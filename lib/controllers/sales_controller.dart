
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:developer'; // For logging

import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import '../services/CsvDataServices.dart';
import 'base_remote_controller.dart';

// --- Data Models for Sales Data ---
// These models help structure the combined data from multiple CSVs.

/// Represents a single detailed item within a sales invoice.
class SalesItemDetail {
  final String billNo;
  final String itemCode;
  final String itemName; // Fetched from ItemMaster
  final String batchNo;
  final String packing;
  final double quantity;
  final double rate;
  final double amount;
  // Add other fields from SalesInvoiceDetails.csv if needed in the future

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

  // Converts the SalesItemDetail object to a Map for easy use in UI or debugging.
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

/// Represents a complete sales entry, combining master data with a list of detailed items.
class SalesEntry {
  final String accountName;
  final String billNo;
  final String paymentMode;
  final double amount; // Total bill amount
  final DateTime? entryDate;
  final List<SalesItemDetail> items; // List of detailed items for this sales entry

  SalesEntry({
    required this.accountName,
    required this.billNo,
    required this.paymentMode,
    required this.amount,
    this.entryDate,
    this.items = const [], // Default to an empty list
  });

  // Converts the SalesEntry object to a Map for compatibility with existing filtering
  // or if you need a flat map representation for some parts of the UI.
  Map<String, dynamic> toMap() {
    return {
      'AccountName': accountName,
      'BillNo': billNo,
      'PaymentMode': paymentMode,
      'Amount': amount,
      'EntryDate': entryDate,
      'Items': items.map((item) => item.toMap()).toList(), // Convert nested items to maps
    };
  }
}

// --- SalesController ---

class SalesController extends GetxController with BaseRemoteController {
  // Dependencies injected using GetX
  final GoogleDriveService drive = Get.find<GoogleDriveService>();
  final CsvDataService _csvDataService = Get.find<CsvDataService>();

  // Observable list to hold the processed sales data, now using the SalesEntry model.
  final sales = <SalesEntry>[].obs;
  
  // Track loading state and processing progress
  final RxBool isProcessingLargeDataset = false.obs;
  final RxDouble processingProgress = 0.0.obs;
  final RxString lastError = ''.obs;
  
  // Cache validation
  DateTime? _lastProcessedTime;
  bool _hasProcessedData = false;

  @override
  Future<void> onInit() async {
    super.onInit();
    log('[SalesController] Initializing and loading sales data...');
    
    // Check if CSV service already has data loaded
    if (_csvDataService.hasData('salesMasterCsv') && 
        _csvDataService.hasData('salesDetailsCsv') && 
        _csvDataService.hasData('itemMasterCsv')) {
      log('[SalesController] CSV data already available, processing...');
      guard(() => _processSalesData());
    } else {
      // Guard ensures that the async operation is handled safely (e.g., preventing multiple calls).
      guard(() => _loadSales(forceRefresh: false));
    }
  }

  /// Public method to trigger fetching sales data, with an option to force a fresh download.
  Future<void> fetchSales({bool forceRefresh = false}) async => guard(() => _loadSales(forceRefresh: forceRefresh));

  /// Private method to load and process sales data from multiple CSVs.
  Future<void> _loadSales({bool forceRefresh = false}) async {
    try {
      lastError.value = '';
      
      // Check if we already have processed data and it's recent (unless force refresh)
      if (!forceRefresh && _hasProcessedData && _lastProcessedTime != null) {
        final timeSinceLastProcess = DateTime.now().difference(_lastProcessedTime!);
        if (timeSinceLastProcess < Duration(minutes: 30) && sales.isNotEmpty) {
          log('[SalesController] Using recently processed sales data');
          return;
        }
      }

      // 1. Load all necessary CSVs from Google Drive (or cache).
      await _csvDataService.loadAllCsvs(forceDownload: forceRefresh);

      // 2. Process the data
      await _processSalesData();

    } catch (e, st) {
      log('[SalesController] ❌ Error loading sales data: $e\n$st');
      lastError.value = 'Failed to load sales data: ${e.toString()}';
      sales.clear(); // Clear data on error
    } finally {
      log('[SalesController] Loading finished.');
    }
  }

