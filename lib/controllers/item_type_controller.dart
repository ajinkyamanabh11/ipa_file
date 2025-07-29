// lib/controllers/item_type_controller.dart

import 'package:get/get.dart';
import '../constants/paths.dart';
import '../services/CsvDataServices.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import 'base_remote_controller.dart';
import 'dart:developer';

class ItemTypeController extends GetxController with BaseRemoteController {
  final drive = Get.find<GoogleDriveService>();
  final CsvDataService _csvDataService = Get.find<CsvDataService>();

  final allItemTypes = <String>[].obs;
  final filteredItemTypes = <String>[].obs;
  final typeCounts = <String, int>{}.obs;
  final allItems = <Map<String, dynamic>>[].obs;
  final allItemDetailRows = <Map<String, dynamic>>[].obs;

  final itemDetailsByCode = <String, List<Map<String, dynamic>>>{}.obs;
  final groupedByPkg = <String, Map<String, List<Map<String, dynamic>>>>{}.obs;

  final RxMap<String, Map<String, dynamic>> latestDetailByCode = <String, Map<String, dynamic>>{}.obs;
  final uniqueItemDetails = <Map<String, dynamic>>[].obs;

  final errorMessage = Rx<String?>(null);

  void _setError(String message) {
    errorMessage.value = message;
    log('[ItemTypeController] Error: $message');
  }

  @override
  Future<void> onInit() async {
    super.onInit();
    log('[ItemTypeController] Initializing and loading data...');
    await _load();
  }

  Future<void> fetchItemTypes({bool silent = false, bool forceRefresh = false}) async =>
      guard(() => _load(silent: silent, forceRefresh: forceRefresh));

  void search(String q) {
    filteredItemTypes.value = allItemTypes
        .where((t) => t.toLowerCase().contains(q.toLowerCase()))
        .toList();
  }

  Future<void> _load({bool silent = false, forceRefresh = false}) async {
    if (!silent) isLoading(true);
    errorMessage.value = null;

    try {
      // Load only the CSVs needed for item types (lazy loading)
      await _csvDataService.loadCsvs([
        CsvDataService.itemMasterCacheKey,
        CsvDataService.itemDetailCacheKey,
      ], forceDownload: forceRefresh);

      final String masterCsv = _csvDataService.itemMasterCsv.value;
      final String detailCsv = _csvDataService.itemDetailCsv.value;

      if (masterCsv.isEmpty || detailCsv.isEmpty) {
        _setError('Item Master or Item Detail CSV data is empty. Cannot process item types.');
        allItemTypes.clear();
        filteredItemTypes.clear();
        typeCounts.clear();
        allItems.clear();
        allItemDetailRows.clear();
        itemDetailsByCode.clear();
        groupedByPkg.clear();
        latestDetailByCode.clear();
        uniqueItemDetails.clear();
        return;
      }

      log('⚡ ItemTypeController: Processing CSVs (from cache or new download)');

      // Process ItemMaster.csv - Keep ItemCode as string (common for IDs)
      final masterRows = CsvUtils.toMaps(
        masterCsv,
        stringColumns: ['ItemCode'],
      );
      final counts = <String, int>{};
      for (final r in masterRows) {
        final type = r['ItemType']?.toString() ?? '';
        counts[type] = (counts[type] ?? 0) + 1;
      }
      allItemTypes.value = counts.keys.toList()..sort();
      filteredItemTypes.value = allItemTypes;
      typeCounts.value = counts;
      allItems.value = masterRows;

      // Process ItemDetail.csv - ONLY 'BatchNo' is specified as stringColumn
      final detailRows = CsvUtils.toMaps(
        detailCsv,
        stringColumns: ['BatchNo'], // <--- ONLY BatchNo here
      );
      allItemDetailRows.value = detailRows;

      final seenComposite = <String>{};
      final perCode = <String, List<Map<String, dynamic>>>{};
      final pkgMap = <String, Map<String, List<Map<String, dynamic>>>>{};
      final Map<String, Map<String, dynamic>> tempLatestPerCode = {};

      for (final row in detailRows) {
        // These will now follow the CsvUtils parsing: ItemCode, txt_pkg, cmb_unit might be numbers if they look like it
        // BatchNo will be explicitly string.
        final itemCode = row['ItemCode']?.toString().trim() ?? '';
        final batchNo = row['BatchNo']?.toString().trim() ?? '';
        final pkg = row['txt_pkg']?.toString().trim() ?? '';
        final cmbUnit = row['cmb_unit']?.toString().trim() ?? '';

        if (itemCode.isEmpty || batchNo.isEmpty || pkg.isEmpty || cmbUnit.isEmpty) continue;

        final compositeKey = '$itemCode|$batchNo|$pkg|$cmbUnit';
        if (seenComposite.contains(compositeKey)) {
          continue;
        }
        seenComposite.add(compositeKey);

        perCode.putIfAbsent(itemCode, () => []).add(row);
        pkgMap.putIfAbsent(itemCode, () => {});
        pkgMap[itemCode]!.putIfAbsent(pkg, () => []).add(row);
        tempLatestPerCode.putIfAbsent(itemCode, () => row);
      }

      populateUniqueItems();

      itemDetailsByCode.value = perCode;
      groupedByPkg.value = pkgMap;
      latestDetailByCode.value = tempLatestPerCode;

      log('[ItemTypeController] ✅ ItemType data processed successfully.');

    } catch (e, st) {
      log('[ItemTypeController] ❌ Error loading ItemType data: $e');
      log('$st');
      allItemTypes.clear();
      filteredItemTypes.clear();
      typeCounts.clear();
      allItems.clear();
      allItemDetailRows.clear();
      itemDetailsByCode.clear();
      groupedByPkg.clear();
      latestDetailByCode.clear();
      uniqueItemDetails.clear();
      _setError('Failed to load item types: $e');
    } finally {
      if (!silent) isLoading(false);
    }
  }

  void populateUniqueItems() {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final row in allItemDetailRows) {
      final itemCode = row['ItemCode']?.toString().trim() ?? '';
      final batchNo = row['BatchNo']?.toString().trim() ?? '';
      final pkg = row['txt_pkg']?.toString().trim() ?? '';
      final cmbUnit = row['cmb_unit']?.toString().trim() ?? '';

      final key = '$itemCode|$batchNo|$pkg|$cmbUnit';

      if (itemCode.isEmpty || batchNo.isEmpty || pkg.isEmpty || cmbUnit.isEmpty) continue;
      if (seen.contains(key)) continue;

      seen.add(key);
      result.add(row);
    }

    uniqueItemDetails.value = result;
  }

  List<Map<String, dynamic>> getBatches(String code, {String? pkg}) {
    final all = itemDetailsByCode[code] ?? [];
    if (pkg == null) return all;
    return all.where((row) => row['txt_pkg']?.toString().trim() == pkg.trim()).toList();
  }

  List<Map<String, dynamic>> sortDetails(
      List<Map<String, dynamic>> rows,
      String field, {
        bool ascending = true,
      }) {
    rows.sort((a, b) {
      final av = a[field]?.toString() ?? '';
      final bv = b[field]?.toString() ?? '';
      return ascending ? av.compareTo(bv) : bv.compareTo(av);
    });
    return rows;
  }
}