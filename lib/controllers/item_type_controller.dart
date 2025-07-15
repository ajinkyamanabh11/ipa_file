import 'package:get/get.dart';

import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import 'base_remote_controller.dart';

class ItemTypeController extends GetxController with BaseRemoteController {
  final drive = Get.find<GoogleDriveService>();

  // ─┤ public, reactive state ├─────────────────────────────────
  final allItemTypes      = <String>[].obs;
  final filteredItemTypes = <String>[].obs;
  final typeCounts        = <String,int>{}.obs;
  final allItems          = <Map<String,dynamic>>[].obs;                // rows of ItemMaster
  final itemDetails       = <String, Map<String,dynamic>>{}.obs;        // newest batch per code

  @override
  void onInit() {
    super.onInit();
    guard(_load);                       // initial fetch
  }

  /// Used by pull‑to‑refresh in both screens
  Future<void> fetchItemTypes({bool silent = false}) async =>
      guard(() => _load(silent: silent));

  void search(String q) {
    filteredItemTypes.value = allItemTypes
        .where((t) => t.toLowerCase().contains(q.toLowerCase()))
        .toList();
  }

  // ───────────────────────────────────────────────────────────
  Future<void> _load({bool silent = false}) async {
    if (!silent) isLoading.value = true;

    final parent = await drive.folderId(kSoftAgriPath);

    // 1️⃣  ItemMaster.csv ➜ allItems  +  counts
    final masterId   = await drive.fileId('ItemMaster.csv', parent);
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

    // 2️⃣  ItemDetail.csv ➜ itemDetails  (newest batch per ItemCode)
    final detailId   = await drive.fileId('ItemDetail.csv', parent);
    final detailRows = CsvUtils.toMaps(await drive.downloadCsv(detailId));

    final map = <String, Map<String,dynamic>>{};
    for (final row in detailRows) {
      final code = row['ItemCode']?.toString();
      if (code == null || code.isEmpty) continue;
      // keep the *first* row we encounter (Drive export is usually newest‑first)
      map.putIfAbsent(code, () => row);
    }
    itemDetails.value = map;

    if (!silent) isLoading.value = false;
  }
}