  /// Process sales data from CSV service
  Future<void> _processSalesData() async {
    try {
      // Get the raw CSV string content from the service.
      final String salesMasterCsv = _csvDataService.salesMasterCsv.value;
      final String salesInvoiceDetailsCsv = _csvDataService.salesDetailsCsv.value;
      final String itemMasterCsv = _csvDataService.itemMasterCsv.value;

      // Basic checks for empty data to provide informative logs.
      if (salesMasterCsv.isEmpty) {
        log('⚠️ SalesController: SalesInvoiceMaster.csv data is empty. Cannot process sales.');
        sales.clear(); // Clear any previous data
        return;
      }
      if (salesInvoiceDetailsCsv.isEmpty) {
        log('⚠️ SalesController: SalesInvoiceDetails.csv data is empty. Sales details will be missing.');
        // Continue, but detailed items list will be empty for sales entries.
      }
      if (itemMasterCsv.isEmpty) {
        log('⚠️ SalesController: ItemMaster.csv data is empty. Item names will be "Unknown Item".');
        // Continue, but item names will be placeholders.
      }

      log('⚡ SalesController: Starting data processing...');

      // Check if we're dealing with a large dataset
      final salesMasterLines = salesMasterCsv.split('\n').length;
      final salesDetailsLines = salesInvoiceDetailsCsv.split('\n').length;
      isProcessingLargeDataset.value = (salesMasterLines > 5000 || salesDetailsLines > 10000);

      if (isProcessingLargeDataset.value) {
        log('📊 SalesController: Large dataset detected, processing in chunks...');
        await _processLargeDataset(salesMasterCsv, salesInvoiceDetailsCsv, itemMasterCsv);
      } else {
        await _processNormalDataset(salesMasterCsv, salesInvoiceDetailsCsv, itemMasterCsv);
      }

      _hasProcessedData = true;
      _lastProcessedTime = DateTime.now();
      
      log('✅ SalesController: Sales data processed successfully. Total sales entries: ${sales.length}');

    } catch (e, st) {
      log('[SalesController] ❌ Error processing sales data: $e\n$st');
      lastError.value = 'Failed to process sales data: ${e.toString()}';
      sales.clear();
      rethrow;
    }
  }

