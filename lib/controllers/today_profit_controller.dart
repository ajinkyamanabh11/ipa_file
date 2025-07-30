// import 'package:flutter/material.dart'; // Keep for DateUtils
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
// import '../constants/paths.dart';
// import '../services/CsvDataServices.dart';
// import '../services/google_drive_service.dart';
// import '../util/csv_utils.dart';
// // NEW IMPORT
// import 'dart:developer';
//
// class TodayProfitController extends GetxController {
//   final GoogleDriveService drive = Get.find<GoogleDriveService>();
//   final CsvDataService _csvDataService = Get.find<CsvDataService>(); // Get CsvDataService instance
//
//   final RxDouble todayTotalProfit = 0.0.obs;
//   final RxBool isLoadingTodayProfit = false.obs;
//
//   @override
//   void onInit() {
//     super.onInit();
//     // Load today's profit as soon as the controller is initialized
//     loadTodayProfit();
//   }
//
//   Future<void> loadTodayProfit() async {
//     isLoadingTodayProfit.value = true;
//     todayTotalProfit.value = 0.0; // Reset before loading
//
//     final today = DateUtils.dateOnly(DateTime.now());
//     log('📆 TodayProfitController: Loading today\'s profit for $today');
//
//     try {
//       // 🔴 CRITICAL CHANGE: Use the centralized CsvDataService to get CSV data.
//       // Force download here to ensure the dashboard profit is always fresh.
//       await _csvDataService.loadAllCsvs(forceDownload: true);
//
//       final masterCsv = _csvDataService.salesMasterCsv.value;
//       final detailsCsv = _csvDataService.salesDetailsCsv.value;
//       final itemMasterCsv = _csvDataService.itemMasterCsv.value;
//       final itemDetailCsv = _csvDataService.itemDetailCsv.value;
//
//       // Validate that CSV data is available
//       if (masterCsv.isEmpty || detailsCsv.isEmpty || itemMasterCsv.isEmpty || itemDetailCsv.isEmpty) {
//         log('⚠️ TodayProfitController: One or more required CSVs are empty. Cannot calculate today\'s profit.');
//         todayTotalProfit.value = 0.0;
//         return;
//       }
//
//       final masterRows = CsvUtils.toMaps(masterCsv);
//       final detailRows = CsvUtils.toMaps(detailsCsv);
//       final itemRows = CsvUtils.toMaps(itemMasterCsv);
//       final itemDetailRows = CsvUtils.toMaps(itemDetailCsv);
//
//       final filteredInvoices = masterRows.where((r) {
//         final rawDate = r['invoicedate'] ?? r['challandate'] ?? r['receiptdate'];
//         if (rawDate == null) return false;
//
//         try {
//           final dateStr = rawDate.toString().split('T').first;
//           final parsed = DateTime.tryParse(dateStr) ?? DateFormat('dd/MM/yyyy').parseStrict(dateStr);
//           return parsed.isAtSameMomentAs(today); // Check if it's exactly today
//         } catch (_) {
//           return false;
//         }
//       }).toList();
//
//       final Map<String, List<Map<String, dynamic>>> detailsByInvoice = {};
//       for (final row in detailRows) {
//         final bill = row['billno']?.toString().trim().toUpperCase() ?? '';
//         if (bill.isNotEmpty) {
//           detailsByInvoice.putIfAbsent(bill, () => []).add(row);
//         }
//       }
//
//       final Map<String, Map<String, dynamic>> itemMap = {
//         for (var row in itemRows)
//           row['itemcode']?.toString().trim().toUpperCase() ?? '': row,
//       };
//
//       final Map<String, List<Map<String, dynamic>>> itemDetailsByItemBatch = {};
//       for (var row in itemDetailRows) {
//         final itemCode = row['ItemCode']?.toString().trim().toUpperCase() ?? '';
//         final batchNo = row['BatchNo']?.toString().trim().toUpperCase() ?? '';
//         final key = '${itemCode}_${batchNo}';
//         itemDetailsByItemBatch.putIfAbsent(key, () => []).add(row);
//       }
//
//       double currentDayProfit = 0.0;
//
//       for (final inv in filteredInvoices) {
//         final invoiceNo = inv['Billno']?.toString().trim().toUpperCase() ?? '';
//
//         if (invoiceNo.isEmpty) continue;
//
//         final matchingLines = detailsByInvoice[invoiceNo] ?? [];
//
//         for (final d in matchingLines) {
//           final itemCode = d['itemcode']?.toString().trim().toUpperCase();
//           final batchNo = d['batchno']?.toString().trim().toUpperCase() ?? '';
//           final salesPacking = _normalizePacking(d['packing']!.toString());
//
//           final salesDetailQty = num.tryParse('${d['qty']}') ?? 0;
//           final salesDetailPrice = double.tryParse('${d['CGSTTaxableAmt']}') ?? 0.0;
//
//           if (salesDetailQty <= 0 || itemCode == null || itemCode.isEmpty) continue;
//
//           // Item details lookup logic (remains the same)
//           final lookupKey = '${itemCode}_${batchNo}';
//           Map<String, dynamic>? matchingDetail;
//
//           List<Map<String, dynamic>> potentialMatches = [];
//
//           if (itemDetailsByItemBatch.containsKey(lookupKey)) {
//             potentialMatches = itemDetailsByItemBatch[lookupKey]!;
//           }
//
//           if (potentialMatches.isEmpty) {
//             potentialMatches = itemDetailRows.where(
//                     (detail) => detail['ItemCode']?.toString().trim().toUpperCase() == itemCode &&
//                     (detail['BatchNo']?.toString().trim().toUpperCase() == '..' ||
//                         detail['BatchNo']?.toString().trim().isEmpty == true)
//             ).toList();
//           }
//
//           if (potentialMatches.isNotEmpty) {
//             matchingDetail = potentialMatches.firstWhereOrNull(
//                     (detail) {
//                   final itemDetailTxtPkg = detail['txt_pkg']?.toString().trim() ?? '';
//                   final itemDetailCmbUnit = detail['cmb_unit']?.toString().trim() ?? '';
//                   final itemDetailPacking = _normalizePacking('$itemDetailTxtPkg$itemDetailCmbUnit');
//                   return itemDetailPacking == salesPacking;
//                 }
//             );
//           }
//
//           final purcPricePerUnit = double.tryParse('${matchingDetail?['PurchasePrice']}') ?? 0.0;
//           final totalPurchase = purcPricePerUnit * salesDetailQty;
//
//           final profitCalculated = salesDetailPrice - totalPurchase;
//           currentDayProfit += profitCalculated;
//         }
//       }
//       todayTotalProfit.value = currentDayProfit;
//       log('✅ TodayProfitController: Today\'s total profit: ₹${todayTotalProfit.value.toStringAsFixed(2)}');
//     } catch (e, st) {
//       log('[TodayProfitController] ❌ Error loading today\'s profit: $e');
//       log('$st');
//       todayTotalProfit.value = 0.0;
//     } finally {
//       isLoadingTodayProfit.value = false;
//       log('TodayProfitController: Loading finished. isLoadingTodayProfit: ${isLoadingTodayProfit.value}');
//     }
//   }
//
//   String _normalizePacking(String packing) {
//     if (packing == null || packing.isEmpty) return '';
//     return packing.replaceAllMapped(RegExp(r'(\d+)\.0(\D*)$'), (match) {
//       return '${match.group(1)}${match.group(2)}';
//     }).toUpperCase().trim();
//   }
// }