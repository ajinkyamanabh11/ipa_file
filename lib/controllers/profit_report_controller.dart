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

  final isLoading = false.obs;
  final batchProfits = <Map<String, dynamic>>[].obs;
  final filteredInvoices = <Map<String, dynamic>>[].obs;

  final totalSales = 0.0.obs;
  final totalPurchase = 0.0.obs;
  final totalProfit = 0.0.obs;

  final searchQuery = ''.obs;

  List<Map<String, dynamic>> get filteredRows {
    final search = searchQuery.value.toLowerCase();
    if (search.isEmpty) return batchProfits;
    return batchProfits.where((row) {
      final item = (row['itemName'] ?? '').toString().toLowerCase();
      final bill = (row['billno'] ?? '').toString().toLowerCase();
      return item.contains(search) || bill.contains(search);
    }).toList();
  }

  Future<void> loadProfitReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    isLoading.value = true;
    totalSales.value = 0.0;
    totalPurchase.value = 0.0;
    totalProfit.value = 0.0;

    try {
      final data = await _loadBatchData(startDate, endDate);
      batchProfits.assignAll(data);
      _updateTotals(data);
    } catch (e, st) {
      print('[ProfitReport] ❌ Error: $e');
      print(st);
      batchProfits.clear();
      filteredInvoices.clear();
      _updateTotals([]);
    } finally {
      isLoading.value = false;
    }
  }

  void _updateTotals(List<Map<String, dynamic>> rows) {
    double sale = 0;
    double purchase = 0;
    double profit = 0;

    for (final row in rows) {
      sale += row['sales'] ?? 0;
      purchase += row['purchase'] ?? 0;
      profit += row['profit'] ?? 0;
    }

    totalSales.value = sale;
    totalPurchase.value = purchase;
    totalProfit.value = profit;
  }

  Future<List<Map<String, dynamic>>> _loadBatchData(
      DateTime startDate, DateTime endDate) async {
    fromDate = startDate;
    toDate = endDate;
    print('📅 Loading profit report from $fromDate to $toDate');

    final path = await SoftAgriPath.build(drive);
    final folderId = await drive.folderId(path);

    // Load invoice master
    final fileIdMaster = await drive.fileId('SalesInvoiceMaster.csv', folderId);
    final csvMaster = await drive.downloadCsv(fileIdMaster);
    final masterRows = CsvUtils.toMaps(csvMaster);
    print('📄 Loaded ${masterRows.length} rows from SalesInvoiceMaster');

    // Filter master by date
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

    // Load details and item master
    final fileIdDetails = await drive.fileId('SalesInvoiceDetails.csv', folderId);
    final csvDetails = await drive.downloadCsv(fileIdDetails);
    final detailRows = CsvUtils.toMaps(csvDetails);

    final fileIdItem = await drive.fileId('ItemMaster.csv', folderId);
    final csvItem = await drive.downloadCsv(fileIdItem);
    final itemRows = CsvUtils.toMaps(csvItem);

    // 🔁 Optimization: Build maps for fast lookup
    final Map<String, List<Map<String, dynamic>>> detailsByInvoice = {};
    for (final row in detailRows) {
      final bill = row['billno']?.toString().trim().toUpperCase() ?? '';
      if (bill.isNotEmpty) {
        detailsByInvoice.putIfAbsent(bill, () => []).add(row);
      }
    }

    final Map<String, Map<String, dynamic>> itemMap = {
      for (var row in itemRows)
        row['itemcode']?.toString().trim().toUpperCase() ?? '': row,
    };

    final Map<String, Map<String, dynamic>> itemDetailMap = {
      for (var row in itemTypeController.allItemDetailRows)
        '${row['ItemCode']?.toString().trim().toUpperCase()}_${row['BatchNo']?.toString().trim().toUpperCase()}': row,
    };

    final List<Map<String, dynamic>> results = [];

    for (final inv in filtered) {
      final invoiceNo = inv['invoiceno']?.toString().trim().toUpperCase() ?? '';
      final invoiceDateRaw = inv['invoicedate']?.toString() ?? '';
      final invoiceDate = invoiceDateRaw.split('T').first;

      if (invoiceNo.isEmpty) continue;

      final matchingLines = detailsByInvoice[invoiceNo] ?? [];

      for (final d in matchingLines) {
        final batchNo = d['batchno']?.toString().trim() ?? 'UNKNOWN';
        final qty = num.tryParse('${d['qty']}') ?? 0;
        final sales = double.tryParse('${d['CGSTTaxableAmt']}') ?? 0.0;
        final packing = d['packing']?.toString() ?? '';
        final itemCode = d['itemcode']?.toString().trim().toUpperCase();

        if (qty <= 0) continue;

        final item = itemMap[itemCode];
        final itemName = item?['itemname']?.toString().trim() ?? itemCode;

        final detailKey = '${itemCode}_$batchNo'.toUpperCase();
        final matchingDetail = itemDetailMap[detailKey];

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

    print('[ProfitReport] ✅ Loaded ${results.length} batch entries');

    return results;
  }

  void clear() {
    batchProfits.clear();
    filteredInvoices.clear();
    totalSales.value = 0;
    totalPurchase.value = 0;
    totalProfit.value = 0;
    searchQuery.value = '';
  }
}
