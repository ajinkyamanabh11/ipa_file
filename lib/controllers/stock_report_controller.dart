// lib/controllers/stock_report_controller.dart

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer';
import '../services/CsvDataServices.dart';
import '../util/csv_utils.dart';
import '../services/performance_monitor_service.dart';

class StockReportController extends GetxController {
  var isLoading = true.obs;
  var errorMessage = Rx<String?>(null);
  var searchQuery = ''.obs;

  // New observables for sorting
  var sortByColumn = 'Item Name'.obs;
  var sortAscending = true.obs;

  // Pagination support
  var currentPage = 0.obs;
  var pageSize = 100.obs;
  var totalRows = 0.obs;
  var hasMoreData = false.obs;

  // Optimized data storage
  var filteredStockData = <Map<String, dynamic>>[].obs;
  var totalCurrentStock = 0.0.obs;

  // Streaming and performance optimization
  StreamSubscription? _dataStreamSubscription;
  Timer? _debounceTimer;
  bool _isProcessing = false;

  final CsvDataService _csvDataService = Get.find<CsvDataService>();

  @override
  void onInit() {
    super.onInit();
    
    startPerformanceTiming('stock_controller_init');
    
    // Debounced reactive updates to prevent excessive processing
    _setupDebouncedListeners();
    
    loadStockReport(); // Initial data load
    
    stopPerformanceTiming('stock_controller_init');
  }

  @override
  void onClose() {
    _dataStreamSubscription?.cancel();
    _debounceTimer?.cancel();
    super.onClose();
  }

  void _setupDebouncedListeners() {
    // Debounced search to prevent excessive filtering
    ever(searchQuery, (_) => _debounceFilter());
    ever(sortByColumn, (_) => _debounceFilter());
    ever(sortAscending, (_) => _debounceFilter());
    
    // Listen to CSV data changes but with debouncing
    ever(_csvDataService.itemDetailCsv, (_) => _debounceFilter());
    ever(_csvDataService.itemMasterCsv, (_) => _debounceFilter());
  }

