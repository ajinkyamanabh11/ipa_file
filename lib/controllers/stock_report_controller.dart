// lib/controllers/stock_report_controller.dart

import 'package:get/get.dart';
import 'package:flutter/material.dart'; // For DateUtils (though not directly used here, useful for other date comparisons)
import 'package:csv/csv.dart'; // Not directly used here, but good to keep if other methods use it
import '../services/CsvDataServices.dart';
import '../util/csv_utils.dart';

class StockReportController extends GetxController {
  var isLoading = true.obs;
  var errorMessage = Rx<String?>(null);
  var searchQuery = ''.obs;

  // New observables for sorting
  var sortByColumn = 'Item Name'.obs; // Default sort by Item Name
  var sortAscending = true.obs; // Default sort ascending

  // Enhanced pagination variables
  var currentPage = 0.obs;
  var itemsPerPage = 50.obs; // Default 50 items per page
  var totalItems = 0.obs;
  var totalPages = 0.obs;

  var filteredStockData = <Map<String, dynamic>>[].obs;
  var allStockData = <Map<String, dynamic>>[]; // Internal storage for all data
  var totalCurrentStock = 0.0.obs;

  // Memory management and processing
  var isProcessingLargeDataset = false.obs;
  var processingProgress = 0.0.obs;
  
  // Cache management
  DateTime? _lastProcessedTime;
  bool _hasProcessedData = false;
  String _lastDataHash = '';

  final CsvDataService _csvDataService = Get.find<CsvDataService>();

  @override
  void onInit() {
    super.onInit();
    // Re-apply filter whenever any relevant observable changes
    ever(_csvDataService.itemDetailCsv, (_) => _checkAndReprocess());
    ever(_csvDataService.itemMasterCsv, (_) => _checkAndReprocess());
    ever(searchQuery, (_) => _applyFilterAndSort());
    ever(sortByColumn, (_) => _applyFilterAndSort()); // Trigger filter on sort column change
    ever(sortAscending, (_) => _applyFilterAndSort()); // Trigger filter on sort order change
    ever(currentPage, (_) => _updateDisplayedData()); // Update displayed data when page changes

    // Check if CSV service already has data loaded
    if (_csvDataService.hasData('itemDetailCsv') && _csvDataService.hasData('itemMasterCsv')) {
      log('StockReportController: CSV data already available, processing...');
      _processStockData();
    } else {
      loadStockReport(); // Initial data load
    }
  }

  /// Check if data needs reprocessing based on changes
  void _checkAndReprocess() {
    final currentHash = _generateDataHash();
    if (currentHash != _lastDataHash) {
      _lastDataHash = currentHash;
      _hasProcessedData = false;
      _processStockData();
    }
  }

  /// Generate hash of current data to detect changes
  String _generateDataHash() {
    final itemDetailLength = _csvDataService.itemDetailCsv.value.length;
    final itemMasterLength = _csvDataService.itemMasterCsv.value.length;
    return '$itemDetailLength-$itemMasterLength';
  }

  /// Public method to set the column to sort by.
  void setSortColumn(String column) {
    if (sortByColumn.value == column) {
      // If the same column is selected, just toggle the order
      toggleSortOrder();
    } else {
      sortByColumn.value = column;
      sortAscending.value = true; // Default to ascending when changing column
    }
  }

  /// Public method to toggle the sort order (ascending/descending).
  void toggleSortOrder() {
    sortAscending.value = !sortAscending.value;
  }

  /// Navigate to next page
  void nextPage() {
    if (currentPage.value < totalPages.value - 1) {
      currentPage.value++;
    }
  }

  /// Navigate to previous page
  void previousPage() {
    if (currentPage.value > 0) {
      currentPage.value--;
    }
  }

  /// Go to specific page
  void goToPage(int page) {
    if (page >= 0 && page < totalPages.value) {
      currentPage.value = page;
    }
  }

  /// Set items per page and refresh display
  void setItemsPerPage(int items) {
    itemsPerPage.value = items;
    currentPage.value = 0; // Reset to first page
    _updateDisplayedData();
  }

