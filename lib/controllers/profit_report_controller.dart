import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import 'dart:developer';

class ProfitReportController extends GetxController {
  final drive = Get.find<GoogleDriveService>();

  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();

  final isLoading = false.obs;
  final batchProfits = <Map<String, dynamic>>[].obs;
  final filteredInvoices = <Map<String, dynamic>>[].obs;

  final totalSales = 0.0.obs;
  final totalPurchase = 0.0.obs;
  final totalProfit = 0.0.obs;

  final searchQuery = ''.obs;

  List<Map<String, dynamic>> get filteredRows {
    final search = searchQuery.value.toLowerCase();
    if (search.isEmpty) return batchProfits;
    return batchProfits.where((row) {
      final item = (row['itemName'] ?? '').toString().toLowerCase();
      final bill = (row['billno'] ?? '').toString().toLowerCase();
      return item.contains(search) || bill.contains(search);
    }).toList();
  }
  void resetProfits() {
    batchProfits.clear();
    totalSales.value = 0.0;
    totalPurchase.value = 0.0;
    totalProfit.value = 0.0;
    // isLoading.value = false; // You might not need to reset this here
  }
  Future<void> loadProfitReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    isLoading.value = true;
    totalSales.value = 0.0;
    totalPurchase.value = 0.0;
    totalProfit.value = 0.0;

