// lib/controllers/lazy_sales_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:developer'; // For logging

import '../util/csv_utils.dart';
import '../services/lazy_csv_service.dart';
import 'base_remote_controller.dart';

/// Enhanced SalesController that uses lazy loading for CSV data
class LazySalesController extends GetxController with BaseRemoteController {
  // Dependencies
  final LazyCsvService _lazyCsvService = Get.find<LazyCsvService>();

  // Required CSV types for sales data
  static const List<CsvType> _requiredCsvTypes = [
    CsvType.salesMaster,
    CsvType.salesDetails,
    CsvType.itemMaster,
  ];

  // Observable data
  final sales = <SalesEntry>[].obs;
  final RxBool isLoadingCsvData = false.obs;
  final RxDouble csvLoadingProgress = 0.0.obs;
  final RxString currentlyLoadingFile = ''.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    log('[LazySalesController] Initialized - ready for on-demand loading');
    // Don't load data automatically - wait for user action
  }

  /// Load sales data on-demand
  Future<void> loadSalesData({bool forceRefresh = false}) async {
    await guard(() => _loadSalesDataInternal(forceRefresh: forceRefresh));
  }

  /// Internal method to load sales data using lazy CSV service
  Future<void> _loadSalesDataInternal({bool forceRefresh = false}) async {
    try {
      isLoadingCsvData.value = true;
      csvLoadingProgress.value = 0.0;
      sales.clear();

      log('🔄 LazySalesController: Starting lazy load of sales data...');

      // Load required CSV files on-demand
      final csvData = await _lazyCsvService.loadMultipleCsvs(
        _requiredCsvTypes,
        forceDownload: forceRefresh,
        onProgress: (csvType, progress) {
          currentlyLoadingFile.value = _getDisplayName(csvType);
          _updateOverallProgress();
        },
      );

      // Check if we have the essential data
      final salesMasterCsv = csvData[CsvType.salesMaster] ?? '';
      final salesDetailsCsv = csvData[CsvType.salesDetails] ?? '';
      final itemMasterCsv = csvData[CsvType.itemMaster] ?? '';

      if (salesMasterCsv.isEmpty) {
        throw Exception('Sales Master CSV is empty or failed to load');
      }

      csvLoadingProgress.value = 0.5;
      currentlyLoadingFile.value = 'Processing data...';

      // Parse the CSV data
      await _processSalesData(salesMasterCsv, salesDetailsCsv, itemMasterCsv);

      csvLoadingProgress.value = 1.0;
      currentlyLoadingFile.value = 'Complete';
      
      log('✅ LazySalesController: Successfully loaded ${sales.length} sales entries');

    } catch (e, st) {
      log('❌ LazySalesController: Error loading sales data: $e\n$st');
      error.value = 'Failed to load sales data: $e';
      sales.clear();
    } finally {
      isLoadingCsvData.value = false;
      currentlyLoadingFile.value = '';
    }
  }

  /// Process sales data from CSV strings
  Future<void> _processSalesData(
    String salesMasterCsv,
    String salesDetailsCsv,
    String itemMasterCsv,
  ) async {
    // Parse ItemMaster.csv for item name lookup
    final itemMasterMaps = CsvUtils.toMaps(itemMasterCsv, ignoreInvalidRows: true);
    final Map<String, String> itemNameLookup = {};
    
    for (final itemMap in itemMasterMaps) {
      final itemCode = itemMap['ItemCode']?.toString().trim() ?? '';
      final itemName = itemMap['ItemName']?.toString().trim() ?? 'Unknown Item';
      if (itemCode.isNotEmpty) {
        itemNameLookup[itemCode] = itemName;
      }
    }

    // Parse SalesInvoiceDetails.csv if available
    final Map<String, List<SalesItemDetail>> detailsGroupedByBillNo = {};
    if (salesDetailsCsv.isNotEmpty) {
      final salesDetailsMaps = CsvUtils.toMaps(salesDetailsCsv, ignoreInvalidRows: true);
      
      for (final detailMap in salesDetailsMaps) {
        final billNo = detailMap['BillNo']?.toString().trim() ?? '';
        if (billNo.isEmpty) continue;

        final itemCode = detailMap['ItemCode']?.toString().trim() ?? '';
        final itemName = itemNameLookup[itemCode] ?? 'Unknown Item';
        
        final detail = SalesItemDetail(
          billNo: billNo,
          itemCode: itemCode,
          itemName: itemName,
          batchNo: detailMap['BatchNo']?.toString().trim() ?? '',
          packing: detailMap['Packing']?.toString().trim() ?? '',
          quantity: _parseDouble(detailMap['Quantity']),
          rate: _parseDouble(detailMap['Rate']),
          amount: _parseDouble(detailMap['Amount']),
        );

        detailsGroupedByBillNo.putIfAbsent(billNo, () => []).add(detail);
      }
    }

    // Process SalesInvoiceMaster.csv
    final salesMasterMaps = CsvUtils.toMaps(salesMasterCsv, ignoreInvalidRows: true);
    final List<SalesEntry> processedSales = [];

    for (final salesMap in salesMasterMaps) {
      final billNo = salesMap['BillNo']?.toString().trim() ?? '';
      if (billNo.isEmpty) continue;

      final salesEntry = SalesEntry(
        billNo: billNo,
        partyName: salesMap['PartyName']?.toString().trim() ?? '',
        entryDate: salesMap['EntryDate']?.toString().trim() ?? '',
        totalAmount: _parseDouble(salesMap['TotalAmount']),
        items: detailsGroupedByBillNo[billNo] ?? [],
      );

      processedSales.add(salesEntry);
    }

    // Update the observable list
    sales.assignAll(processedSales);
  }

  /// Check if CSV data is currently loading
  bool get isAnyFileLoading {
    return _requiredCsvTypes.any((type) => _lazyCsvService.isLoading(type));
  }

  /// Get loading states for all required CSV files
  Map<CsvType, CsvLoadingState> get csvLoadingStates {
    final Map<CsvType, CsvLoadingState> states = {};
    for (final csvType in _requiredCsvTypes) {
      states[csvType] = _lazyCsvService.getLoadingState(csvType);
    }
    return states;
  }

  /// Update overall progress based on individual file progress
  void _updateOverallProgress() {
    double totalProgress = 0.0;
    for (final csvType in _requiredCsvTypes) {
      totalProgress += _lazyCsvService.getProgress(csvType);
    }
    csvLoadingProgress.value = totalProgress / _requiredCsvTypes.length;
  }

  /// Clear cached data for sales-related CSV files
  Future<void> clearSalesCache() async {
    for (final csvType in _requiredCsvTypes) {
      await _lazyCsvService.clearCsv(csvType);
    }
    sales.clear();
    log('🧹 LazySalesController: Cleared sales CSV cache');
  }

  /// Refresh sales data by forcing a fresh download
  Future<void> refreshSalesData() async {
    await loadSalesData(forceRefresh: true);
  }

  /// Helper method to parse double values safely
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0.0;
    }
    return 0.0;
  }

  /// Get display name for CSV type
  String _getDisplayName(CsvType csvType) {
    switch (csvType) {
      case CsvType.salesMaster:
        return 'Sales Master';
      case CsvType.salesDetails:
        return 'Sales Details';
      case CsvType.itemMaster:
        return 'Item Master';
      default:
        return csvType.filename;
    }
  }

  /// Get memory usage info for debugging
  Map<String, dynamic> getMemoryInfo() {
    return {
      'salesEntries': sales.length,
      'csvMemoryUsage': '${_lazyCsvService.memoryUsageMB.value.toStringAsFixed(1)}MB',
      'isMemoryWarning': _lazyCsvService.isMemoryWarning.value,
      'cacheInfo': _lazyCsvService.getCacheInfo(),
    };
  }

  @override
  void onClose() {
    log('[LazySalesController] Disposed');
    super.onClose();
  }
}

// --- Data Models (same as original) ---

/// Represents a single detailed item within a sales invoice.
class SalesItemDetail {
  final String billNo;
  final String itemCode;
  final String itemName;
  final String batchNo;
  final String packing;
  final double quantity;
  final double rate;
  final double amount;

  SalesItemDetail({
    required this.billNo,
    required this.itemCode,
    required this.itemName,
    required this.batchNo,
    required this.packing,
    required this.quantity,
    required this.rate,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'BillNo': billNo,
      'ItemCode': itemCode,
      'ItemName': itemName,
      'BatchNo': batchNo,
      'Packing': packing,
      'Quantity': quantity,
      'Rate': rate,
      'Amount': amount,
    };
  }
}

/// Represents a complete sales entry combining data from multiple CSVs.
class SalesEntry {
  final String billNo;
  final String partyName;
  final String entryDate;
  final double totalAmount;
  final List<SalesItemDetail> items;

  SalesEntry({
    required this.billNo,
    required this.partyName,
    required this.entryDate,
    required this.totalAmount,
    required this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'BillNo': billNo,
      'PartyName': partyName,
      'TotalAmount': totalAmount,
      'EntryDate': entryDate,
      'Items': items.map((item) => item.toMap()).toList(),
    };
  }
}