  /// Loads stock report data from CSVs.
  Future<void> loadStockReport({bool forceRefresh = false}) async {
    isLoading.value = true;
    errorMessage.value = null;
    processingProgress.value = 0.0;

    try {
      // Check if we already have processed data and it's recent (unless force refresh)
      if (!forceRefresh && _hasProcessedData && _lastProcessedTime != null) {
        final timeSinceLastProcess = DateTime.now().difference(_lastProcessedTime!);
        if (timeSinceLastProcess < Duration(minutes: 30) && allStockData.isNotEmpty) {
          log('StockReportController: Using recently processed stock data');
          isLoading.value = false;
          processingProgress.value = 1.0;
          return;
        }
      }

      await _csvDataService.loadAllCsvs(forceDownload: forceRefresh);
      await _processStockData();

    } catch (e, st) {
      errorMessage.value = 'Failed to load stock data: $e';
      print('Error loading stock data: $e\n$st');
    } finally {
      isLoading.value = false;
      processingProgress.value = 1.0;
    }
  }

  /// Process stock data from CSV service
  Future<void> _processStockData() async {
    try {
      if (_csvDataService.itemDetailCsv.value.isEmpty || _csvDataService.itemMasterCsv.value.isEmpty) {
        errorMessage.value = 'Required CSV data (ItemMaster or ItemDetail) is empty. Please ensure files are on Google Drive.';
        allStockData.clear();
        filteredStockData.value = [];
        totalCurrentStock.value = 0.0;
        return;
      }

      // Check if we're dealing with a large dataset
      final itemDetailLines = _csvDataService.itemDetailCsv.value.split('\n').length;
      final itemMasterLines = _csvDataService.itemMasterCsv.value.split('\n').length;
      isProcessingLargeDataset.value = (itemDetailLines > 1000 || itemMasterLines > 1000);

      if (isProcessingLargeDataset.value) {
        // Process large dataset in chunks to prevent crashes
        await _processLargeDataset();
      } else {
        // Process normally for small datasets
        await _processNormalDataset();
      }

      if (allStockData.isEmpty) {
        errorMessage.value = 'No stock data found after processing.';
      } else {
        _hasProcessedData = true;
        _lastProcessedTime = DateTime.now();
        _lastDataHash = _generateDataHash();
      }

    } catch (e, st) {
      errorMessage.value = 'Failed to process stock data: $e';
      print('Error processing stock data: $e\n$st');
    }
  }

  /// Process large datasets in chunks to prevent memory issues
  Future<void> _processLargeDataset() async {
    const int chunkSize = 1000; // Process 1000 items at a time
    processingProgress.value = 0.0;

    // Parse CSVs into lists of maps
    final List<Map<String, dynamic>> allItemDetails =
    CsvUtils.toMaps(
        _csvDataService.itemDetailCsv.value,
        stringColumns: ['BatchNo', 'ItemCode', 'txt_pkg', 'cmb_unit']);

    final List<Map<String, dynamic>> allItemsMaster =
    CsvUtils.toMaps(
        _csvDataService.itemMasterCsv.value,
        stringColumns: ['ItemCode', 'ItemName', 'ItemType']);

    // Filter items with non-zero current stock first
    final filteredRawItemDetails = allItemDetails.where((itemDetail) {
      final currentStock = double.tryParse(itemDetail['Currentstock']?.toString() ?? '0') ?? 0.0;
      return currentStock != 0;
    }).toList();

    allStockData.clear();
    double currentTotalStock = 0.0;

    // Process in chunks
    for (int i = 0; i < filteredRawItemDetails.length; i += chunkSize) {
      final chunk = filteredRawItemDetails.skip(i).take(chunkSize).toList();
      final processedChunk = await _processDataChunk(chunk, allItemsMaster);

      allStockData.addAll(processedChunk);

      // Update total stock
      for (final item in processedChunk) {
        currentTotalStock += item['Current Stock'] ?? 0.0;
      }

      // Update progress
      processingProgress.value = (i + chunkSize) / filteredRawItemDetails.length;

      // Allow UI to update and prevent blocking
      await Future.delayed(Duration(milliseconds: 20));
    }

    totalCurrentStock.value = currentTotalStock;
    _applyFilterAndSort();
  }