  /// Process large dataset in chunks to prevent memory issues
  Future<void> _processLargeDataset(String salesMasterCsv, String salesInvoiceDetailsCsv, String itemMasterCsv) async {
    const int chunkSize = 1000; // Process 1000 sales entries at a time
    processingProgress.value = 0.0;

    // 2. Parse ItemMaster.csv into a lookup map for efficient ItemName retrieval.
    final List<Map<String, dynamic>> itemMasterMaps = CsvUtils.toMaps(
      itemMasterCsv,
      stringColumns: ['ItemCode', 'ItemName'],
    );
    final Map<String, String> itemCodeToName = {
      for (var item in itemMasterMaps)
        (item['ItemCode']?.toString() ?? ''): (item['ItemName']?.toString() ?? '')
    };
    log('✅ SalesController: ItemMaster data parsed. Total items: ${itemMasterMaps.length}');

    // 3. Parse SalesInvoiceDetails.csv and group details by BillNo.
    final List<Map<String, dynamic>> salesDetailsMaps = CsvUtils.toMaps(
      salesInvoiceDetailsCsv,
      stringColumns: [
        'BillNo', 'Itemcode', 'batchno', 'Packing',
      ],
    );
    
    // Group details by BillNo in chunks to prevent memory spikes
    final Map<String, List<SalesItemDetail>> billNoToDetails = {};
    for (int i = 0; i < salesDetailsMaps.length; i += chunkSize) {
      final chunk = salesDetailsMaps.skip(i).take(chunkSize).toList();
      
      for (var detail in chunk) {
        final billNo = detail['Billno']?.toString() ?? '';
        if (billNo.isEmpty) continue;

        final itemCode = detail['Itemcode']?.toString() ?? '';
        final batchNo = detail['batchno']?.toString() ?? '';
        final packing = detail['Packing']?.toString() ?? '';
        final quantity = double.tryParse('${detail['qty']}') ?? 0.0;
        final rate = double.tryParse('${detail['salesprice']}') ?? 0.0;
        final amount = double.tryParse('${detail['total']}') ?? 0.0;

        // Lookup ItemName from the parsed ItemMaster data.
        final itemName = itemCodeToName[itemCode] ?? 'Unknown Item';

        // Create a SalesItemDetail object for the current detail entry.
        final salesItemDetail = SalesItemDetail(
          billNo: billNo,
          itemCode: itemCode,
          itemName: itemName,
          batchNo: batchNo,
          packing: packing,
          quantity: quantity,
          rate: rate,
          amount: amount,
        );

        // Add the detail to the list for its corresponding BillNo.
        billNoToDetails.putIfAbsent(billNo, () => []).add(salesItemDetail);
      }
      
      // Update progress and allow UI updates
      processingProgress.value = (i + chunkSize) / salesDetailsMaps.length * 0.5; // 50% for details processing
      await Future.delayed(Duration(milliseconds: 10));
    }
    
    log('✅ SalesController: SalesInvoiceDetails data parsed and grouped. Number of BillNo groups: ${billNoToDetails.length}');

    // 4. Process SalesInvoiceMaster.csv in chunks
    final List<Map<String, dynamic>> salesMasterMaps = CsvUtils.toMaps(
      salesMasterCsv,
      stringColumns: [
        'Billno',
        'invoicedate', // Keep as string for parsing
        'entrydate',   // Keep as string for parsing
      ],
    );

    final List<SalesEntry> processedSales = [];
    for (int i = 0; i < salesMasterMaps.length; i += chunkSize) {
      final chunk = salesMasterMaps.skip(i).take(chunkSize).toList();
      
      for (var m in chunk) {
        final String billNo = m['Billno']?.toString() ?? '';
        final String accountName = m['accountname']?.toString() ?? '';
        final String paymentMode = m['paymentmode']?.toString() ?? '';
        final double totalBillAmount = double.tryParse('${m['totalbillamount']}') ?? 0.0;

        DateTime? entryDate;
        final rawDate = '${m['invoicedate'] ?? m['entrydate'] ?? ''}';
        if (rawDate.isNotEmpty && rawDate != 'null') {
          try {
            // Parse date, taking only the date part if time is included.
            entryDate = DateTime.parse(rawDate.split(' ').first);
          } catch (e) {
            log('⚠️ SalesController: Error parsing date "$rawDate" for BillNo $billNo: $e');
            // Ignore parse errors and leave entryDate as null.
          }
        }

        // Retrieve the list of detailed items for this BillNo.
        final List<SalesItemDetail> items = billNoToDetails[billNo] ?? [];

        // Create the final SalesEntry object.
        processedSales.add(
          SalesEntry(
            accountName: accountName,
            billNo: billNo,
            paymentMode: paymentMode,
            amount: totalBillAmount,
            entryDate: entryDate,
            items: items, // Attach the list of detailed items
          ),
        );
      }
      
      // Update progress and allow UI updates
      final masterProgress = (i + chunkSize) / salesMasterMaps.length * 0.5; // 50% for master processing
      processingProgress.value = 0.5 + masterProgress;
      await Future.delayed(Duration(milliseconds: 10));
    }

    sales.value = processedSales; // Update the observable list
    processingProgress.value = 1.0;
  }

