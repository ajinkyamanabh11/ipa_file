import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import 'dart:developer';

class TodayProfitController extends GetxController {
  final drive = Get.find<GoogleDriveService>();

  final RxDouble todayTotalProfit = 0.0.obs;
  final RxBool isLoadingTodayProfit = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Load today's profit as soon as the controller is initialized
    loadTodayProfit();
  }

  Future<void> loadTodayProfit() async {
    isLoadingTodayProfit.value = true;
    todayTotalProfit.value = 0.0; // Reset before loading

    final today = DateUtils.dateOnly(DateTime.now());

    try {
      final path = await SoftAgriPath.build(drive);
      final folderId = await drive.folderId(path);

      final fileIdMaster = await drive.fileId('SalesInvoiceMaster.csv', folderId);
      final csvMaster = await drive.downloadCsv(fileIdMaster);
      final masterRows = CsvUtils.toMaps(csvMaster);

      final filteredInvoices = masterRows.where((r) {
        final rawDate = r['invoicedate'] ?? r['challandate'] ?? r['receiptdate'];
        if (rawDate == null) return false;

        try {
          final dateStr = rawDate.toString().split('T').first;
          final parsed = DateTime.tryParse(dateStr) ?? DateFormat('dd/MM/yyyy').parseStrict(dateStr);
          return parsed.isAtSameMomentAs(today); // Check if it's exactly today
        } catch (_) {
          return false;
        }
      }).toList();

      final fileIdDetails = await drive.fileId('SalesInvoiceDetails.csv', folderId);
      final csvDetails = await drive.downloadCsv(fileIdDetails);
      final detailRows = CsvUtils.toMaps(csvDetails);

      final fileIdItem = await drive.fileId('ItemMaster.csv', folderId);
      final csvItem = await drive.downloadCsv(fileIdItem);
      final itemRows = CsvUtils.toMaps(csvItem);

      final fileIdItemDetail = await drive.fileId('ItemDetail.csv', folderId);
      final csvItemDetail = await drive.downloadCsv(fileIdItemDetail);
      final itemDetailRows = CsvUtils.toMaps(csvItemDetail);


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

      double currentDayProfit = 0.0;

      for (final inv in filteredInvoices) {
        final invoiceNo = inv['Billno']?.toString().trim().toUpperCase() ?? '';

        if (invoiceNo.isEmpty) continue;

        final matchingLines = detailsByInvoice[invoiceNo] ?? [];

        for (final d in matchingLines) {
          final itemCode = d['itemcode']?.toString().trim().toUpperCase();
          final batchNo = d['batchno']?.toString().trim().toUpperCase() ?? '';
          final salesPacking = _normalizePacking(d['packing']!.toString());

          final salesDetailQty = num.tryParse('${d['qty']}') ?? 0;
          final salesDetailPrice = double.tryParse('${d['CGSTTaxableAmt']}') ?? 0.0;

          if (salesDetailQty <= 0 || itemCode == null || itemCode.isEmpty) continue;

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
            matchingDetail = potentialMatches.firstWhereOrNull(
                    (detail) {
                  final itemDetailTxtPkg = detail['txt_pkg']?.toString().trim() ?? '';
                  final itemDetailCmbUnit = detail['cmb_unit']?.toString().trim() ?? '';
                  final itemDetailPacking = _normalizePacking('$itemDetailTxtPkg$itemDetailCmbUnit');
                  return itemDetailPacking == salesPacking;
                }
            );
          }

          final purcPricePerUnit = double.tryParse('${matchingDetail?['PurchasePrice']}') ?? 0.0;
          final totalPurchase = purcPricePerUnit * salesDetailQty;

          final profitCalculated = salesDetailPrice - totalPurchase;
          currentDayProfit += profitCalculated;
        }
      }
      todayTotalProfit.value = currentDayProfit;
    } catch (e, st) {
      log('[TodayProfitController] ❌ Error loading today\'s profit: $e');
      log('$st');
      todayTotalProfit.value = 0.0;
    } finally {
      isLoadingTodayProfit.value = false;
    }
  }

  String _normalizePacking(String packing) {
    if (packing == null || packing.isEmpty) return '';
    return packing.replaceAllMapped(RegExp(r'(\d+)\.0(\D*)$'), (match) {
      return '${match.group(1)}${match.group(2)}';
    }).toUpperCase().trim();
  }
}