  /// Process normal-sized datasets
  Future<void> _processNormalDataset() async {
    final List<Map<String, dynamic>> processedList = [];
    double currentTotalStock = 0.0;

    // Parse CSVs into lists of maps
    final List<Map<String, dynamic>> allItemDetails =
    CsvUtils.toMaps(
        _csvDataService.itemDetailCsv.value,
        stringColumns: ['BatchNo', 'ItemCode', 'txt_pkg', 'cmb_unit']);

    final List<Map<String, dynamic>> allItemsMaster =
    CsvUtils.toMaps(
        _csvDataService.itemMasterCsv.value,
        stringColumns: ['ItemCode', 'ItemName', 'ItemType']);

    final filteredRawItemDetails = allItemDetails.where((itemDetail) {
      final currentStock = double.tryParse(itemDetail['Currentstock']?.toString() ?? '0') ?? 0.0;
      return currentStock != 0;
    }).toList();

    for (final itemDetail in filteredRawItemDetails) {
      final itemCode = itemDetail['ItemCode']?.toString().trim() ?? '';
      final batchNo = itemDetail['BatchNo']?.toString().trim() ?? '';
      final txtPkg = itemDetail['txt_pkg']?.toString().trim() ?? '';
      final cmbUnit = itemDetail['cmb_unit']?.toString().trim() ?? '';

      if (itemCode.isEmpty || batchNo.isEmpty || txtPkg.isEmpty || cmbUnit.isEmpty) {
        continue;
      }

      final masterItem = allItemsMaster.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['ItemCode']?.toString().trim() == itemCode,
        orElse: () => null,
      );
      final itemName = masterItem?['ItemName']?.toString().trim() ?? 'N/A';
      final itemType = masterItem?['ItemType']?.toString().trim() ?? 'N/A';

      final pkgUnit = '$txtPkg $cmbUnit'.trim();
      final currentStock = double.tryParse(itemDetail['Currentstock']?.toString() ?? '0') ?? 0.0;

      processedList.add({
        'Item Code': itemCode,
        'Item Name': itemName,
        'Batch No': batchNo,
        'Package': pkgUnit,
        'Current Stock': currentStock,
        'Type': itemType,
      });
      currentTotalStock += currentStock;
    }

