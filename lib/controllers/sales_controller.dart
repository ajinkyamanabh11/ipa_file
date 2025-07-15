import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import 'base_remote_controller.dart';

class SalesController extends GetxController with BaseRemoteController {
  final drive = Get.find<GoogleDriveService>();
  final sales = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    guard(_loadSales);
  }
  Future<void> fetchSales() async => guard(_loadSales);

  Future<void> _loadSales() async {
    final parent = await drive.folderId(kSoftAgriPath);
    final id = await drive.fileId('SalesInvoiceMaster.csv', parent);
    final csv = await drive.downloadCsv(id);

    sales.value = CsvUtils.toMaps(csv, parseNumbers: false).map((m) {
      m['AccountName'] = m['accountname'];
      m['BillNo'] = m['billno'];
      m['PaymentMode'] = m['paymentmode'];
      m['Amount'] = double.tryParse('${m['totalbillamount']}') ?? 0.0;

      final rawDate = '${m['invoicedate'] ?? m['entrydate'] ?? ''}';
      if (rawDate.isNotEmpty && rawDate != 'null') {
        try {
          m['EntryDate'] = DateTime.parse(rawDate.split(' ').first);
        } catch (_) {}
      }
      return m;
    }).toList();
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
        final bill = s['BillNo']?.toString().toLowerCase() ?? '';
        final d = date == null ||
            (s['EntryDate'] is DateTime &&
                DateUtils.isSameDay(s['EntryDate'], date));
        return name.contains(nameQ.toLowerCase()) &&
            bill.contains(billQ.toLowerCase()) &&
            d;
      }).toList();
}
