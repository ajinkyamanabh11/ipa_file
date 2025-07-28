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

  var filteredStockData = <Map<String, dynamic>>[].obs;
  var totalCurrentStock = 0.0.obs;

  final CsvDataService _csvDataService = Get.find<CsvDataService>();

  @override
  void onInit() {
    super.onInit();
    // Re-apply filter whenever any relevant observable changes
    ever(_csvDataService.itemDetailCsv, (_) => _applyFilter());
    ever(_csvDataService.itemMasterCsv, (_) => _applyFilter());
    ever(searchQuery, (_) => _applyFilter());
    ever(sortByColumn, (_) => _applyFilter()); // Trigger filter on sort column change
    ever(sortAscending, (_) => _applyFilter()); // Trigger filter on sort order change

    loadStockReport(); // Initial data load
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

  /// Loads stock report data from CSVs.
  Future<void> loadStockReport({bool forceRefresh = false}) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _csvDataService.loadAllCsvs(forceDownload: forceRefresh);
      print('--- Raw Item Master CSV Data ---');
      print(_csvDataService.itemMasterCsv.value.isEmpty ? 'Item Master CSV is empty.' : _csvDataService.itemMasterCsv.value);
      print('--- Raw Item Detail CSV Data ---');
      print(_csvDataService.itemDetailCsv.value.isEmpty ? 'Item Detail CSV is empty.' : _csvDataService.itemDetailCsv.value);

      _applyFilter(); // Apply filter after loading new data

      if (_csvDataService.itemDetailCsv.value.isEmpty || _csvDataService.itemMasterCsv.value.isEmpty) {
        errorMessage.value = 'Required CSV data (ItemMaster or ItemDetail) is empty. Please ensure files are on Google Drive.';
      }

    } catch (e, st) {
      errorMessage.value = 'Failed to load stock data: $e';
      print('Error loading stock data: $e\n$st');
    } finally {
      isLoading.value = false;
    }
  }

  /// Applies search filter and sorting to the stock data.
  void _applyFilter() {
    if (_csvDataService.itemDetailCsv.value.isEmpty || _csvDataService.itemMasterCsv.value.isEmpty) {
      filteredStockData.value = [];
      totalCurrentStock.value = 0.0;
      return;
    }

    final search = searchQuery.value.toLowerCase().trim();
    final List<Map<String, dynamic>> processedList = [];
    double currentTotalStock = 0.0;

    // Parse CSVs into lists of maps
    final List<Map<String, dynamic>> allItemDetails =
    CsvUtils.toMaps(
        _csvDataService.itemDetailCsv.value,
        stringColumns: ['BatchNo', 'ItemCode', 'txt_pkg', 'cmb_unit'] // Ensure these are strings
    );
    final List<Map<String, dynamic>> allItemsMaster =
    CsvUtils.toMaps(
        _csvDataService.itemMasterCsv.value,
        stringColumns: ['ItemCode', 'ItemName', 'ItemType'] // Ensure these are strings
    );

    print('--- Parsed Item Master Data (List<Map<String, dynamic>>) ---');
    print(allItemsMaster.isEmpty ? 'Parsed Item Master is empty.' : allItemsMaster);
    print('--- Parsed Item Detail Data (List<Map<String, dynamic>>) ---');
    print(allItemDetails.isEmpty ? 'Parsed Item Detail is empty.' : allItemDetails);

    final filteredRawItemDetails = allItemDetails.where((itemDetail) {
      final currentStock = double.tryParse(itemDetail['Currentstock']?.toString() ?? '0') ?? 0.0;
      return currentStock > 0;
    }).toList();

    for (final itemDetail in filteredRawItemDetails) {
      final itemCode = itemDetail['ItemCode']?.toString().trim() ?? '';
      final batchNo = itemDetail['BatchNo']?.toString().trim() ?? '';
      final txtPkg = itemDetail['txt_pkg']?.toString().trim() ?? '';
      final cmbUnit = itemDetail['cmb_unit']?.toString().trim() ?? '';

      if (itemCode.isEmpty || batchNo.isEmpty || txtPkg.isEmpty || cmbUnit.isEmpty) {
        print('Skipping itemDetail due to missing essential fields: $itemDetail');
        continue;
      }

      final masterItem = allItemsMaster
          .firstWhereOrNull((item) => item['ItemCode']?.toString().trim() == itemCode);
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

    // --- Apply Sorting ---
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
      // Add more sorting conditions here if you add more sortable columns

      return sortAscending.value ? compareResult : -compareResult;
    });

    // Re-assign Sr.No. after sorting
    for (int i = 0; i < processedList.length; i++) {
      processedList[i]['Sr.No.'] = i + 1;
    }

    filteredStockData.value = processedList;
    totalCurrentStock.value = currentTotalStock;

    print('--- Final Filtered & Sorted Stock Data ---');
    print(filteredStockData.isEmpty ? 'No filtered stock data.' : filteredStockData);
    print('--- Calculated Total Current Stock: ${totalCurrentStock.value} ---');
  }
}
