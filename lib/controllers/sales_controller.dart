// lib/controllers/sales_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart'; // Ensure this is the correct CsvUtils with stringColumns
import '../services/CsvDataServices.dart';
import 'base_remote_controller.dart';
import 'dart:developer';

class SalesController extends GetxController with BaseRemoteController {
  final drive = Get.find<GoogleDriveService>();
  final CsvDataService _csvDataService = Get.find<CsvDataService>();

  final sales = <Map<String, dynamic>>[].obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    log('[SalesController] Initializing and loading sales data...');
    guard(() => _loadSales(forceRefresh: true));
  }

  Future<void> fetchSales({bool forceRefresh = false}) async => guard(() => _loadSales(forceRefresh: forceRefresh));

  Future<void> _loadSales({bool forceRefresh = false}) async {
    try {
      await _csvDataService.loadAllCsvs(forceDownload: forceRefresh);

      final String csv = _csvDataService.salesMasterCsv.value;

      if (csv.isEmpty) {
        log('⚠️ SalesController: SalesInvoiceMaster.csv data is empty. Cannot process sales.');
        sales.clear();
        return;
      }

      log('⚡ SalesController: Processing SalesInvoiceMaster.csv (from cache or new download)');

      // 🔴 CRITICAL FIX HERE: Use the new 'stringColumns' parameter
      // 'BillNo' should be a string to preserve leading zeros if present.
      // 'invoicedate' and 'entrydate' should be strings before you attempt to parse them into DateTime.
      // 'totalbillamount' should *not* be in stringColumns as it's a number.
      sales.value = CsvUtils.toMaps(
        csv,
        stringColumns: [
          'BillNo',
          'invoicedate', // Important to keep as string before DateTime.parse
          'entrydate',   // Important to keep as string before DateTime.parse
          // Add any other columns here that you want to ensure are always strings,
          // especially if they represent IDs, codes, or text that might contain leading zeros.
        ],
      ).map((m) {
        m['AccountName'] = m['accountname'];
        m['BillNo']      = m['billno']; // This will now correctly be a string like '00123' if that's in the CSV
        m['PaymentMode'] = m['paymentmode'];
        m['Amount']      = double.tryParse('${m['totalbillamount']}') ?? 0.0; // Convert to double here

        final rawDate = '${m['invoicedate'] ?? m['entrydate'] ?? ''}';
        if (rawDate.isNotEmpty && rawDate != 'null') {
          try {
            // keep only yyyy‑MM‑dd part
            m['EntryDate'] = DateTime.parse(rawDate.split(' ').first);
          } catch (_) {/* ignore parse errors */}
        }
        return m;
      }).toList();
      log('✅ SalesController: Sales data processed successfully. Count: ${sales.length}');

    } catch (e, st) {
      log('[SalesController] ❌ Error loading sales data: $e\n$st');
      sales.clear();
    }
  }

  double get totalCash => sales
      .where((s) => s['PaymentMode']?.toString().toLowerCase() == 'cash')
      .fold(0.0, (p, s) => p + (s['Amount'] ?? 0));

  double get totalCredit => sales
      .where((s) => s['PaymentMode']?.toString().toLowerCase() == 'credit')
      .fold(0.0, (p, s) => p + (s['Amount'] ?? 0));

  List<Map<String, dynamic>> filter({
    required String nameQ,
    required String billQ,
    DateTime? date,
  }) =>
      sales.where((s) {
        final name = s['AccountName']?.toString().toLowerCase() ?? '';
        final bill = s['BillNo']?.toString().toLowerCase() ?? ''; // This should now correctly filter based on the full string
        final dateMatch = date == null ||
            (s['EntryDate'] is DateTime &&
                DateUtils.isSameDay(s['EntryDate'], date));

        return name.contains(nameQ.toLowerCase()) &&
            bill.contains(billQ.toLowerCase()) &&
            dateMatch;
      }).toList();
}