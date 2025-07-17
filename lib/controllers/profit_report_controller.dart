import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import 'item_type_controller.dart';

class ProfitReportController extends GetxController {
  final drive = Get.find<GoogleDriveService>();
  final itemTypeController = Get.find<ItemTypeController>();

  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();

  final batchProfits = <Map<String, dynamic>>[].obs;
  final filteredInvoices = <Map<String, dynamic>>[].obs;

  Future<void> loadProfitReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    fromDate = startDate;
    toDate = endDate;
    print('📅 Loading profit report from $fromDate to $toDate');

    try {
      final path = await SoftAgriPath.build(drive);
      final folderId = await drive.folderId(path);

      final fileIdMaster = await drive.fileId('SalesInvoiceMaster.csv', folderId);
      final csvMaster = await drive.downloadCsv(fileIdMaster);
      final masterRows = CsvUtils.toMaps(csvMaster);
      print('📄 Loaded ${masterRows.length} rows from SalesInvoiceMaster');

      final filtered = masterRows.where((r) {
        final rawDate = r['invoicedate'] ?? r['challandate'] ?? r['receiptdate'];
        if (rawDate == null) return false;

        DateTime? parsedDate;
        try {
          final dateStr = rawDate.toString().split('T').first;
          parsedDate = DateTime.tryParse(dateStr) ??
              DateFormat('dd/MM/yyyy').parseStrict(dateStr);
        } catch (_) {}

        return parsedDate != null &&
            !parsedDate.isBefore(startDate) &&
            !parsedDate.isAfter(endDate);
      }).toList();

      filteredInvoices.assignAll(filtered);
      print('📦 Filtered invoices: ${filtered.length}');

      final fileIdDetails = await drive.fileId('SalesInvoiceDetails.csv', folderId);
      final csvDetails = await drive.downloadCsv(fileIdDetails);
      final detailRows = CsvUtils.toMaps(csvDetails);

      final fileIdItem = await drive.fileId('ItemMaster.csv', folderId);
      final csvItem = await drive.downloadCsv(fileIdItem);
      final itemRows = CsvUtils.toMaps(csvItem);

      final List<Map<String, dynamic>> results = [];

      for (final inv in filtered) {
        final invoiceNo = inv['invoiceno']?.toString().trim().toUpperCase() ?? '';
        final invoiceDateRaw = inv['invoicedate']?.toString() ?? '';
        final invoiceDate = invoiceDateRaw.split('T').first;

        if (invoiceNo.isEmpty) continue;

        final matchingLines = detailRows.where((d) {
          final bill = d['billno']?.toString().trim().toUpperCase();
          return bill == invoiceNo;
        }).toList();

        if (matchingLines.isEmpty) {
          print('⚠️ No details found for invoice: $invoiceNo');
        }

        for (final d in matchingLines) {
          final batchNo = d['batchno']?.toString().trim() ?? 'UNKNOWN';
          final qty = num.tryParse('${d['qty']}') ?? 0;
          final sales = double.tryParse('${d['CGSTTaxableAmt']}') ?? 0.0;
          final packing = d['packing']?.toString() ?? '';
          final itemCode = d['itemcode']?.toString()?.trim();

          final item = itemRows.firstWhereOrNull(
                (i) => i['itemcode']?.toString()?.trim() == itemCode,
          );

          final itemName = item?['itemname']?.toString()?.trim() ??
              itemCode ??
              'UNKNOWN';

          final matchingDetail = itemTypeController.allItemDetailRows
              .firstWhereOrNull((row) =>
          row['ItemCode']?.toString()?.trim() == itemCode &&
              (row['BatchNo']?.toString()?.trim().toLowerCase() ?? '') ==
                  batchNo.toLowerCase());

          final purcPriceWithGst =
              double.tryParse('${matchingDetail?['PurchasePrice']}') ?? 0.0;

          final purchase = purcPriceWithGst * qty;
          final profit = sales - purchase;

          final entry = {
            'billno': invoiceNo,
            'batchno': batchNo,
            'qty': qty,
            'sales': sales,
            'purchase': purchase,
            'profit': profit,
            'packing': packing,
            'itemName': itemName,
            'date': invoiceDate,
          };

          results.add(entry);
        }
      }

      results.sort((a, b) =>
          a['billno'].toString().compareTo(b['billno'].toString()));

      batchProfits.assignAll(results);
      print('[ProfitReport] ✅ Loaded ${results.length} batch entries');

      for (var entry in results) {
        print(entry);
      }
    } catch (e, st) {
      print('[ProfitReport] ❌ Error: $e');
      print(st);
      batchProfits.clear();
      filteredInvoices.clear();
    }
  }
}
