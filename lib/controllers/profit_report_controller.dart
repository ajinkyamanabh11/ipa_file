import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants/paths.dart';
import '../services/CsvDataServices.dart'; // Corrected service name import
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import 'dart:developer';

class ProfitReportController extends GetxController {
  final drive = Get.find<GoogleDriveService>();
  final CsvDataService _csvDataService = Get.find<CsvDataService>(); // Get CsvDataService instance

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

  void resetProfits() {
    batchProfits.clear();
    totalSales.value = 0.0;
    totalPurchase.value = 0.0;
    totalProfit.value = 0.0;
  }

  // In loadProfitReport method:
  Future<void> loadProfitReport({
    required DateTime startDate,
    required DateTime endDate,
    bool forceRefresh = false,
  }) async {
    isLoading.value = true;
    totalSales.value = 0.0;
    totalPurchase.value = 0.0;
    totalProfit.value = 0.0;
    batchProfits.clear();

    log('📈 ProfitReportController: Starting load for dates: $startDate to $endDate (Force Refresh parameter received: $forceRefresh)'); // 🔴 NEW/UPDATED LOG

    try {
      await _csvDataService.loadAllCsvs(forceDownload: forceRefresh);
      log('📈 ProfitReportController: CsvDataService.loadAllCsvs completed. Force download was: $forceRefresh'); // 🔴 NEW LOG

      final data = await _processBatchData(startDate, endDate);
      log('📈 ProfitReportController: _processBatchData returned ${data.length} entries.');

      if (data.isNotEmpty) {
        batchProfits.assignAll(data);
        log('📈 ProfitReportController: batchProfits updated. New count: ${batchProfits.length}');
        _updateTotals(data);
        log('📈 ProfitReportController: Totals updated. Sales: ${totalSales.value}, Profit: ${totalProfit.value}');
      } else {
        batchProfits.clear();
        _updateTotals([]);
        log('📈 ProfitReportController: No data returned from _processBatchData, batchProfits cleared. Totals reset to 0.'); // 🔴 UPDATED LOG
      }
    } catch (e, st) {
      log('[ProfitReport] ❌ Error in loadProfitReport: $e\n$st');
      batchProfits.clear();
      filteredInvoices.clear();
      _updateTotals([]);
    } finally {
      isLoading.value = false;
      log('📈 ProfitReportController: Loading finished. isLoading: ${isLoading.value}');
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

  String _normalizePacking(String packing) {
    if (packing == null || packing.isEmpty) return '';
    return packing.replaceAllMapped(RegExp(r'(\d+)\.0(\D*)$'), (match) {
      return '${match.group(1)}${match.group(2)}';
    }).toUpperCase().trim();
  }

  // Renamed from _loadBatchData to _processBatchData as it no longer loads from Drive directly
  Future<List<Map<String, dynamic>>> _processBatchData(
      DateTime startDate, DateTime endDate) async {
    fromDate = startDate;
    toDate = endDate;
    log('📆 ProfitReportController: Processing profit report from $fromDate to $toDate');

    // Get raw CSV strings from CsvDataService's reactive properties
    final masterCsv = _csvDataService.salesMasterCsv.value;
    final detailsCsv = _csvDataService.salesDetailsCsv.value;
    final itemMasterCsv = _csvDataService.itemMasterCsv.value;
    final itemDetailCsv = _csvDataService.itemDetailCsv.value;

    // Validate that CSV data is available
    if (masterCsv.isEmpty || detailsCsv.isEmpty || itemMasterCsv.isEmpty || itemDetailCsv.isEmpty) {
      log('⚠️ ProfitReportController: One or more required CSVs are empty. Cannot process report.');
      return [];
    }

    final masterRows = CsvUtils.toMaps(masterCsv);
    final detailRows = CsvUtils.toMaps(detailsCsv);
    final itemRows = CsvUtils.toMaps(itemMasterCsv);
    final itemDetailRows = CsvUtils.toMaps(itemDetailCsv);

    final filtered = masterRows.where((r) {
      final rawDate = r['invoicedate'] ?? r['challandate'] ?? r['receiptdate'];
      if (rawDate == null) return false;

      try {
        final dateStr = rawDate.toString().split('T').first;
        final parsed = DateTime.tryParse(dateStr) ??
            DateFormat('dd/MM/yyyy').parseStrict(dateStr);
        return parsed.isAfter(startDate.subtract(Duration(days: 1))) &&
            parsed.isBefore(endDate.add(Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).toList();

    filteredInvoices.assignAll(filtered);
    log('📄 ProfitReportController: Filtered invoices: ${filtered.length}');

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

    final Map<String, List<Map<String, dynamic>>> itemDetailsByItemBatch = {};
    for (var row in itemDetailRows) {
      final itemCode = row['ItemCode']?.toString().trim().toUpperCase() ?? '';
      final batchNo = row['BatchNo']?.toString().trim().toUpperCase() ?? '';
      final key = '${itemCode}_${batchNo}';
      itemDetailsByItemBatch.putIfAbsent(key, () => []).add(row);
    }

    final List<Map<String, dynamic>> results = [];

    for (final inv in filtered) {
      final invoiceNo = inv['Billno']?.toString().trim().toUpperCase() ?? '';
      final invoiceDateRaw = inv['invoicedate']?.toString() ?? '';
      final invoiceDate = invoiceDateRaw.split('T').first;

      if (invoiceNo.isEmpty) continue;

      final matchingLines = detailsByInvoice[invoiceNo] ?? [];

      for (final d in matchingLines) {
        final itemCode = d['itemcode']?.toString().trim().toUpperCase();
        final batchNo = d['batchno']?.toString().trim().toUpperCase() ?? '';
        final salesPacking = _normalizePacking(d['packing']!.toString());

        final salesDetailQty = num.tryParse('${d['qty']}') ?? 0;
        final salesDetailPrice = double.tryParse('${d['CGSTTaxableAmt']}') ?? 0.0;

        if (salesDetailQty <= 0 || itemCode == null || itemCode.isEmpty) continue;

        final item = itemMap[itemCode];
        final itemName = item?['itemname']?.toString().trim() ?? itemCode;

        final lookupKey = '${itemCode}_${batchNo}';
        Map<String, dynamic>? matchingDetail;

        List<Map<String, dynamic>> potentialMatches = [];

        if (itemDetailsByItemBatch.containsKey(lookupKey)) {
          potentialMatches = itemDetailsByItemBatch[lookupKey]!;
        }

        if (potentialMatches.isEmpty) {
          potentialMatches = itemDetailRows.where(
                  (detail) => detail['ItemCode']?.toString().trim().toUpperCase() == itemCode &&
                  (detail['BatchNo']?.toString().trim().toUpperCase() == '..' ||
                      detail['BatchNo']?.toString().trim().isEmpty == true)
          ).toList();
        }

        if (potentialMatches.isNotEmpty) {
          matchingDetail = potentialMatches.firstWhereOrNull(
                  (detail) {
                final itemDetailTxtPkg = detail['txt_pkg']?.toString().trim() ?? '';
                final itemDetailCmbUnit = detail['cmb_unit']?.toString().trim() ?? '';
                final itemDetailPacking = _normalizePacking('$itemDetailTxtPkg$itemDetailCmbUnit');
                return itemDetailPacking == salesPacking;
              }
          );
        }

        // Define calculatedPacking here before using it in the 'entry' map
        final String calculatedPacking = (matchingDetail != null)
            ? '${matchingDetail['txt_pkg']?.toString().trim().toUpperCase() ?? ''}${matchingDetail['cmb_unit']?.toString().trim().toUpperCase() ?? ''}'
            : ''; // Provide a default empty string if no match found

        final purcPricePerUnit = double.tryParse('${matchingDetail?['PurchasePrice']}') ?? 0.0;
        final totalPurchase = purcPricePerUnit * salesDetailQty;

        final profitCalculated = salesDetailPrice - totalPurchase;

        final entry = {
          'billno': invoiceNo,
          'batchno': batchNo,
          'qty': salesDetailQty,
          'sales': salesDetailPrice,
          'purchase': totalPurchase,
          'profit': profitCalculated,
          'packing': calculatedPacking, // Now `calculatedPacking` is defined
          'itemName': itemName,
          'itemCode': itemCode,
          'date': invoiceDate,
        };

        results.add(entry);
      }
    }

    results.sort((a, b) => a['billno'].toString().compareTo(b['billno'].toString()));
    log('[ProfitReport] ✅ _processBatchData finished processing. Returning ${results.length} batch entries');
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