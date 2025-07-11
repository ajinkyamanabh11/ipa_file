import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'google_signin_controller.dart';

class ItemDetailController extends GetxController {
  late final GoogleSignInController _google;
  final isLoading = false.obs;
  final error = RxnString();
  final details = <Map<String, dynamic>>[].obs;   // rows for one ItemCode

  @override
  void onInit() {
    super.onInit();
    _google = Get.find<GoogleSignInController>();
  }

  Future<void> fetchDetails(String itemCode) async {
    isLoading.value = true;
    error.value = null;

    try {
      final auth = await _google.getAuthHeaders();
      if (auth == null) throw Exception('Missing auth headers');

      final headers = {'Authorization': auth['Authorization']!};

      // Navigate to the same folder: SoftAgri_Backups / 20252026 / softagri_csv
      final folderNames = ['SoftAgri_Backups', '20252026', 'softagri_csv'];
      String? parentId;
      for (final folder in folderNames) {
        final query = [
          "name='$folder'",
          "mimeType='application/vnd.google-apps.folder'",
          "'${parentId ?? 'root'}' in parents",
          "trashed=false"
        ].join(' and ');
        final res = await http.get(
          Uri.parse(
              'https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent(query)}&fields=files(id,name)&spaces=drive'),
          headers: headers,
        );
        final data = json.decode(res.body);
        if (data['files'] == null || data['files'].isEmpty) {
          throw Exception("Folder '$folder' not found");
        }
        parentId = data['files'][0]['id'];
      }

      // Find ItemDetail.csv
      final fileRes = await http.get(
        Uri.parse(
            "https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent("name='ItemDetail.csv' and '$parentId' in parents")}&fields=files(id)"),
        headers: headers,
      );
      final fileData = json.decode(fileRes.body);
      if (fileData['files'] == null || fileData['files'].isEmpty) {
        throw Exception("File 'ItemDetail.csv' not found");
      }

      final fileId = fileData['files'][0]['id'];
      final csvRes = await http.get(
        Uri.parse(
            "https://www.googleapis.com/drive/v3/files/$fileId?alt=media"),
        headers: headers,
      );
      if (csvRes.statusCode != 200) {
        throw Exception('Download failed (${csvRes.statusCode})');
      }

      // Parse CSV
      final table = const CsvToListConverter(eol: '\n').convert(csvRes.body);
      final header = table.first.cast<String>();

      final idxItemCode = header.indexOf('ItemCode');
      if (idxItemCode == -1) throw Exception('ItemCode column missing');

      final List<Map<String, dynamic>> rows = [];
      for (int r = 1; r < table.length; r++) {
        final row = table[r];
        if (row[idxItemCode].toString() == itemCode) {
          final map = <String, dynamic>{};
          for (int c = 0; c < header.length; c++) {
            map[header[c]] = row[c];
          }
          rows.add(map);
        }
      }

      if (rows.isEmpty) {
        throw Exception('No details found for $itemCode');
      }

      // Sort newest batch first (by MFGDate if present)
      rows.sort((a, b) =>
      DateTime.tryParse(b['MFGDate']?.toString() ?? '')?.compareTo(
          DateTime.tryParse(a['MFGDate']?.toString() ?? '') ?? DateTime(0)) ??
          0);

      details.value = rows;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
