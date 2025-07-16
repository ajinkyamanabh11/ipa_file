import 'package:get/get.dart';
import 'package:csv/csv.dart';
import '../constants/paths.dart';
import '../model/profit_report_models/BatchProfitRow_model.dart';
import '../model/profit_report_models/ItemMasterRow_model.dart';
import '../model/profit_report_models/SalesInvoiceDetailRow_model.dart';
import '../model/profit_report_models/SalesInvoiceMasterRow_model.dart';
import '../services/google_drive_service.dart';


class BatchProfitReportController extends GetxController {
  final drive = Get.find<GoogleDriveService>();

  final rows      = <BatchProfitRow>[].obs;
  final isLoading = false.obs;
  final error     = RxnString();

  late List<String> _softAgriPath;

  @override
  Future<void> onInit() async {
    super.onInit();
    _softAgriPath = await SoftAgriPath.build(drive);
    await loadData();
  }

  /* ─────────── main loader ─────────── */
  Future<void> loadData() async {
    try {
      isLoading(true);
      error.value = null;

      final folderId = await drive.folderId(_softAgriPath);

      final masterCsv = await drive.downloadCsv(
          await drive.fileId('SalesInvoiceMaster.csv', folderId));
      final detailCsv = await drive.downloadCsv(
          await drive.fileId('SalesInvoiceDetails.csv', folderId));
      final itemCsv = await drive.downloadCsv(
          await drive.fileId('ItemMaster.csv', folderId));

      final master = _tsvToMaps(masterCsv)
          .map(SalesInvoiceMasterRow.fromCsv)
          .toList();
      final detail = _tsvToMaps(detailCsv)
          .map(SalesInvoiceDetailRow.fromCsv)
          .toList();
      final items = _tsvToMaps(itemCsv)
          .map(ItemMasterRow.fromCsv)
          .toList();

      final headerByBill = {for (var h in master) h.billNo: h};
      final itemNameByCode = {for (var i in items) i.itemCode: i.itemName};

      /* group by batchno */
      final grouped = <String, List<SalesInvoiceDetailRow>>{};
      for (final d in detail) {
        final batch = d.batch.trim();
        if (batch.isEmpty) continue;
        grouped.putIfAbsent(batch, () => []).add(d);
      }

      final out = <BatchProfitRow>[];
      grouped.forEach((batch, list) {
        if (list.isEmpty) return;

        final first = list.first;
        final qty = list.fold(0.0, (s, e) => s + e.qty);
        final salesAmt = list.fold(0.0, (s, e) => s + e.lineTotal);
        final purAmt = first.purchasePrice * qty;
        final profit = salesAmt - purAmt;
        final name = itemNameByCode[first.itemCode] ?? 'Unknown';

        final earliest = list
            .map((e) => headerByBill[e.billNo]?.invoiceDate ?? DateTime(1900))
            .reduce((a, b) => a.isBefore(b) ? a : b)
            .toIso8601String()
            .split('T')
            .first;

        out.add(BatchProfitRow(
          date: earliest,
          invoiceNo: first.billNo, // first encounter
          batch: batch,
          itemCode: first.itemCode,
          itemName: name,
          packing: first.packing,
          quantity: qty,
          salesAmount: salesAmt,
          purchaseAmount: purAmt,
          profit: profit,
        ));
      });

      out.sort((a, b) => b.profit.compareTo(a.profit));
      rows.value = out;
    } catch (e, st) {
      error.value = e.toString();
      rows.clear();
      // ignore: avoid_print
      print('[BatchProfit] $e\n$st');
    } finally {
      isLoading(false);
    }
  }

  /* ─────────── TSV → List<Map> helper ─────────── */
  List<Map<String, dynamic>> _tsvToMaps(String src) {
    // auto‑detect line ending, keep numbers as strings
    final data = const CsvToListConverter(
      fieldDelimiter: '\t',
      shouldParseNumbers: false,
    ).convert(src);

    if (data.isEmpty) return [];

    final header = data.first
        .map((h) => h.toString().trim().toLowerCase())
        .toList();

    return data.skip(1).map((row) {
      final m = <String, dynamic>{};
      for (var i = 0; i < header.length && i < row.length; i++) {
        m[header[i]] = row[i].toString().trim();
      }
      return m;
    }).toList();
  }
}
