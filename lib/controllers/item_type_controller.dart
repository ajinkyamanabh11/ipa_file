// lib/controllers/item_type_controller.dart
import 'package:get/get.dart';

import '../constants/paths.dart';                 // ⬅️ contains SoftAgriPath.build()
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import 'base_remote_controller.dart';

class ItemTypeController extends GetxController with BaseRemoteController {
  final drive = Get.find<GoogleDriveService>();

  // ───────────── dynamic three‑segment Drive path ──────────────
  late final List<String> _softAgriPath;          // ['SoftAgri_Backups', <FY>, 'softagri_csv']

  // ───────────── public reactive state ─────────────────────────
  final allItemTypes      = <String>[].obs;                       // full ItemType list
  final filteredItemTypes = <String>[].obs;                       // search‑filtered
  final typeCounts        = <String,int>{}.obs;                   // ItemType → count
  final allItems          = <Map<String,dynamic>>[].obs;          // rows of ItemMaster
  final itemDetails       = <String, Map<String,dynamic>>{}.obs;  // latest batch per code

  // ───────────────────────── life‑cycle ────────────────────────
  @override
  Future<void> onInit() async {
    super.onInit();

    // build dynamic FY path once per app run
    _softAgriPath = await SoftAgriPath.build(drive);

    // initial fetch
    guard(_load);
  }

  /// Pull‑to‑refresh entrypoint in both stock screens
  Future<void> fetchItemTypes({bool silent = false}) async =>
      guard(() => _load(silent: silent));

  /// Local search (no Drive call)
  void search(String q) {
    filteredItemTypes.value = allItemTypes
        .where((t) => t.toLowerCase().contains(q.toLowerCase()))
        .toList();
  }

  // ───────────────────────── data fetch ────────────────────────
  Future<void> _load({bool silent = false}) async {
    if (!silent) isLoading(true);

    // 1️⃣  locate Drive folder for current FY
    final parentId = await drive.folderId(_softAgriPath);

    // 2️⃣  ItemMaster.csv  →  allItems  +  typeCounts
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

    // 3️⃣  ItemDetail.csv  →  itemDetails (newest batch per ItemCode)
    final detailId   = await drive.fileId('ItemDetail.csv', parentId);
    final detailRows = CsvUtils.toMaps(await drive.downloadCsv(detailId));

    final latest = <String, Map<String,dynamic>>{};
    for (final row in detailRows) {
      final code = row['ItemCode']?.toString();
      if (code == null || code.isEmpty) continue;

      // Drive export is usually newest‑first, so keep first seen
      latest.putIfAbsent(code, () => row);
    }
    itemDetails.value = latest;

    if (!silent) isLoading(false);
  }
}
