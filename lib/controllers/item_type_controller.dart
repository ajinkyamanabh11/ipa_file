import 'package:get/get.dart';
import '../constants/paths.dart';
import '../services/CsvDataServices.dart'; // Ensure correct import for CsvDataService
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import 'base_remote_controller.dart';
import 'dart:developer';

class ItemTypeController extends GetxController with BaseRemoteController {
  final drive = Get.find<GoogleDriveService>();
  final CsvDataService _csvDataService = Get.find<CsvDataService>();

  // ───── UI State ─────
  final allItemTypes = <String>[].obs;
  final filteredItemTypes = <String>[].obs;
  final typeCounts = <String, int>{}.obs;
  final allItems = <Map<String, dynamic>>[].obs;
  final allItemDetailRows = <Map<String, dynamic>>[].obs;

  final itemDetailsByCode = <String, List<Map<String, dynamic>>>{}.obs;
  final groupedByPkg = <String, Map<String, List<Map<String, dynamic>>>>{}.obs;

  final latestDetailByCode = <String, Map<String, dynamic>>{}.obs;

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
    // Initial load, typically not forced unless specified by app logic
    await _load();
  }

  // Exposed method to trigger data fetching with refresh option
  Future<void> fetchItemTypes({bool silent = false, bool forceRefresh = false}) async =>
      guard(() => _load(silent: silent, forceRefresh: forceRefresh));

  // Method for searching item types
  void search(String q) {
    filteredItemTypes.value = allItemTypes
        .where((t) => t.toLowerCase().contains(q.toLowerCase()))
        .toList();
  }

  // Core data loading and processing method
  Future<void> _load({bool silent = false, bool forceRefresh = false}) async {
    if (!silent) isLoading(true);
    errorMessage.value = null; // Clear previous errors

    try {
      // Load all CSVs from service, respecting the forceRefresh flag
      await _csvDataService.loadAllCsvs(forceDownload: forceRefresh);

      final String masterCsv = _csvDataService.itemMasterCsv.value;
      final String detailCsv = _csvDataService.itemDetailCsv.value;

      // Validate if essential CSV data is available
      if (masterCsv.isEmpty || detailCsv.isEmpty) {
        _setError('Item Master or Item Detail CSV data is empty. Cannot process item types.');
        // Clear all relevant Rx lists/maps if data is missing
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

      // ───── Process ItemMaster.csv ─────
      // Parse ItemMaster.csv (numbers can be parsed)
      final masterRows = CsvUtils.toMaps(masterCsv);
      final counts = <String, int>{};
      for (final r in masterRows) {
        final type = r['ItemType']?.toString() ?? '';
        counts[type] = (counts[type] ?? 0) + 1;
      }
      allItemTypes.value = counts.keys.toList()..sort(); // Populate item types and sort
      filteredItemTypes.value = allItemTypes; // Initially, filtered are all types
      typeCounts.value = counts; // Store counts per type
      allItems.value = masterRows; // Store all master item rows

      // ───── Process ItemDetail.csv ─────
      // CRITICAL FIX: Parse ItemDetail.csv with parseNumbers: false
      // This ensures batch numbers (like "002" vs "02") are treated as distinct strings.
      final detailRows = CsvUtils.toMaps(detailCsv, parseNumbers: false);
      allItemDetailRows.value = detailRows; // Store all detail rows

      final seenComposite = <String>{}; // Tracks unique item-batch-pkg combinations
      final perCode = <String, List<Map<String, dynamic>>>{}; // Details grouped by item code
      final pkgMap = <String, Map<String, List<Map<String, dynamic>>>>{}; // Details grouped by item code then package
      final Map<String, Map<String, dynamic>> tempLatestPerCode = {}; // Stores the "latest" detail row per item code

      // Iterate through detail rows to populate the maps
      for (final row in detailRows) {
        final itemCode = row['ItemCode']?.toString().trim() ?? '';
        // BatchNo is now guaranteed to be its raw string form (e.g., "002", "02")
        final batchNo = row['BatchNo']?.toString().trim() ?? '';
        final pkg = row['txt_pkg']?.toString().trim() ?? '';

        // Skip rows with essential missing data
        if (itemCode.isEmpty || batchNo.isEmpty || pkg.isEmpty) continue;

        // Create a composite key to identify unique item-batch-package combinations
        final compositeKey = '$itemCode|$batchNo|$pkg';
        if (seenComposite.contains(compositeKey)) {
          // If this combination has already been processed, skip to avoid duplicates
          continue;
        }
        seenComposite.add(compositeKey); // Mark this combination as seen

        // Add the row to the list for its itemCode
        perCode.putIfAbsent(itemCode, () => []).add(row);

        // Add the row to the package map (nested structure: ItemCode -> Pkg -> List of details)
        pkgMap.putIfAbsent(itemCode, () => {});
        pkgMap[itemCode]!.putIfAbsent(pkg, () => []).add(row);

        // Store this row as the "latest" for its itemCode (current logic: first one encountered)
        tempLatestPerCode.putIfAbsent(itemCode, () => row);
      }

      // After processing all details, populate the unique items list
      populateUniqueItems();

      // Update the reactive variables
      itemDetailsByCode.value = perCode;
      groupedByPkg.value = pkgMap;
      latestDetailByCode.value = tempLatestPerCode;

      log('[ItemTypeController] ✅ ItemType data processed successfully.');

    } catch (e, st) {
      log('[ItemTypeController] ❌ Error loading ItemType data: $e');
      log('$st'); // Log the stack trace for detailed debugging
      // Clear all data structures on error
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

  // Populates unique items based on item code, batch number, and package
  void populateUniqueItems() {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final row in allItemDetailRows) {
      final itemCode = row['ItemCode']?.toString().trim() ?? '';
      final batchNo = row['BatchNo']?.toString().trim() ?? '';
      final pkg = row['txt_pkg']?.toString().trim() ?? '';

      final key = '$itemCode|$batchNo|$pkg'; // Use the consistent key structure

      // Ensure essential fields are present and the combination is unique
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
    // Filter by package (normalized if needed, but here direct string comparison is fine after parseNumbers:false)
    return all.where((row) => row['txt_pkg']?.toString().trim() == pkg.trim()).toList();
  }

  /// Sort detail rows by field (ascending or descending)
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