import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import 'package:get_storage/get_storage.dart'; // Import GetStorage
import 'dart:developer';

class ProfitReportController extends GetxController {
  final drive = Get.find<GoogleDriveService>();
  final GetStorage _box = GetStorage(); // Get an instance of GetStorage

  static const String _masterCacheKey = 'salesMasterCsv';
  static const String _detailsCacheKey = 'salesDetailsCsv';
  static const String _itemMasterCacheKey = 'itemMasterCsv';
  static const String _itemDetailCacheKey = 'itemDetailCsv';
  static const String _lastSyncTimestampKey = 'lastProfitSync';
  static const Duration _cacheDuration = Duration(minutes: 10); // How long cache is valid

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

  String _normalizePacking(String packing) {
    if (packing == null || packing.isEmpty) return '';
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

    // --- Caching Logic ---
    String? masterCsv;
    String? detailsCsv;
    String? itemMasterCsv;
    String? itemDetailCsv;

    final lastSync = _box.read<int?>(_lastSyncTimestampKey);
    final isCacheValid = lastSync != null &&
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastSync)) < _cacheDuration;

    if (isCacheValid) {
      print('💡 Using cached CSVs (valid for ${_cacheDuration.inMinutes} mins)');
      masterCsv = _box.read(_masterCacheKey);
      detailsCsv = _box.read(_detailsCacheKey);
      itemMasterCsv = _box.read(_itemMasterCacheKey);
      itemDetailCsv = _box.read(_itemDetailCacheKey);
    }

    // Download if cache is invalid or missing
    if (masterCsv == null || detailsCsv == null || itemMasterCsv == null || itemDetailCsv == null) {
      print('🌐 Cache invalid or missing, downloading CSVs from Drive...');
      masterCsv = await drive.downloadCsv(await drive.fileId('SalesInvoiceMaster.csv', folderId));
      detailsCsv = await drive.downloadCsv(await drive.fileId('SalesInvoiceDetails.csv', folderId));
      itemMasterCsv = await drive.downloadCsv(await drive.fileId('ItemMaster.csv', folderId));
      itemDetailCsv = await drive.downloadCsv(await drive.fileId('ItemDetail.csv', folderId));

      // Save to cache
      await _box.write(_masterCacheKey, masterCsv);
      await _box.write(_detailsCacheKey, detailsCsv);
      await _box.write(_itemMasterCacheKey, itemMasterCsv);
      await _box.write(_itemDetailCacheKey, itemDetailCsv);
      await _box.write(_lastSyncTimestampKey, DateTime.now().millisecondsSinceEpoch);
      print('💾 CSVs downloaded and cached.');
    } else {
      print('⚡ Using cached CSVs to process report.');
    }

    // --- Continue with processing using the (potentially cached) CSV data ---
    final masterRows = CsvUtils.toMaps(masterCsv!);
    final detailRows = CsvUtils.toMaps(detailsCsv!);
    final itemRows = CsvUtils.toMaps(itemMasterCsv!);
    final itemDetailRows = CsvUtils.toMaps(itemDetailCsv!);

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
        final salesPacking = _normalizePacking(d['packing']!.toString());

        final salesDetailQty = num.tryParse('${d['qty']}') ?? 0;
        final salesDetailPrice = double.tryParse('${d['CGSTTaxableAmt']}') ?? 0.0;

        // log("DEBUG: SalesInvoiceDetails item: $itemCode - Sales Packing (Normalized): $salesPacking");

        if (salesDetailQty <= 0 || itemCode == null || itemCode.isEmpty) continue;

        final item = itemMap[itemCode];
        final itemName = item?['itemname']?.toString().trim() ?? itemCode;

        final lookupKey = '${itemCode}_${batchNo}';
        // log("🔍 Trying lookupKey (ItemCode_BatchNo): $lookupKey with Sales Packing (Normalized): $salesPacking");

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
          // if (potentialMatches.isNotEmpty) {
          //   log("✅ Fallback matches by ItemCode with empty/placeholder BatchNo found for: $lookupKey (Count: ${potentialMatches.length})");
          // }
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

        // if (matchingDetail != null) {
        //   log("✅ Exact match found for: $lookupKey with Packing (Normalized): $salesPacking");
        // } else {
        //   log("❌ No match found for: $lookupKey with Packing (Normalized): $salesPacking");
        //   log("🔎 Did not find an exact ItemDetail for ItemCode: $itemCode, BatchNo: $batchNo, Sales Packing (Normalized): $salesPacking");
        //   if (potentialMatches.isNotEmpty) {
        //     log("   Available ItemDetail packings (Normalized) for $lookupKey:");
        //     for (var detail in potentialMatches) {
        //       final txtPkg = detail['txt_pkg']?.toString().trim() ?? '';
        //       final cmbUnit = detail['cmb_unit']?.toString().trim() ?? '';
        //       log("     - ${_normalizePacking('$txtPkg$cmbUnit')}");
        //     }
        //   }
        // }

        final itemDetailTxtPkg = matchingDetail?['txt_pkg']?.toString().trim().toUpperCase() ?? '';
        final itemDetailCmbUnit = matchingDetail?['cmb_unit']?.toString().trim().toUpperCase() ?? '';
        final calculatedPacking = '$itemDetailTxtPkg$itemDetailCmbUnit';

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

        // log("🧾 Name: $itemName | Packing: $calculatedPacking | Qty: $salesDetailQty | Sale: $salesDetailPrice | Purchase: $totalPurchase | Profit: $profitCalculated");

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