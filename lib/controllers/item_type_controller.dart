import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'google_signin_controller.dart';

class ItemTypeController extends GetxController {
  // ──────────────────────── PUBLIC STATE ────────────────────────
  var allItemTypes     = <String>[].obs;                   // All distinct types
  var filteredItemTypes = <String>[].obs;                  // Search results
  var typeCounts       = <String, int>{}.obs;              // #items per type
  var allItems         = <Map<String, dynamic>>[].obs;     // Every row of ItemMaster
  var itemDetails      = <String, Map<String, dynamic>>{}.obs; // newest detail per code

  var isLoading = false.obs;
  var error      = RxnString();

  // ──────────────────────── PRIVATE ────────────────────────
  late final GoogleSignInController _google;

  // ──────────────────────── LIFECYCLE ────────────────────────
  @override
  void onInit() {
    super.onInit();
    _google = Get.find<GoogleSignInController>();
    fetchItemTypes();                           // kick‑off immediately
  }

  // ──────────────────────── SEARCH HELPER ────────────────────────
  void search(String query) {
    filteredItemTypes.value = allItemTypes
        .where((t) => t.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // ──────────────────────── MAIN FETCH ────────────────────────
  Future<void> fetchItemTypes({bool silent = false}) async {
    if (!silent) isLoading.value = true;
    error.value = null;

    try {
      final auth = await _google.getAuthHeaders();
      if (auth == null) throw Exception('Missing auth headers');
      final headers = {'Authorization': auth['Authorization']!};

      // 1️⃣  Walk: SoftAgri_Backups / 20252026 / softagri_csv
      final folderNames = ['SoftAgri_Backups', '20252026', 'softagri_csv'];
      String? parentId;
      for (final folder in folderNames) {
        final q = [
          "name='$folder'",
          "mimeType='application/vnd.google-apps.folder'",
          "'${parentId ?? 'root'}' in parents",
          "trashed=false",
        ].join(' and ');
        final r = await http.get(
          Uri.parse(
              'https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent(q)}&fields=files(id)&spaces=drive'),
          headers: headers,
        );
        final list = (json.decode(r.body)['files'] as List);
        if (list.isEmpty) throw Exception("Folder '$folder' not found");
        parentId = list.first['id'];
      }

      // 2️⃣  Download ItemMaster.csv
      await _fetchItemMaster(parentId!, headers);

      // 3️⃣  Download ItemDetail.csv
      await _fetchItemDetails(parentId, headers);
    } catch (e) {
      error.value = e.toString();
    } finally {
      if (!silent) isLoading.value = false;
    }
  }

  // ──────────────────────── HELPERS ────────────────────────
  Future<void> _fetchItemMaster(String parentId, Map<String, String> headers) async {
    final fileId = await _findFileId('ItemMaster.csv', parentId, headers);

    final csv = await http.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
      headers: headers,
    );
    if (csv.statusCode != 200) throw Exception('Download ItemMaster.csv failed');

    final table = const CsvToListConverter(eol: '\n').convert(csv.body);
    final head  = table.first.cast<String>();

    final idxType = head.indexOf('ItemType');
    final idxName = head.indexOf('ItemName');
    if (idxType == -1 || idxName == -1) {
      throw Exception('ItemType or ItemName column missing in ItemMaster.csv');
    }

    final counts = <String, int>{};
    final items  = <Map<String, dynamic>>[];

    for (var i = 1; i < table.length; i++) {
      final row     = table[i];
      final type    = row[idxType].toString();
      counts[type]  = (counts[type] ?? 0) + 1;

      final map = <String, dynamic>{};
      for (var j = 0; j < head.length; j++) map[head[j]] = row[j];
      items.add(map);
    }

    allItems.value        = items;
    typeCounts.value      = counts;
    allItemTypes.value    = counts.keys.toList()..sort();
    filteredItemTypes.value = allItemTypes;
  }

  Future<void> _fetchItemDetails(String parentId, Map<String, String> headers) async {
    final fileId = await _findFileId('ItemDetail.csv', parentId, headers);

    final csv = await http.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
      headers: headers,
    );
    if (csv.statusCode != 200) throw Exception('Download ItemDetail.csv failed');

    final table = const CsvToListConverter(eol: '\n').convert(csv.body);
    final head = table.first.map((e) => e.toString().trim()).toList();

    final idxCode = head.indexOf('ItemCode');
    if (idxCode == -1) throw Exception('ItemCode missing in ItemDetail.csv');

    final map = <String, Map<String, dynamic>>{};
    for (var i = 1; i < table.length; i++) {
      final row = table[i];
      final code = row[idxCode]?.toString().trim();
      if (code == null || code.isEmpty) continue;

      map.putIfAbsent(code, () {
        final m = <String, dynamic>{};
        for (var j = 0; j < head.length && j < row.length; j++) {
          m[head[j]] = row[j];
        }
        return m;
      });
    }

    itemDetails.value = map;
  }


  Future<String> _findFileId(
      String fileName, String parentId, Map<String, String> headers) async {
    final q = Uri.encodeQueryComponent("name='$fileName' and '$parentId' in parents");
    final r = await http.get(
      Uri.parse(
          'https://www.googleapis.com/drive/v3/files?q=$q&fields=files(id)'),
      headers: headers,
    );
    final list = (json.decode(r.body)['files'] as List);
    if (list.isEmpty) throw Exception("File '$fileName' not found");
    return list.first['id'];
  }
}
