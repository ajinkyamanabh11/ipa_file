import 'dart:convert';
import 'dart:developer';
import 'package:csv/csv.dart';
import 'package:get/get.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../model/account_master_model.dart';
import '../model/allaccounts_model.dart';
import 'google_signin_controller.dart';   // your class

/// ——————————————————— helpers ———————————————————
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);
  @override Future<http.StreamedResponse> send(http.BaseRequest r) => _client.send(r..headers.addAll(_headers));
}

class DriveCsv {
  static Future<String> fetch({
    required drive.DriveApi api,
    required List<String> path, // folder path segments
    required String fileName,
  }) async {
    // Walk the folder tree
    String parentId = 'root';
    for (final segment in path) {
      final res = await api.files.list(
        q: "'$parentId' in parents and name = '$segment' "
            "and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        spaces: 'drive',
      );
      if (res.files == null || res.files!.isEmpty) {
        throw Exception('Folder not found: $segment');
      }
      parentId = res.files!.first.id!;
    }
    // Find the CSV file in the final folder
    final list = await api.files.list(
      q: "'$parentId' in parents and name = '$fileName' and trashed = false",
    );
    if (list.files == null || list.files!.isEmpty) {
      throw Exception('$fileName not found');
    }
    final id = list.files!.first.id!;
    final media = await api.files.get(id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) bytes.addAll(chunk);
    return utf8.decode(bytes);
  }

  static List<Map<String, dynamic>> parse(String csv) {
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(csv);
    if (rows.isEmpty) return [];
    final headers = rows.first.map((e) => e.toString()).toList();
    return rows.skip(1).map((row) => Map.fromIterables(headers, row)).toList();
  }
}

/// ——————————————————— controller ———————————————————
class CustomerLedger_Controller extends GetxController {
  // Google‑sign‑in controller injected in main.dart   Get.put(GoogleSignInController());
  final gs = Get.find<GoogleSignInController>();

  final accounts      = <AccountModel>[].obs;
  final transactions  = <AllAccountsModel>[].obs;
  final filtered      = <AllAccountsModel>[].obs;

  final drTotal       = 0.0.obs;
  final crTotal       = 0.0.obs;
  final currentName   = ''.obs;
  final isLoading     = true.obs;

  final _drivePath = const ['SoftAgri_Backups', '20252026', 'softagri_csv'];

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    try {
      isLoading(true);
      final headers = await gs.getAuthHeaders();
      if (headers == null) throw 'Not signed in to Google';
      final api = drive.DriveApi(GoogleAuthClient(headers));

      final accCsv  = await DriveCsv.fetch(api: api, path: _drivePath, fileName: 'AccountMaster.csv');
      final allCsv  = await DriveCsv.fetch(api: api, path: _drivePath, fileName: 'AllAccounts.csv');

      accounts.assignAll( DriveCsv.parse(accCsv).map(AccountModel.fromMap) );
      transactions.assignAll( DriveCsv.parse(allCsv).map(AllAccountsModel.fromMap) );
    } catch (e) {
      log('❌ $e');
    } finally {
      isLoading(false);
    }
  }

  void filterByName(String name) {
    currentName(name);
    final acc = accounts.firstWhereOrNull(
          (a) => a.accountName.toLowerCase() == name.toLowerCase(),
    );
    if (acc == null) {
      filtered.clear();
      drTotal(0); crTotal(0);
      return;
    }
    filtered.assignAll(
      transactions.where((t) => t.accountCode == acc.accountNumber),
    );
    _totals();
  }

  void _totals() {
    double dr = 0, cr = 0;
    for (final t in filtered) {
      t.isDr ? dr += t.amount : cr += t.amount;
    }
    drTotal(dr); crTotal(cr);
  }

  void clearFilter() {
    filtered.clear();
    currentName('');
    drTotal(0); crTotal(0);
  }
}