  void _debounceFilter() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_isProcessing) {
        _applyFilterAsync();
      }
    });
  }

  /// Public method to set the column to sort by.
  void setSortColumn(String column) {
    startPerformanceTiming('stock_sort_change');
    
    if (sortByColumn.value == column) {
      toggleSortOrder();
    } else {
      sortByColumn.value = column;
      sortAscending.value = true;
    }
    
    stopPerformanceTiming('stock_sort_change');
  }

  /// Public method to toggle the sort order (ascending/descending).
  void toggleSortOrder() {
    sortAscending.value = !sortAscending.value;
  }

  /// Load next page of data
  void loadNextPage() {
    if (hasMoreData.value && !isLoading.value) {
      startPerformanceTiming('stock_load_next_page');
      currentPage.value++;
      _applyFilterAsync();
      stopPerformanceTiming('stock_load_next_page');
    }
  }

  /// Reset pagination and reload
  void resetPagination() {
    startPerformanceTiming('stock_reset_pagination');
    currentPage.value = 0;
    filteredStockData.clear();
    _applyFilterAsync();
    stopPerformanceTiming('stock_reset_pagination');
  }

  /// Loads stock report data from CSVs with improved performance.
  Future<void> loadStockReport({bool forceRefresh = false}) async {
    if (_isProcessing) return;
    
    startPerformanceTiming('stock_load_report');
    _isProcessing = true;
    isLoading.value = true;
    errorMessage.value = null;
    
    try {
      await _csvDataService.loadAllCsvs(forceDownload: forceRefresh);
      
      if (_csvDataService.itemDetailCsv.value.isEmpty || _csvDataService.itemMasterCsv.value.isEmpty) {
        errorMessage.value = 'Required CSV data (ItemMaster or ItemDetail) is empty. Please ensure files are on Google Drive.';
        return;
      }

      // Get total row count for pagination
      totalRows.value = CsvUtils.getRowCount(_csvDataService.itemDetailCsv.value);
      
      await _applyFilterAsync();

    } catch (e, st) {
      errorMessage.value = 'Failed to load stock data: $e';
      log('Error loading stock data: $e\n$st');
    } finally {
      isLoading.value = false;
      _isProcessing = false;
      stopPerformanceTiming('stock_load_report');
    }
  }

  /// Optimized async filter application with streaming
  Future<void> _applyFilterAsync() async {
    if (_csvDataService.itemDetailCsv.value.isEmpty || _csvDataService.itemMasterCsv.value.isEmpty) {
      filteredStockData.value = [];
      totalCurrentStock.value = 0.0;
      return;
    }

    startPerformanceTiming('stock_apply_filter');
    
    try {
      final search = searchQuery.value.toLowerCase().trim();
      
      // Use async processing for large datasets
      final itemDetailsFuture = CsvUtils.toMapsAsync(
        _csvDataService.itemDetailCsv.value,
        stringColumns: ['BatchNo', 'ItemCode', 'txt_pkg', 'cmb_unit'],
      );
      
      final itemMasterFuture = CsvUtils.toMapsAsync(
        _csvDataService.itemMasterCsv.value,
        stringColumns: ['ItemCode', 'ItemName', 'ItemType'],
      );

      // Process both CSVs in parallel
      final results = await Future.wait([itemDetailsFuture, itemMasterFuture]);
      final allItemDetails = results[0];
      final allItemsMaster = results[1];

      // Create lookup map for efficient item name retrieval
      final itemMasterLookup = <String, Map<String, dynamic>>{};
      for (final item in allItemsMaster) {
        final itemCode = item['ItemCode']?.toString().trim() ?? '';
        if (itemCode.isNotEmpty) {
          itemMasterLookup[itemCode] = item;
        }
      }

      // Process data in chunks to avoid blocking UI
      await _processDataInChunks(allItemDetails, itemMasterLookup, search);

    } catch (e, st) {
      log('Error in _applyFilterAsync: $e\n$st');
      errorMessage.value = 'Error processing data: $e';
    } finally {
      stopPerformanceTiming('stock_apply_filter');
    }
  }

  /// Process data in chunks to maintain UI responsiveness
  Future<void> _processDataInChunks(
    List<Map<String, dynamic>> allItemDetails,
    Map<String, Map<String, dynamic>> itemMasterLookup,
    String search,
  ) async {
    startPerformanceTiming('stock_process_chunks');
    
    const chunkSize = 500;
    final List<Map<String, dynamic>> processedList = [];
    double currentTotalStock = 0.0;

    // Filter items with non-zero stock first
    final filteredRawItemDetails = allItemDetails.where((itemDetail) {
      final currentStock = double.tryParse(itemDetail['Currentstock']?.toString() ?? '0') ?? 0.0;
      return currentStock != 0;
    }).toList();

    // Process in chunks
    for (int i = 0; i < filteredRawItemDetails.length; i += chunkSize) {
      final endIndex = (i + chunkSize < filteredRawItemDetails.length) 
          ? i + chunkSize 
          : filteredRawItemDetails.length;
      
      final chunk = filteredRawItemDetails.sublist(i, endIndex);
      
      for (final itemDetail in chunk) {
        final itemCode = itemDetail['ItemCode']?.toString().trim() ?? '';
        final batchNo = itemDetail['BatchNo']?.toString().trim() ?? '';
        final txtPkg = itemDetail['txt_pkg']?.toString().trim() ?? '';
        final cmbUnit = itemDetail['cmb_unit']?.toString().trim() ?? '';

        if (itemCode.isEmpty || batchNo.isEmpty || txtPkg.isEmpty || cmbUnit.isEmpty) {
          continue;
        }

        final masterItem = itemMasterLookup[itemCode];
        final itemName = masterItem?['ItemName']?.toString().trim() ?? 'N/A';
        final itemType = masterItem?['ItemType']?.toString().trim() ?? 'N/A';

        final pkgUnit = '$txtPkg $cmbUnit'.trim();
        final currentStock = double.tryParse(itemDetail['Currentstock']?.toString() ?? '0') ?? 0.0;

        // Apply search query filter
        if (search.isEmpty ||
            itemCode.toLowerCase().contains(search) ||
            itemName.toLowerCase().contains(search)) {
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
      }

      // Yield control back to the UI thread periodically
      if (i % (chunkSize * 2) == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    // Apply sorting
    _sortProcessedList(processedList);

    // Apply pagination if needed
    final startIndex = currentPage.value * pageSize.value;
    final endIndex = (startIndex + pageSize.value < processedList.length)
        ? startIndex + pageSize.value
        : processedList.length;

    final paginatedList = (startIndex < processedList.length)
        ? processedList.sublist(startIndex, endIndex)
        : <Map<String, dynamic>>[];

    // Update pagination info
    hasMoreData.value = endIndex < processedList.length;

    // Re-assign Sr.No. for paginated results
    for (int i = 0; i < paginatedList.length; i++) {
      paginatedList[i]['Sr.No.'] = startIndex + i + 1;
    }

    // Update observables
    if (currentPage.value == 0) {
      filteredStockData.value = paginatedList;
    } else {
      filteredStockData.addAll(paginatedList);
    }
    
    totalCurrentStock.value = currentTotalStock;

    log('--- Processed stock data: ${processedList.length} total, ${paginatedList.length} in current page ---');
    log('--- Total Current Stock: ${totalCurrentStock.value} ---');
    
    stopPerformanceTiming('stock_process_chunks');
  }

  void _sortProcessedList(List<Map<String, dynamic>> processedList) {
    startPerformanceTiming('stock_sort_data');
    
    processedList.sort((a, b) {
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
    
    stopPerformanceTiming('stock_sort_data');
  }

  /// Stream-based data processing for very large datasets
  void loadStockReportStream() {
    startPerformanceTiming('stock_load_stream');
    
    _dataStreamSubscription?.cancel();
    
    if (_csvDataService.itemDetailCsv.value.isEmpty || _csvDataService.itemMasterCsv.value.isEmpty) {
      return;
    }

    isLoading.value = true;
    filteredStockData.clear();
    
    _dataStreamSubscription = CsvUtils.toMapsStream(
      _csvDataService.itemDetailCsv.value,
      stringColumns: ['BatchNo', 'ItemCode', 'txt_pkg', 'cmb_unit'],
      chunkSize: 1000,
    ).listen(
      (chunk) {
        // Process each chunk and update UI incrementally
        _processChunkAndUpdate(chunk);
      },
      onDone: () {
        isLoading.value = false;
        stopPerformanceTiming('stock_load_stream');
        log('Stream processing completed');
      },
      onError: (error) {
        errorMessage.value = 'Stream processing error: $error';
        isLoading.value = false;
        stopPerformanceTiming('stock_load_stream');
      },
    );
  }

  void _processChunkAndUpdate(List<Map<String, dynamic>> chunk) {
    // Process chunk and add to filtered data
    // This is a simplified version - you would apply filtering and sorting here
    final search = searchQuery.value.toLowerCase().trim();
    
    for (final item in chunk) {
      final currentStock = double.tryParse(item['Currentstock']?.toString() ?? '0') ?? 0.0;
      if (currentStock != 0) {
        final itemCode = item['ItemCode']?.toString().trim() ?? '';
        final itemName = 'Item Name'; // You would look this up from master data
        
        if (search.isEmpty || itemCode.toLowerCase().contains(search)) {
          filteredStockData.add({
            'Item Code': itemCode,
            'Item Name': itemName,
            'Current Stock': currentStock,
            // ... other fields
          });
        }
      }
    }
  }
}
