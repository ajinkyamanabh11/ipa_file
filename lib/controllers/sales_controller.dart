
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:developer'; // For logging
import 'dart:isolate';
import 'dart:async';

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
  
  // Progress tracking for data processing
  final RxBool isProcessingData = false.obs;
  final RxString processingMessage = ''.obs;
  final RxDouble processingProgress = 0.0.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    log('[SalesController] Initializing and loading sales data...');
    // Guard ensures that the async operation is handled safely (e.g., preventing multiple calls).
    guard(() => _loadSales(forceRefresh: true));
  }

  /// Public method to trigger fetching sales data, with an option to force a fresh download.
  Future<void> fetchSales({bool forceRefresh = false}) async => guard(() => _loadSales(forceRefresh: forceRefresh));

  /// Private method to load and process sales data from multiple CSVs.
  Future<void> _loadSales({bool forceRefresh = false}) async {
    try {
      isProcessingData.value = true;
      processingMessage.value = 'Loading data...';
      processingProgress.value = 0.0;

      // 1. Load all necessary CSVs from Google Drive (or cache).
      await _csvDataService.loadAllCsvs(forceDownload: forceRefresh);

      processingMessage.value = 'Processing sales data...';
      processingProgress.value = 0.1;

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

      // 2. Parse ItemMaster.csv into a lookup map for efficient ItemName retrieval.
      processingMessage.value = 'Processing item master data...';
      processingProgress.value = 0.2;
      
      final List<Map<String, dynamic>> itemMasterMaps = await _processItemMasterData(itemMasterCsv);
      final Map<String, String> itemCodeToName = {
        for (var item in itemMasterMaps)
          (item['ItemCode']?.toString() ?? ''): (item['ItemName']?.toString() ?? '')
      };
      log('✅ SalesController: ItemMaster data parsed. Total items: ${itemMasterMaps.length}');

      // 3. Process SalesInvoiceDetails.csv and group details by BillNo.
      processingMessage.value = 'Processing sales details...';
      processingProgress.value = 0.4;
      
      final Map<String, List<SalesItemDetail>> billNoToDetails = await _processSalesDetailsData(
        salesInvoiceDetailsCsv, 
        itemCodeToName
      );
      log('✅ SalesController: SalesInvoiceDetails data parsed and grouped. Number of BillNo groups: ${billNoToDetails.length}');

      // 4. Process SalesInvoiceMaster.csv and combine with the grouped details.
      processingMessage.value = 'Processing sales master data...';
      processingProgress.value = 0.6;
      
      final List<SalesEntry> processedSales = await _processSalesMasterData(
        salesMasterCsv, 
        billNoToDetails
      );

      processingMessage.value = 'Finalizing data...';
      processingProgress.value = 0.9;

      sales.value = processedSales; // Update the observable list
      log('✅ SalesController: Sales data processed successfully with details. Total sales entries: ${sales.length}');

    } catch (e, st) {
      log('[SalesController] ❌ Error loading sales data: $e\n$st');
      sales.clear(); // Clear data on error
    } finally {
      isProcessingData.value = false;
      processingMessage.value = '';
      processingProgress.value = 0.0;
      log('[SalesController] Loading finished. isLoadingSales: false');
    }
  }

  /// Process ItemMaster data in isolate
  Future<List<Map<String, dynamic>>> _processItemMasterData(String itemMasterCsv) async {
    if (itemMasterCsv.isEmpty) return [];
    
    return await compute(CsvUtils.toMapsFromArgs, {
      'csvData': itemMasterCsv,
      'stringColumns': ['ItemCode', 'ItemName'],
    });
  }

  /// Process SalesDetails data in isolate
  Future<Map<String, List<SalesItemDetail>>> _processSalesDetailsData(
    String salesInvoiceDetailsCsv, 
    Map<String, String> itemCodeToName
  ) async {
    if (salesInvoiceDetailsCsv.isEmpty) return {};
    
    final List<Map<String, dynamic>> salesDetailsMaps = await compute(CsvUtils.toMapsFromArgs, {
      'csvData': salesInvoiceDetailsCsv,
      'stringColumns': ['BillNo', 'Itemcode', 'batchno', 'Packing'],
    });
    
    final Map<String, List<SalesItemDetail>> billNoToDetails = {};
    
    // Process in chunks to avoid blocking
    const int chunkSize = 1000;
    for (int i = 0; i < salesDetailsMaps.length; i += chunkSize) {
      final end = (i + chunkSize < salesDetailsMaps.length) ? i + chunkSize : salesDetailsMaps.length;
      final chunk = salesDetailsMaps.sublist(i, end);
      
      for (var detail in chunk) {
        final billNo = detail['Billno']?.toString() ?? '';
        if (billNo.isEmpty) {
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
      
      // Small delay to prevent blocking
      if (i % (chunkSize * 5) == 0) {
        await Future.delayed(Duration(milliseconds: 1));
      }
    }
    
    return billNoToDetails;
  }

  /// Process SalesMaster data in isolate
  Future<List<SalesEntry>> _processSalesMasterData(
    String salesMasterCsv, 
    Map<String, List<SalesItemDetail>> billNoToDetails
  ) async {
    if (salesMasterCsv.isEmpty) return [];
    
    final List<Map<String, dynamic>> salesMasterMaps = await compute(CsvUtils.toMapsFromArgs, {
      'csvData': salesMasterCsv,
      'stringColumns': ['Billno', 'invoicedate', 'entrydate'],
    });

    final List<SalesEntry> processedSales = [];
    
    // Process in chunks
    const int chunkSize = 500;
    for (int i = 0; i < salesMasterMaps.length; i += chunkSize) {
      final end = (i + chunkSize < salesMasterMaps.length) ? i + chunkSize : salesMasterMaps.length;
      final chunk = salesMasterMaps.sublist(i, end);
      
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
      
      // Small delay to prevent blocking
      if (i % (chunkSize * 3) == 0) {
        await Future.delayed(Duration(milliseconds: 1));
      }
    }
    
    return processedSales;
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
}