    try {
      final data = await _loadBatchData(startDate, endDate);
      batchProfits.assignAll(data);
      _updateTotals(data);
    } catch (e, st) {
      print('[ProfitReport] ❌ Error: $e');
      print(st);
      batchProfits.clear();
      filteredInvoices.clear();
      _updateTotals([]);
    } finally {
      isLoading.value = false;
    }
  }

  void _updateTotals(List<Map<String, dynamic>> rows) {
    double sale = 0;
    double purchase = 0;
    double profit = 0;

    for (final row in rows) {
      sale += row['sales'] ?? 0;
      purchase += row['purchase'] ?? 0;
      profit += row['profit'] ?? 0;
    }

    totalSales.value = sale;
    totalPurchase.value = purchase;
    totalProfit.value = profit;
  }

  // Helper function to normalize packing strings for comparison
  String _normalizePacking(String packing) {
    if (packing == null || packing.isEmpty) return '';
    // This regex replaces '.0' at the end of a number with an empty string,
    // effectively converting "10.0KG" to "10KG".
    // It also removes any trailing ".0" from a purely numeric part.
    return packing.replaceAllMapped(RegExp(r'(\d+)\.0(\D*)$'), (match) {
      return '${match.group(1)}${match.group(2)}';
    }).toUpperCase().trim();
  }

  Future<List<Map<String, dynamic>>> _loadBatchData(
      DateTime startDate, DateTime endDate) async {
    fromDate = startDate;
    toDate = endDate;
    print('📆 Loading profit report from $fromDate to $toDate');

    final path = await SoftAgriPath.build(drive);
    final folderId = await drive.folderId(path);

    final fileIdMaster = await drive.fileId('SalesInvoiceMaster.csv', folderId);
    final csvMaster = await drive.downloadCsv(fileIdMaster);
    final masterRows = CsvUtils.toMaps(csvMaster);

    final filtered = masterRows.where((r) {
      final rawDate = r['invoicedate'] ?? r['challandate'] ?? r['receiptdate'];
      if (rawDate == null) return false;

      try {
        final dateStr = rawDate.toString().split('T').first;
        final parsed = DateTime.tryParse(dateStr) ??
            DateFormat('dd/MM/yyyy').parseStrict(dateStr);
        return parsed.isAfter(startDate.subtract(Duration(days: 1))) &&
            parsed.isBefore(endDate.add(Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).toList();

    filteredInvoices.assignAll(filtered);
    print('📄 Filtered invoices: ${filtered.length}');

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


    final List<Map<String, dynamic>> results = [];

    for (final inv in filtered) {
      final invoiceNo = inv['Billno']?.toString().trim().toUpperCase() ?? '';
      final invoiceDateRaw = inv['invoicedate']?.toString() ?? '';
      final invoiceDate = invoiceDateRaw.split('T').first;

      if (invoiceNo.isEmpty) continue;

      final matchingLines = detailsByInvoice[invoiceNo] ?? [];

      for (final d in matchingLines) {
        final itemCode = d['itemcode']?.toString().trim().toUpperCase();
        final batchNo = d['batchno']?.toString().trim().toUpperCase() ?? '';
        // Normalize sales packing from SalesInvoiceDetails.csv
        final salesPacking = _normalizePacking(d['packing']!.toString());

        final salesDetailQty = num.tryParse('${d['qty']}') ?? 0;
        final salesDetailPrice = double.tryParse('${d['CGSTTaxableAmt']}') ?? 0.0;

        log("DEBUG: SalesInvoiceDetails item: $itemCode - Sales Packing (Normalized): $salesPacking");

        if (salesDetailQty <= 0 || itemCode == null || itemCode.isEmpty) continue;

        final item = itemMap[itemCode];
        final itemName = item?['itemname']?.toString().trim() ?? itemCode;

        final lookupKey = '${itemCode}_${batchNo}';
        log("🔍 Trying lookupKey (ItemCode_BatchNo): $lookupKey with Sales Packing (Normalized): $salesPacking");

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
          if (potentialMatches.isNotEmpty) {
            log("✅ Fallback matches by ItemCode with empty/placeholder BatchNo found for: $lookupKey (Count: ${potentialMatches.length})");
          }
        }

        if (potentialMatches.isNotEmpty) {
          matchingDetail = potentialMatches.firstWhereOrNull(
                  (detail) {
                final itemDetailTxtPkg = detail['txt_pkg']?.toString().trim() ?? '';
                final itemDetailCmbUnit = detail['cmb_unit']?.toString().trim() ?? '';
                // Normalize ItemDetail packing for comparison
                final itemDetailPacking = _normalizePacking('$itemDetailTxtPkg$itemDetailCmbUnit');
                return itemDetailPacking == salesPacking;
              }
          );
        }

        if (matchingDetail != null) {
          log("✅ Exact match found for: $lookupKey with Packing (Normalized): $salesPacking");
        } else {
          log("❌ No match found for: $lookupKey with Packing (Normalized): $salesPacking");
          log("🔎 Did not find an exact ItemDetail for ItemCode: $itemCode, BatchNo: $batchNo, Sales Packing (Normalized): $salesPacking");
          if (potentialMatches.isNotEmpty) {
            log("   Available ItemDetail packings (Normalized) for $lookupKey:");
            for (var detail in potentialMatches) {
              final txtPkg = detail['txt_pkg']?.toString().trim() ?? '';
              final cmbUnit = detail['cmb_unit']?.toString().trim() ?? '';
              log("     - ${_normalizePacking('$txtPkg$cmbUnit')}");
            }
          }
        }

        // Get packing from the *found* matchingDetail from ItemDetail.csv
        // (Use the original values from matchingDetail for storage, not normalized ones)
        final itemDetailTxtPkg = matchingDetail?['txt_pkg']?.toString().trim().toUpperCase() ?? '';
        final itemDetailCmbUnit = matchingDetail?['cmb_unit']?.toString().trim().toUpperCase() ?? '';
        final calculatedPacking = '$itemDetailTxtPkg$itemDetailCmbUnit'; // This is the correct packing to use in the entry

        final purcPricePerUnit = double.tryParse('${matchingDetail?['PurchasePrice']}') ?? 0.0;
        final totalPurchase = purcPricePerUnit * salesDetailQty;

        final profitCalculated = salesDetailPrice - totalPurchase;

        final entry = {
          'billno': invoiceNo,
          'batchno': batchNo,
          'qty': salesDetailQty,
          'sales': salesDetailPrice,
          'purchase': totalPurchase,
          'profit': profitCalculated,
          'packing': calculatedPacking,
          'itemName': itemName,
          'itemCode': itemCode,
          'date': invoiceDate,
        };

        log("🧾 Name: $itemName | Packing: $calculatedPacking | Qty: $salesDetailQty | Sale: $salesDetailPrice | Purchase: $totalPurchase | Profit: $profitCalculated");

        results.add(entry);
      }
    }

    results.sort((a, b) => a['billno'].toString().compareTo(b['billno'].toString()));
    print('[ProfitReport] ✅ Loaded ${results.length} batch entries');
    return results;
  }

  void clear() {
    batchProfits.clear();
    filteredInvoices.clear();
    totalSales.value = 0;
    totalPurchase.value = 0;
    totalProfit.value = 0;
    searchQuery.value = '';
  }
}