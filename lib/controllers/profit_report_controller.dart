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

  // Pagination variables
  final currentPage = 0.obs;
  final itemsPerPage = 50.obs;
  final totalItems = 0.obs;
  final totalPages = 0.obs;
  
  // All data storage for pagination
  List<Map<String, dynamic>> allBatchProfits = [];

  final totalSales = 0.0.obs;
  final totalPurchase = 0.0.obs;
  final totalProfit = 0.0.obs;

  final searchQuery = ''.obs;

  // Memory management
  final isProcessingLargeDataset = false.obs;
  final processingProgress = 0.0.obs;

  List<Map<String, dynamic>> get filteredRows {
    final search = searchQuery.value.toLowerCase();
    if (search.isEmpty) return batchProfits;
    return batchProfits.where((row) {
      final item = (row['itemName'] ?? '').toString().toLowerCase();
      final bill = (row['billno'] ?? '').toString().toLowerCase();
      return item.contains(search) || bill.contains(search);
    }).toList();
  }

  /// Navigate to next page
  void nextPage() {
    if (currentPage.value < totalPages.value - 1) {
      currentPage.value++;
      _updateDisplayedData();
    }
  }

  /// Navigate to previous page
  void previousPage() {
    if (currentPage.value > 0) {
      currentPage.value--;
      _updateDisplayedData();
    }
  }

  /// Go to specific page
  void goToPage(int page) {
    if (page >= 0 && page < totalPages.value) {
      currentPage.value = page;
      _updateDisplayedData();
    }
  }

  /// Set items per page and refresh display
  void setItemsPerPage(int items) {
    itemsPerPage.value = items;
    currentPage.value = 0; // Reset to first page
    _updatePaginationInfo();
    _updateDisplayedData();
  }

  void resetProfits() {
    batchProfits.clear();
    allBatchProfits.clear();
    totalSales.value = 0.0;
    totalPurchase.value = 0.0;
    totalProfit.value = 0.0;
    totalItems.value = 0;
    totalPages.value = 0;
    currentPage.value = 0;
  }

  // In loadProfitReport method:
  Future<void> loadProfitReport({
    required DateTime startDate,
    required DateTime endDate,
    bool forceRefresh = false,
  }) async {
    isLoading.value = true;
    processingProgress.value = 0.0;
    totalSales.value = 0.0;
    totalPurchase.value = 0.0;
    totalProfit.value = 0.0;
    batchProfits.clear();
    allBatchProfits.clear();

    log('📈 ProfitReportController: Starting load for dates: $startDate to $endDate (Force Refresh parameter received: $forceRefresh)');

    try {
      await _csvDataService.loadAllCsvs(forceDownload: forceRefresh);
      log('📈 ProfitReportController: CsvDataService.loadAllCsvs completed. Force download was: $forceRefresh');

      // Check dataset size and determine processing method
      final masterCsv = _csvDataService.salesMasterCsv.value;
      final detailsCsv = _csvDataService.salesDetailsCsv.value;
      
      final masterLines = masterCsv.split('\n').length;
      final detailsLines = detailsCsv.split('\n').length;
      isProcessingLargeDataset.value = (masterLines > 1000 || detailsLines > 1000);

      List<Map<String, dynamic>> data;
      if (isProcessingLargeDataset.value) {
        data = await _processBatchDataInChunks(startDate, endDate);
      } else {
        data = await _processBatchData(startDate, endDate);
      }
      
      log('📈 ProfitReportController: Data processing returned ${data.length} entries.');

      if (data.isNotEmpty) {
        allBatchProfits = data;
        _updateTotals(data);
        _updatePaginationInfo();
        _updateDisplayedData();
        log('📈 ProfitReportController: Data updated. Sales: ${totalSales.value}, Profit: ${totalProfit.value}');
      } else {
        resetProfits();
        log('📈 ProfitReportController: No data returned, profits reset to 0.');
      }
    } catch (e, st) {
      log('[ProfitReport] ❌ Error in loadProfitReport: $e\n$st');
      resetProfits();
      filteredInvoices.clear();
    } finally {
      isLoading.value = false;
      processingProgress.value = 1.0;
      log('📈 ProfitReportController: Loading finished. isLoading: ${isLoading.value}');
    }
  }

  /// Process large datasets in chunks to prevent memory issues
  Future<List<Map<String, dynamic>>> _processBatchDataInChunks(
    DateTime startDate, 
    DateTime endDate
  ) async {
    const int chunkSize = 200; // Process 200 invoices at a time
    
    fromDate = startDate;
    toDate = endDate;
    log('📆 ProfitReportController: Processing large profit report from $fromDate to $toDate');

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

    // Filter invoices by date range
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

    // Prepare lookup maps
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

    // Process filtered invoices in chunks
    for (int i = 0; i < filtered.length; i += chunkSize) {
      final chunk = filtered.skip(i).take(chunkSize).toList();
      final chunkResults = await _processInvoiceChunk(
        chunk, 
        detailsByInvoice, 
        itemMap, 
        itemDetailsByItemBatch
      );
      
      results.addAll(chunkResults);
      
      // Update progress
      processingProgress.value = (i + chunkSize) / filtered.length;
      
      // Allow UI to update
      await Future.delayed(Duration(milliseconds: 10));
    }

    results.sort((a, b) => a['billno'].toString().compareTo(b['billno'].toString()));
    log('[ProfitReport] ✅ _processBatchDataInChunks finished processing. Returning ${results.length} batch entries');
    return results;
  }

  /// Process a chunk of invoices
  Future<List<Map<String, dynamic>>> _processInvoiceChunk(
    List<Map<String, dynamic>> invoices,
    Map<String, List<Map<String, dynamic>>> detailsByInvoice,
    Map<String, Map<String, dynamic>> itemMap,
    Map<String, List<Map<String, dynamic>>> itemDetailsByItemBatch,
  ) async {
    final List<Map<String, dynamic>> results = [];

    for (final inv in invoices) {
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
          potentialMatches = itemDetailsByItemBatch.values
              .expand((list) => list)
              .where((detail) => 
                  detail['ItemCode']?.toString().trim().toUpperCase() == itemCode &&
                  (detail['BatchNo']?.toString().trim().toUpperCase() == '..' ||
                   detail['BatchNo']?.toString().trim().isEmpty == true))
              .toList();
        }

        if (potentialMatches.isNotEmpty) {
          matchingDetail = potentialMatches.cast<Map<String, dynamic>?>().firstWhere(
            (detail) {
              final itemDetailTxtPkg = detail?['txt_pkg']?.toString().trim() ?? '';
              final itemDetailCmbUnit = detail?['cmb_unit']?.toString().trim() ?? '';
              final itemDetailPacking = _normalizePacking('$itemDetailTxtPkg$itemDetailCmbUnit');
              return itemDetailPacking == salesPacking;
            },
            orElse: () => null,
          );
        }

        final String calculatedPacking = (matchingDetail != null)
            ? '${matchingDetail['txt_pkg']?.toString().trim().toUpperCase() ?? ''}${matchingDetail['cmb_unit']?.toString().trim().toUpperCase() ?? ''}'
            : '';

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
          'packing': calculatedPacking,
          'itemName': itemName,
          'itemCode': itemCode,
          'date': invoiceDate,
        };

        results.add(entry);
      }
    }

    return results;
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

  /// Update pagination information
  void _updatePaginationInfo() {
    totalItems.value = allBatchProfits.length;
    totalPages.value = (totalItems.value / itemsPerPage.value).ceil();
    
    // Reset to first page if current page is out of bounds
    if (currentPage.value >= totalPages.value && totalPages.value > 0) {
      currentPage.value = 0;
    }
  }

  /// Update the displayed data based on current page
  void _updateDisplayedData() {
    if (allBatchProfits.isEmpty) {
      batchProfits.value = [];
      return;
    }

    final startIndex = currentPage.value * itemsPerPage.value;
    final endIndex = (startIndex + itemsPerPage.value).clamp(0, allBatchProfits.length);
    
    final pageData = allBatchProfits.sublist(startIndex, endIndex);
    batchProfits.value = pageData;
    
    log('📄 ProfitReportController: Displaying page ${currentPage.value + 1} of ${totalPages.value} (${pageData.length} items)');
  }

  /// Get pagination info as string
  String getPaginationInfo() {
    if (totalItems.value == 0) return 'No items';
    
    final startItem = (currentPage.value * itemsPerPage.value) + 1;
    final endItem = ((currentPage.value + 1) * itemsPerPage.value).clamp(0, totalItems.value);
    
    return 'Showing $startItem-$endItem of ${totalItems.value} items';
  }

  /// Check if there are more pages
  bool get hasNextPage => currentPage.value < totalPages.value - 1;
  bool get hasPreviousPage => currentPage.value > 0;

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
          matchingDetail = potentialMatches.cast<Map<String, dynamic>?>().firstWhere(
            (detail) {
              final itemDetailTxtPkg = detail?['txt_pkg']?.toString().trim() ?? '';
              final itemDetailCmbUnit = detail?['cmb_unit']?.toString().trim() ?? '';
              final itemDetailPacking = _normalizePacking('$itemDetailTxtPkg$itemDetailCmbUnit');
              return itemDetailPacking == salesPacking;
            },
            orElse: () => null,
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
    resetProfits();
    filteredInvoices.clear();
    searchQuery.value = '';
  }
}