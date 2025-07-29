// lib/controllers/stock_report_controller.dart

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import '../services/CsvDataServices.dart';
import '../util/csv_utils.dart';

class StockReportController extends GetxController {
  var isLoading = true.obs;
  var errorMessage = Rx<String?>(null);
  var searchQuery = ''.obs;
  var itemTypeFilter = 'All'.obs; // New: Observable for ItemType filter

  var filteredStockData = <Map<String, dynamic>>[].obs;
  var totalCurrentStock = 0.0.obs;

  final CsvDataService _csvDataService = Get.find<CsvDataService>();

  @override
  void onInit() {
    super.onInit();
    ever(_csvDataService.itemDetailCsv, (_) => _applyFilter());
    ever(_csvDataService.itemMasterCsv, (_) => _applyFilter());
    ever(searchQuery, (_) => _applyFilter());
    ever(itemTypeFilter, (_) => _applyFilter()); // New: Listen to itemTypeFilter changes
    loadStockReport();
  }

  Future<void> loadStockReport({bool forceRefresh = false}) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _csvDataService.loadAllCsvs(forceDownload: forceRefresh);
      print('--- Raw Item Master CSV Data ---');
      print(_csvDataService.itemMasterCsv.value.isEmpty ? 'Item Master CSV is empty.' : _csvDataService.itemMasterCsv.value);
      print('--- Raw Item Detail CSV Data ---');
      print(_csvDataService.itemDetailCsv.value.isEmpty ? 'Item Detail CSV is empty.' : _csvDataService.itemDetailCsv.value);

      _applyFilter();

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

  // New: Method to get unique Item Types for the dropdown
  List<String> getUniqueItemTypes() {
    if (_csvDataService.itemMasterCsv.value.isEmpty) {
      return ['All'];
    }
    final List<Map<String, dynamic>> allItemsMaster =
    CsvUtils.toMaps(_csvDataService.itemMasterCsv.value); // No specific stringColumns needed here
    final Set<String> types = {'All'}; // Always include 'All' option
    for (final item in allItemsMaster) {
      final itemType = item['ItemType']?.toString().trim();
      if (itemType != null && itemType.isNotEmpty) {
        types.add(itemType);
      }
    }
    return types.toList()..sort();
  }


  void _applyFilter() {
    if (_csvDataService.itemDetailCsv.value.isEmpty || _csvDataService.itemMasterCsv.value.isEmpty) {
      filteredStockData.value = [];
      totalCurrentStock.value = 0.0;
      return;
    }

    final search = searchQuery.value.toLowerCase().trim();
    final selectedItemType = itemTypeFilter.value; // Get selected item type
    final List<Map<String, dynamic>> processedList = [];
    int srNo = 1;
    double currentTotalStock = 0.0;

    // ONLY 'BatchNo' is specified as stringColumn for ItemDetail.csv
    final List<Map<String, dynamic>> allItemDetails =
    CsvUtils.toMaps(
        _csvDataService.itemDetailCsv.value,
        stringColumns: ['BatchNo'] // <--- ONLY BatchNo here
    );
    // ItemMaster CSV can usually have ItemCode treated as string if it might have leading zeros
    // or alphanumeric IDs. If it's purely numeric and you don't care about leading zeros,
    // you can remove 'ItemCode' from this list. I'll leave it as good practice for IDs.
    final List<Map<String, dynamic>> allItemsMaster =
    CsvUtils.toMaps(
        _csvDataService.itemMasterCsv.value,
        stringColumns: ['ItemCode'] // Keep ItemCode as string if it can have leading zeros
    );

    print('--- Parsed Item Master Data (List<Map<String, dynamic>>) ---');
    print(allItemsMaster.isEmpty ? 'Parsed Item Master is empty.' : allItemsMaster);
    print('--- Parsed Item Detail Data (List<Map<String, dynamic>>) ---');
    print(allItemDetails.isEmpty ? 'Parsed Item Detail is empty.' : allItemDetails);


    final filteredRawItemDetails = allItemDetails.where((itemDetail) {
      // Ensure 'Currentstock' is parsed as double here for calculations
      final currentStock = double.tryParse(itemDetail['Currentstock']?.toString() ?? '0') ?? 0.0;
      return currentStock != 0;
    }).toList();

    for (final itemDetail in filteredRawItemDetails) {
      // ItemCode, txt_pkg, cmb_unit will be parsed by CSV utility's default behavior.
      // BatchNo will be explicitly string.
      final itemCode = itemDetail['ItemCode']?.toString().trim() ?? '';
      final batchNo = itemDetail['BatchNo']?.toString().trim() ?? ''; // This will be '002' if in CSV
      final txtPkg = itemDetail['txt_pkg']?.toString().trim() ?? '';
      final cmbUnit = itemDetail['cmb_unit']?.toString().trim() ?? '';

      if (itemCode.isEmpty || batchNo.isEmpty || txtPkg.isEmpty || cmbUnit.isEmpty) {
        print('Skipping itemDetail due to missing essential fields: $itemDetail');
        continue;
      }

      final masterItem = allItemsMaster
          .firstWhereOrNull((item) => item['ItemCode']?.toString().trim() == itemCode);
      final itemName = masterItem?['ItemName']?.toString().trim() ?? 'N/A';
      final itemType = masterItem?['ItemType']?.toString().trim() ?? 'N/A'; // Get itemType

      final pkgUnit = '$txtPkg $cmbUnit'.trim();
      final currentStock = double.tryParse(itemDetail['Currentstock']?.toString() ?? '0') ?? 0.0;

      // Apply search query and ItemType filter
      final bool matchesSearch = search.isEmpty ||
          itemCode.toLowerCase().contains(search) ||
          itemName.toLowerCase().contains(search);

      final bool matchesItemType = selectedItemType == 'All' || itemType == selectedItemType;

      if (matchesSearch && matchesItemType) { // Combined filter
        processedList.add({
          'Sr.No.': srNo++,
          'Item Code': itemCode,
          'Item Name': itemName,
          'Batch No': batchNo, // This will now correctly be '002' if CSV had '002'
          'Package': pkgUnit,
          'Current Stock': currentStock,
          'Type': itemType,
        });
        currentTotalStock += currentStock;
      }
    }
    filteredStockData.value = processedList;
    totalCurrentStock.value = currentTotalStock;

    print('--- Final Filtered Stock Data (after processing) ---');
    print(filteredStockData.isEmpty ? 'No filtered stock data.' : filteredStockData);
    print('--- Calculated Total Current Stock: ${totalCurrentStock.value} ---');
  }
}