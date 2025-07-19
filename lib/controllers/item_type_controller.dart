import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import 'base_remote_controller.dart';
 // Import GetStorage
import 'dart:developer'; // For logging

class ItemTypeController extends GetxController with BaseRemoteController {
  final drive = Get.find<GoogleDriveService>();
  final GetStorage _box = GetStorage(); // Get an instance of GetStorage

  // Cache keys
  static const String _masterCacheKey = 'itemMasterCsvCache';
  static const String _detailCacheKey = 'itemDetailCsvCache';
  static const String _lastSyncTimestampKey = 'lastItemTypeSync';
  static const Duration _cacheDuration = Duration(minutes: 10); // How long cache is valid

  // ───── Drive Path ─────
  List<String>? _softAgriPath;

  // ───── UI State ─────
  final allItemTypes = <String>[].obs;
  final filteredItemTypes = <String>[].obs;
  final typeCounts = <String, int>{}.obs;
  final allItems = <Map<String, dynamic>>[].obs;
  final allItemDetailRows = <Map<String, dynamic>>[].obs;

  // Key: ItemCode, Value: list of detail rows (all batches)
  final itemDetailsByCode = <String, List<Map<String, dynamic>>>{}.obs;

  // Key: ItemCode, Value: map of txt_pkg => list of rows
  final groupedByPkg = <String, Map<String, List<Map<String, dynamic>>>>{}.obs;

  // UI compatible: one row per ItemCode
  final latestDetailByCode = <String, Map<String, dynamic>>{}.obs;

  final uniqueItemDetails = <Map<String, dynamic>>[].obs; // Moved here for clarity

  final errorMessage = Rx<String?>(null);

  void _setError(String message) {
    errorMessage.value = message;
    log('[ItemTypeController] Error: $message');
  }

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializePaths(); // Ensure path initialization completes before proceeding
  }

  Future<void> _initializePaths() async {
    try {
      _softAgriPath = await SoftAgriPath.build(drive);
      log('[ItemTypeController] ✅ SoftAgriPath initialized.');
      // 💡 CHANGE: Removed the isLoading.value check here.
      // This ensures _load is always triggered once paths are ready
      // as the primary data fetch, preventing a race condition.
      await _load();
    } catch (e, st) {
      log('[ItemTypeController] ❌ Error initializing SoftAgriPath: $e');
      log('$st');
      _setError('Failed to load required application paths: $e');
    }
  }

  Future<void> fetchItemTypes({bool silent = false}) async =>
      guard(() => _load(silent: silent)); // This is for subsequent calls, which _load handles.

  void search(String q) {
    filteredItemTypes.value = allItemTypes
        .where((t) => t.toLowerCase().contains(q.toLowerCase()))
        .toList();
  }

  Future<void> _load({bool silent = false}) async {
    // This null check remains crucial to prevent operations if something calls _load
    // before _initializePaths has completed its task.
    if (_softAgriPath == null) {
      log('[ItemTypeController] ⚠️ _softAgriPath not initialized when _load was called. Returning.');
      if (!silent) {
        _setError('App paths not ready. Please try again.');
      }
      return;
    }

    if (!silent) isLoading(true);

    try {
      final parentId = await drive.folderId(_softAgriPath!);

      String? masterCsv;
      String? detailCsv;

      final lastSync = _box.read<int?>(_lastSyncTimestampKey);
      final isCacheValid = lastSync != null &&
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastSync)) < _cacheDuration;

      // --- Caching Logic ---
      if (isCacheValid) {
        log('💡 Using cached ItemType CSVs (valid for ${_cacheDuration.inMinutes} mins)');
        masterCsv = _box.read(_masterCacheKey);
        detailCsv = _box.read(_detailCacheKey);
      }

      // Download if cache is invalid or missing
      if (masterCsv == null || detailCsv == null) {
        log('🌐 Cache invalid or missing for ItemType, downloading CSVs from Drive...');
        masterCsv = await drive.downloadCsv(await drive.fileId('ItemMaster.csv', parentId));
        detailCsv = await drive.downloadCsv(await drive.fileId('ItemDetail.csv', parentId));

        // Save to cache
        await _box.write(_masterCacheKey, masterCsv);
        await _box.write(_detailCacheKey, detailCsv);
        await _box.write(_lastSyncTimestampKey, DateTime.now().millisecondsSinceEpoch);
        log('💾 ItemType CSVs downloaded and cached.');
      } else {
        log('⚡ Using cached ItemType CSVs to process.');
      }

      // --- Continue with processing using the (potentially cached) CSV data ---

      // ───── ItemMaster.csv ─────
      final masterRows = CsvUtils.toMaps(masterCsv!);
      final counts = <String, int>{};
      for (final r in masterRows) {
        final type = r['ItemType']?.toString() ?? '';
        counts[type] = (counts[type] ?? 0) + 1;
      }
      allItemTypes.value = counts.keys.toList()..sort();
      filteredItemTypes.value = allItemTypes;
      typeCounts.value = counts;
      allItems.value = masterRows;

      // ───── ItemDetail.csv ─────
      final detailRows = CsvUtils.toMaps(detailCsv!);
      allItemDetailRows.value = detailRows;

      final seenComposite = <String>{};
      final perCode = <String, List<Map<String, dynamic>>>{};
      final pkgMap = <String, Map<String, List<Map<String, dynamic>>>>{};
      final latestPerCode = <String, Map<String, dynamic>>{};

      for (final row in detailRows) {
        final itemCode = row['ItemCode']?.toString() ?? '';
        final batchNo = row['BatchNo']?.toString() ?? '';
        final pkg = row['txt_pkg']?.toString() ?? '';

        if (itemCode.isEmpty || batchNo.isEmpty || pkg.isEmpty) continue;

        final compositeKey = '$itemCode|$batchNo|$pkg';
        if (seenComposite.contains(compositeKey)) continue;

        seenComposite.add(compositeKey);

        // ✅ All batches by code
        perCode.putIfAbsent(itemCode, () => []).add(row);

        // ✅ Group by txt_pkg
        pkgMap.putIfAbsent(itemCode, () => {});
        pkgMap[itemCode]![pkg] = (pkgMap[itemCode]![pkg] ?? [])..add(row);

        // ✅ First seen as latest
        latestPerCode.putIfAbsent(itemCode, () => row);
      }

      // Populate unique items AFTER all details are processed
      populateUniqueItems();

      itemDetailsByCode.value = perCode;
      groupedByPkg.value = pkgMap;
      latestDetailByCode.value = latestPerCode;

    } catch (e, st) {
      log('[ItemTypeController] ❌ Error loading ItemType data: $e');
      log('$st');
      // Clear data on error
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
      final itemCode = row['ItemCode']?.toString() ?? '';
      final batchNo = row['BatchNo']?.toString() ?? '';
      final pkg = row['txt_pkg']?.toString() ?? '';

      final key = '$itemCode|$batchNo|$pkg';

      if (itemCode.isEmpty || batchNo.isEmpty || pkg.isEmpty) continue;
      if (seen.contains(key)) continue;

      seen.add(key);
      result.add(row);
    }

    uniqueItemDetails.value = result;
  }

  /// Filter batches for given itemCode and package
  List<Map<String, dynamic>> getBatches(String code, {String? pkg}) {
    final all = itemDetailsByCode[code] ?? [];
    if (pkg == null) return all;
    return all.where((row) => row['txt_pkg']?.toString() == pkg).toList();
  }

  /// Sort detail rows by field (asc or desc)
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