  /// Process normal-sized dataset
  Future<void> _processNormalDataset(String salesMasterCsv, String salesInvoiceDetailsCsv, String itemMasterCsv) async {
    // 2. Parse ItemMaster.csv into a lookup map for efficient ItemName retrieval.
    // Ensure 'Itemcode' and 'ItemName' are treated as strings to preserve their exact values.
    final List<Map<String, dynamic>> itemMasterMaps = CsvUtils.toMaps(
      itemMasterCsv,
      stringColumns: ['ItemCode', 'ItemName'],
    );
    final Map<String, String> itemCodeToName = {
      for (var item in itemMasterMaps)
        (item['ItemCode']?.toString() ?? ''): (item['ItemName']?.toString() ?? '')
    };
    log('✅ SalesController: ItemMaster data parsed. Total items: ${itemMasterMaps.length}');

    // 3. Parse SalesInvoiceDetails.csv and group details by BillNo.
    // 'BillNo', 'Itemcode', 'batchno', 'Packing' are crucial identifiers and kept as strings.
    final List<Map<String, dynamic>> salesDetailsMaps = CsvUtils.toMaps(
      salesInvoiceDetailsCsv,
      stringColumns: [
        'BillNo', 'Itemcode', 'batchno', 'Packing',
      ],
    );
    final Map<String, List<SalesItemDetail>> billNoToDetails = {};
    for (var detail in salesDetailsMaps) {
      final billNo = detail['Billno']?.toString() ?? '';
      if (billNo.isEmpty) {
        log('⚠️ SalesController: Skipping SalesInvoiceDetails entry with empty BillNo.');
        continue; // Skip entries without a valid BillNo
      }

      final itemCode = detail['Itemcode']?.toString() ?? '';
      final batchNo = detail['batchno']?.toString() ?? '';
      final packing = detail['Packing']?.toString() ?? '';
      final quantity = double.tryParse('${detail['qty']}') ?? 0.0;
      final rate = double.tryParse('${detail['salesprice']}') ?? 0.0;
      final amount = double.tryParse('${detail['total']}') ?? 0.0;

      // Lookup ItemName from the parsed ItemMaster data.
      final itemName = itemCodeToName[itemCode] ?? 'Unknown Item';

      // Create a SalesItemDetail object for the current detail entry.
      final salesItemDetail = SalesItemDetail(
        billNo: billNo,
        itemCode: itemCode,
        itemName: itemName,
        batchNo: batchNo,
        packing: packing,
        quantity: quantity,
        rate: rate,
        amount: amount,
      );

      // Add the detail to the list for its corresponding BillNo.
      billNoToDetails.putIfAbsent(billNo, () => []).add(salesItemDetail);
    }
    log('✅ SalesController: SalesInvoiceDetails data parsed and grouped. Number of BillNo groups: ${billNoToDetails.length}');

    // 4. Process SalesInvoiceMaster.csv and combine with the grouped details.
    final List<Map<String, dynamic>> salesMasterMaps = CsvUtils.toMaps(
      salesMasterCsv,
      stringColumns: [
        'Billno',
        'invoicedate', // Keep as string for parsing
        'entrydate',   // Keep as string for parsing
      ],
    );

    final List<SalesEntry> processedSales = [];
    for (var m in salesMasterMaps) {
      final String billNo = m['Billno']?.toString() ?? '';
      final String accountName = m['accountname']?.toString() ?? '';
      final String paymentMode = m['paymentmode']?.toString() ?? '';
      final double totalBillAmount = double.tryParse('${m['totalbillamount']}') ?? 0.0;

      DateTime? entryDate;
      final rawDate = '${m['invoicedate'] ?? m['entrydate'] ?? ''}';
      if (rawDate.isNotEmpty && rawDate != 'null') {
        try {
          // Parse date, taking only the date part if time is included.
          entryDate = DateTime.parse(rawDate.split(' ').first);
        } catch (e) {
          log('⚠️ SalesController: Error parsing date "$rawDate" for BillNo $billNo: $e');
          // Ignore parse errors and leave entryDate as null.
        }
      }

      // Retrieve the list of detailed items for this BillNo.
      final List<SalesItemDetail> items = billNoToDetails[billNo] ?? [];

      // Create the final SalesEntry object.
      processedSales.add(
        SalesEntry(
          accountName: accountName,
          billNo: billNo,
          paymentMode: paymentMode,
          amount: totalBillAmount,
          entryDate: entryDate,
          items: items, // Attach the list of detailed items
        ),
      );
    }

    sales.value = processedSales; // Update the observable list
  }

  // --- Existing Getters (adapted to new SalesEntry model) ---

  double get totalCash => sales
      .where((s) => s.paymentMode.toLowerCase() == 'cash')
      .fold(0.0, (p, s) => p + s.amount);

  double get totalCredit => sales
      .where((s) => s.paymentMode.toLowerCase() == 'credit')
      .fold(0.0, (p, s) => p + s.amount);

  // --- Filter Method (adapted to new SalesEntry model) ---

  List<SalesEntry> filter({
    required String nameQ,
    required String billQ,
    DateTime? date,
  }) {
    return sales.where((s) {
      final name = s.accountName.toLowerCase();
      final bill = s.billNo.toLowerCase(); // BillNo is now reliably a string
      final dateMatch = date == null ||
          (s.entryDate != null && DateUtils.isSameDay(s.entryDate!, date));

      return name.contains(nameQ.toLowerCase()) &&
          bill.contains(billQ.toLowerCase()) &&
          dateMatch;
    }).toList();
  }

  /// Clear processed data cache to force refresh
  void clearCache() {
    _hasProcessedData = false;
    _lastProcessedTime = null;
    sales.clear();
    log('[SalesController] Cache cleared');
  }

  /// Get processing status info
  String getProcessingInfo() {
    if (isProcessingLargeDataset.value) {
      return 'Processing large dataset: ${(processingProgress.value * 100).toStringAsFixed(1)}%';
    }
    return 'Ready';
  }
}
