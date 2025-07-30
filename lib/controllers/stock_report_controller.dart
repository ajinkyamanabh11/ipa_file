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

  // Pagination variables
  var currentPage = 0.obs;
  var itemsPerPage = 25.obs; // Default items per page
  var totalItems = 0.obs;
  var totalPages = 0.obs;

  // Current page data and cached data
  var currentPageData = <Map<String, dynamic>>[].obs;
  var totalCurrentStock = 0.0.obs;

  // Data caching - cache processed data by page to avoid reprocessing
  final Map<String, List<Map<String, dynamic>>> _pageCache = {};
  final Map<String, double> _pageTotalStockCache = {};
  
  // Store all processed data for search and filtering
  var allProcessedData = <Map<String, dynamic>>[];
  var filteredDataIndices = <int>[]; // Indices of filtered data in allProcessedData
  
  // Memory management
  var isProcessingLargeDataset = false.obs;
  var processingProgress = 0.0.obs;
  var isLoadingPage = false.obs;

  final CsvDataService _csvDataService = Get.find<CsvDataService>();

  @override
  void onInit() {
    super.onInit();
    // Re-apply filter whenever any relevant observable changes
    ever(_csvDataService.itemDetailCsv, (_) => _onDataChanged());
    ever(_csvDataService.itemMasterCsv, (_) => _onDataChanged());
    ever(searchQuery, (_) => _onFilterChanged());
    ever(sortByColumn, (_) => _onFilterChanged());
    ever(sortAscending, (_) => _onFilterChanged());
    ever(currentPage, (_) => _loadCurrentPageData());
    ever(itemsPerPage, (_) => _onItemsPerPageChanged());

    loadStockReport(); // Initial data load
  }

  /// Handle data changes - clear cache and reload
  void _onDataChanged() {
    _clearCache();
    _processAllData();
  }

  /// Handle filter changes - clear cache and reapply filters
  void _onFilterChanged() {
    _clearCache();
    _applyFiltersAndSort();
    _loadCurrentPageData();
  }

  /// Handle items per page change
  void _onItemsPerPageChanged() {
    currentPage.value = 0; // Reset to first page
    _clearCache(); // Clear cache since page size changed
    _loadCurrentPageData();
  }

  /// Clear all caches
  void _clearCache() {
    _pageCache.clear();
    _pageTotalStockCache.clear();
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
  }

  /// Loads stock report data from CSVs.
  Future<void> loadStockReport({bool forceRefresh = false}) async {
    isLoading.value = true;
    errorMessage.value = null;
    processingProgress.value = 0.0;

    try {
      // Load CSV data (this is cached by CsvDataService)
      await _csvDataService.loadAllCsvs(forceDownload: forceRefresh);

      if (_csvDataService.itemDetailCsv.value.isEmpty || _csvDataService.itemMasterCsv.value.isEmpty) {
        errorMessage.value = 'Required CSV data (ItemMaster or ItemDetail) is empty. Please ensure files are on Google Drive.';
        return;
      }

      // Process all data once and store in memory
      await _processAllData();

      if (allProcessedData.isEmpty) {
        errorMessage.value = 'No stock data found after processing.';
      }

    } catch (e, st) {
      errorMessage.value = 'Failed to load stock data: $e';
      print('Error loading stock data: $e\n$st');
    } finally {
      isLoading.value = false;
      processingProgress.value = 1.0;
    }
  }

  /// Process all data once and store in memory for filtering/sorting
  Future<void> _processAllData() async {
    if (_csvDataService.itemDetailCsv.value.isEmpty || _csvDataService.itemMasterCsv.value.isEmpty) {
      allProcessedData.clear();
      _applyFiltersAndSort();
      return;
    }

    // Check if we're dealing with a large dataset
    final itemDetailLines = _csvDataService.itemDetailCsv.value.split('\n').length;
    final itemMasterLines = _csvDataService.itemMasterCsv.value.split('\n').length;
    isProcessingLargeDataset.value = (itemDetailLines > 1000 || itemMasterLines > 1000);

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

    if (isProcessingLargeDataset.value) {
      // Process in chunks for large datasets
      const int chunkSize = 500;
      for (int i = 0; i < filteredRawItemDetails.length; i += chunkSize) {
        final chunk = filteredRawItemDetails.skip(i).take(chunkSize).toList();
        final processedChunk = await _processDataChunk(chunk, allItemsMaster);
        
        processedList.addAll(processedChunk);
        
        // Update total stock
        for (final item in processedChunk) {
          currentTotalStock += item['Current Stock'] ?? 0.0;
        }
        
        // Update progress
        processingProgress.value = (i + chunkSize) / filteredRawItemDetails.length;
        
        // Allow UI to update
        await Future.delayed(Duration(milliseconds: 10));
      }
    } else {
      // Process normally for small datasets
      int processed = 0;
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
        
        processed++;
        if (processed % 100 == 0) {
          processingProgress.value = processed / filteredRawItemDetails.length;
          await Future.delayed(Duration(milliseconds: 1));
        }
      }
    }

    allProcessedData = processedList;
    totalCurrentStock.value = currentTotalStock;
    
    // Apply initial filters and load first page
    _applyFiltersAndSort();
    _loadCurrentPageData();
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

  /// Apply search filter and sorting to get filtered indices
  void _applyFiltersAndSort() {
    final search = searchQuery.value.toLowerCase().trim();

    // Apply search filter to get indices
    List<int> indices = [];
    if (search.isEmpty) {
      indices = List.generate(allProcessedData.length, (index) => index);
    } else {
      for (int i = 0; i < allProcessedData.length; i++) {
        final item = allProcessedData[i];
        final itemCode = item['Item Code']?.toString().toLowerCase() ?? '';
        final itemName = item['Item Name']?.toString().toLowerCase() ?? '';
        if (itemCode.contains(search) || itemName.contains(search)) {
          indices.add(i);
        }
      }
    }

    // Apply sorting to indices
    indices.sort((aIndex, bIndex) {
      final a = allProcessedData[aIndex];
      final b = allProcessedData[bIndex];
      
      dynamic valA;
      dynamic valB;
      int compareResult = 0;

      if (sortByColumn.value == 'Item Name') {
        valA = a['Item Name']?.toString().toLowerCase() ?? '';
        valB = b['Item Name']?.toString().toLowerCase() ?? '';
        compareResult = valA.compareTo(valB);
      } else if (sortByColumn.value == 'Current Stock') {
        valA = a['Current Stock'] ?? 0.0;
        valB = b['Current Stock'] ?? 0.0;
        if (valA is num && valB is num) {
          compareResult = valA.compareTo(valB);
        }
      }

      return sortAscending.value ? compareResult : -compareResult;
    });

    filteredDataIndices = indices;

    // Update pagination info
    totalItems.value = filteredDataIndices.length;
    totalPages.value = (totalItems.value / itemsPerPage.value).ceil();

    // Reset to first page if current page is out of bounds
    if (currentPage.value >= totalPages.value && totalPages.value > 0) {
      currentPage.value = 0;
    }
  }

  /// Load data for current page
  void _loadCurrentPageData() {
    if (filteredDataIndices.isEmpty) {
      currentPageData.value = [];
      return;
    }

    // Create cache key
    final cacheKey = '${currentPage.value}_${itemsPerPage.value}_${searchQuery.value}_${sortByColumn.value}_${sortAscending.value}';
    
    // Check if page data is cached
    if (_pageCache.containsKey(cacheKey)) {
      currentPageData.value = _pageCache[cacheKey]!;
      return;
    }

    isLoadingPage.value = true;

    try {
      final startIndex = currentPage.value * itemsPerPage.value;
      final endIndex = (startIndex + itemsPerPage.value).clamp(0, filteredDataIndices.length);

      final List<Map<String, dynamic>> pageData = [];
      
      for (int i = startIndex; i < endIndex; i++) {
        final dataIndex = filteredDataIndices[i];
        final item = Map<String, dynamic>.from(allProcessedData[dataIndex]);
        item['Sr.No.'] = i + 1; // Add serial number based on filtered position
        pageData.add(item);
      }

      // Cache the page data
      _pageCache[cacheKey] = pageData;
      currentPageData.value = pageData;

      print('--- Loaded page ${currentPage.value + 1} of ${totalPages.value} (${pageData.length} items) ---');
    } finally {
      isLoadingPage.value = false;
    }
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

  /// Get available items per page options
  List<int> get availableItemsPerPage {
    if (totalItems.value < 10) {
      return [totalItems.value > 0 ? totalItems.value : 10];
    }
    return [10, 25, 50, 100];
  }
}