    allStockData = processedList;
    totalCurrentStock.value = currentTotalStock;
    _applyFilterAndSort();
  }

  /// Process a chunk of data
  Future<List<Map<String, dynamic>>> _processDataChunk(
      List<Map<String, dynamic>> itemDetails,
      List<Map<String, dynamic>> allItemsMaster
      ) async {
    final List<Map<String, dynamic>> processedList = [];

    for (final itemDetail in itemDetails) {
      final itemCode = itemDetail['ItemCode']?.toString().trim() ?? '';
      final batchNo = itemDetail['BatchNo']?.toString().trim() ?? '';
      final txtPkg = itemDetail['txt_pkg']?.toString().trim() ?? '';
      final cmbUnit = itemDetail['cmb_unit']?.toString().trim() ?? '';

      if (itemCode.isEmpty || batchNo.isEmpty || txtPkg.isEmpty || cmbUnit.isEmpty) {
        continue;
      }

      final masterItem = allItemsMaster.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['ItemCode']?.toString().trim() == itemCode,
        orElse: () => null,
      );
      final itemName = masterItem?['ItemName']?.toString().trim() ?? 'N/A';
      final itemType = masterItem?['ItemType']?.toString().trim() ?? 'N/A';

      final pkgUnit = '$txtPkg $cmbUnit'.trim();
      final currentStock = double.tryParse(itemDetail['Currentstock']?.toString() ?? '0') ?? 0.0;

      processedList.add({
        'Item Code': itemCode,
        'Item Name': itemName,
        'Batch No': batchNo,
        'Package': pkgUnit,
        'Current Stock': currentStock,
        'Type': itemType,
      });
    }

    return processedList;
  }

  /// Apply search filter and sorting to processed data
  void _applyFilterAndSort() {
    if (allStockData.isEmpty) {
      filteredStockData.value = [];
      totalItems.value = 0;
      totalPages.value = 0;
      return;
    }

    final search = searchQuery.value.toLowerCase().trim();

    // Apply search filter
    List<Map<String, dynamic>> filteredList = allStockData;
    if (search.isNotEmpty) {
      filteredList = allStockData.where((item) {
        final itemCode = item['Item Code']?.toString().toLowerCase() ?? '';
        final itemName = item['Item Name']?.toString().toLowerCase() ?? '';
        final batchNo = item['Batch No']?.toString().toLowerCase() ?? '';
        return itemCode.contains(search) || 
               itemName.contains(search) || 
               batchNo.contains(search);
      }).toList();
    }

    // Apply sorting
    filteredList.sort((a, b) {
      dynamic valA;
      dynamic valB;
      int compareResult = 0;

      switch (sortByColumn.value) {
        case 'Item Name':
          valA = a['Item Name']?.toString().toLowerCase() ?? '';
          valB = b['Item Name']?.toString().toLowerCase() ?? '';
          compareResult = valA.compareTo(valB);
          break;
        case 'Item Code':
          valA = a['Item Code']?.toString().toLowerCase() ?? '';
          valB = b['Item Code']?.toString().toLowerCase() ?? '';
          compareResult = valA.compareTo(valB);
          break;
        case 'Current Stock':
          valA = a['Current Stock'] ?? 0.0;
          valB = b['Current Stock'] ?? 0.0;
          if (valA is num && valB is num) {
            compareResult = valA.compareTo(valB);
          }
          break;
        case 'Type':
          valA = a['Type']?.toString().toLowerCase() ?? '';
          valB = b['Type']?.toString().toLowerCase() ?? '';
          compareResult = valA.compareTo(valB);
          break;
        default:
          compareResult = 0;
      }

      return sortAscending.value ? compareResult : -compareResult;
    });

    // Update pagination info
    totalItems.value = filteredList.length;
    totalPages.value = (totalItems.value / itemsPerPage.value).ceil();

    // Reset to first page if current page is out of bounds
    if (currentPage.value >= totalPages.value && totalPages.value > 0) {
      currentPage.value = 0;
    }

    // Store filtered data for pagination
    allStockData = filteredList;
    _updateDisplayedData();
  }

  /// Update the displayed data based on current page
  void _updateDisplayedData() {
    if (allStockData.isEmpty) {
      filteredStockData.value = [];
      return;
    }

    final startIndex = currentPage.value * itemsPerPage.value;
    final endIndex = (startIndex + itemsPerPage.value).clamp(0, allStockData.length);

    final pageData = allStockData.sublist(startIndex, endIndex);

    // Add Sr.No. to displayed data
    for (int i = 0; i < pageData.length; i++) {
      pageData[i]['Sr.No.'] = startIndex + i + 1;
    }

    filteredStockData.value = pageData;
    print('--- Displaying page ${currentPage.value + 1} of ${totalPages.value} (${pageData.length} items) ---');
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

  /// Clear processed data cache to force refresh
  void clearCache() {
    _hasProcessedData = false;
    _lastProcessedTime = null;
    _lastDataHash = '';
    allStockData.clear();
    filteredStockData.value = [];
    totalCurrentStock.value = 0.0;
    print('StockReportController: Cache cleared');
  }

  /// Get processing status info
  String getProcessingInfo() {
    if (isProcessingLargeDataset.value) {
      return 'Processing large dataset: ${(processingProgress.value * 100).toStringAsFixed(1)}%';
    }
    return 'Ready';
  }

  /// Get available page sizes for user selection
  List<int> get availablePageSizes => [25, 50, 100, 200, 500];

  /// Jump to first page
  void goToFirstPage() {
    currentPage.value = 0;
  }

  /// Jump to last page
  void goToLastPage() {
    if (totalPages.value > 0) {
      currentPage.value = totalPages.value - 1;
    }
  }

  /// Get current page info for display
  Map<String, dynamic> get pageInfo => {
    'current': currentPage.value + 1,
    'total': totalPages.value,
    'itemsPerPage': itemsPerPage.value,
    'totalItems': totalItems.value,
    'hasNext': hasNextPage,
    'hasPrevious': hasPreviousPage,
  };
}
