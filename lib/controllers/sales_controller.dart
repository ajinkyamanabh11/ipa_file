// lib/controllers/sales_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/paths.dart';                 // ⬅️ SoftAgriPath.build()
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import 'base_remote_controller.dart';

class SalesController extends GetxController with BaseRemoteController {
  final drive = Get.find<GoogleDriveService>();

  // ─────────────────────────────────────────────────────────────
  late final List<String> _softAgriPath;    // ['SoftAgri_Backups', <FY>, 'softagri_csv']

  final sales = <Map<String, dynamic>>[].obs;

  // ───────────────────────── life‑cycle ────────────────────────
  @override
  Future<void> onInit() async {
    super.onInit();

    // 1️⃣  build the dynamic FY path once
    _softAgriPath = await SoftAgriPath.build(drive);

    // 2️⃣  initial fetch
    guard(_loadSales);
  }

  /// Pull‑to‑refresh entrypoint
  Future<void> fetchSales() async => guard(_loadSales);

  // ───────────────────────── CSV fetch + parse ─────────────────
  Future<void> _loadSales() async {
    // locate folder for current FY
    final parent = await drive.folderId(_softAgriPath);

    // download SalesInvoiceMaster.csv
    final id  = await drive.fileId('SalesInvoiceMaster.csv', parent);
    final csv = await drive.downloadCsv(id);

    // map & normalise fields
    sales.value = CsvUtils.toMaps(csv, parseNumbers: false).map((m) {
      m['AccountName'] = m['accountname'];
      m['BillNo']      = m['billno'];
      m['PaymentMode'] = m['paymentmode'];
      m['Amount']      = double.tryParse('${m['totalbillamount']}') ?? 0.0;

      final rawDate = '${m['invoicedate'] ?? m['entrydate'] ?? ''}';
      if (rawDate.isNotEmpty && rawDate != 'null') {
        try {
          // keep only yyyy‑MM‑dd part
          m['EntryDate'] = DateTime.parse(rawDate.split(' ').first);
        } catch (_) {/* ignore parse errors */}
      }
      return m;
    }).toList();
  }

  // ─────────────────────── computed getters ────────────────────
  double get totalCash => sales
      .where((s) => s['PaymentMode']?.toString().toLowerCase() == 'cash')
      .fold(0.0, (p, s) => p + (s['Amount'] ?? 0));

  double get totalCredit => sales
      .where((s) => s['PaymentMode']?.toString().toLowerCase() == 'credit')
      .fold(0.0, (p, s) => p + (s['Amount'] ?? 0));

  // ─────────────────────── local filters ───────────────────────
  List<Map<String, dynamic>> filter({
    required String nameQ,
    required String billQ,
    DateTime? date,
  }) =>
      sales.where((s) {
        final name = s['AccountName']?.toString().toLowerCase() ?? '';
        final bill = s['BillNo']?.toString().toLowerCase() ?? '';
        final dateMatch = date == null ||
            (s['EntryDate'] is DateTime &&
                DateUtils.isSameDay(s['EntryDate'], date));

        return name.contains(nameQ.toLowerCase()) &&
            bill.contains(billQ.toLowerCase()) &&
            dateMatch;
      }).toList();
}
