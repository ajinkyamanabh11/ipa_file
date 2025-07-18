import 'package:get/get.dart';
import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import 'base_remote_controller.dart';

class ItemTypeController extends GetxController with BaseRemoteController {
  final drive = Get.find<GoogleDriveService>();

  // ───── Drive Path ─────
  late final List<String> _softAgriPath;

  // ───── UI State ─────
  final allItemTypes      = <String>[].obs;
  final filteredItemTypes = <String>[].obs;
  final typeCounts        = <String,int>{}.obs;
  final allItems          = <Map<String,dynamic>>[].obs;
  final allItemDetailRows = <Map<String, dynamic>>[].obs;

  // Key: ItemCode, Value: list of detail rows (all batches)
  final itemDetailsByCode = <String, List<Map<String, dynamic>>>{}.obs;

  // Key: ItemCode, Value: map of txt_pkg => list of rows
  final groupedByPkg = <String, Map<String, List<Map<String, dynamic>>>>{}.obs;

  // UI compatible: one row per ItemCode
  final latestDetailByCode = <String, Map<String, dynamic>>{}.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    _softAgriPath = await SoftAgriPath.build(drive);
    guard(_load);
  }

  Future<void> fetchItemTypes({bool silent = false}) async =>
      guard(() => _load(silent: silent));

  void search(String q) {
    filteredItemTypes.value = allItemTypes
        .where((t) => t.toLowerCase().contains(q.toLowerCase()))
        .toList();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) isLoading(true);

    final parentId = await drive.folderId(_softAgriPath);

    // ───── ItemMaster.csv ─────
    final masterId   = await drive.fileId('ItemMaster.csv', parentId);
    final masterRows = CsvUtils.toMaps(await drive.downloadCsv(masterId));

    final counts = <String,int>{};
    for (final r in masterRows) {
      final type = r['ItemType']?.toString() ?? '';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    allItemTypes.value      = counts.keys.toList()..sort();
    filteredItemTypes.value = allItemTypes;
    typeCounts.value        = counts;
    allItems.value          = masterRows;

    // ───── ItemDetail.csv ─────
    final detailId   = await drive.fileId('ItemDetail.csv', parentId);
    final detailRows = CsvUtils.toMaps(await drive.downloadCsv(detailId));
    allItemDetailRows.value = detailRows;

    final seenComposite = <String>{};
    final perCode = <String, List<Map<String, dynamic>>>{};
    final pkgMap = <String, Map<String, List<Map<String, dynamic>>>>{};
    final latestPerCode = <String, Map<String, dynamic>>{};

    for (final row in detailRows) {
      final itemCode = row['ItemCode']?.toString() ?? '';
      final batchNo  = row['BatchNo']?.toString() ?? '';
      final pkg      = row['txt_pkg']?.toString() ?? '';

      if (itemCode.isEmpty || batchNo.isEmpty || pkg.isEmpty) continue;

      final compositeKey = '$itemCode|$batchNo|$pkg';
      if (seenComposite.contains(compositeKey)) continue;

      seenComposite.add(compositeKey);

      // ✅ All batches by code
      perCode.putIfAbsent(itemCode, () => []).add(row);

      // ✅ Group by txt_pkg
      pkgMap.putIfAbsent(itemCode, () => {});
      pkgMap[itemCode]!.putIfAbsent(pkg, () => []).add(row);

      // ✅ First seen as latest
      latestPerCode.putIfAbsent(itemCode, () => row);
      populateUniqueItems();
    }

    itemDetailsByCode.value = perCode;
    groupedByPkg.value = pkgMap;
    latestDetailByCode.value = latestPerCode;

    if (!silent) isLoading(false);
  }
  final uniqueItemDetails = <Map<String, dynamic>>[].obs;

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
