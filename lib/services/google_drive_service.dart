import 'dart:convert';
import 'package:get/get.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../controllers/google_signin_controller.dart';

class GoogleDriveService extends GetxService {
  GoogleDriveService();                      // default ctor

  // Google‑sign‑in controller (already put before this service)
  final _google = Get.find<GoogleSignInController>();

  /// Factory used by `InitialBindings.ensure()`
  /// Place any async warm‑up you need here.
  static Future<GoogleDriveService> init() async {
    // ‑‑ e.g. refresh tokens, preload cache, etc.
    return GoogleDriveService();
  }

  // ───────────────────────────────── Google Drive helpers ──────────────────
  Future<drive.DriveApi> _api() async {
    final headers = await _google.getAuthHeaders();
    if (headers == null) throw Exception('Google Sign‑In required');
    return drive.DriveApi(_GoogleAuthClient(headers));
  }

  Future<String> folderId(List<String> path) async {
    final api = await _api();
    var parent = 'root';
    for (final segment in path) {
      final q =
          "'$parent' in parents and name = '$segment' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      final res = await api.files.list(q: q, spaces: 'drive');
      if (res.files == null || res.files!.isEmpty) {
        throw Exception('Folder not found: $segment');
      }
      parent = res.files!.first.id!;
    }
    return parent;
  }

  Future<String> fileId(String name, String parentId) async {
    final api = await _api();
    final res = await api.files.list(
      q: "'$parentId' in parents and name = '$name' and trashed = false",
    );
    if (res.files == null || res.files!.isEmpty) {
      throw Exception('File not found: $name');
    }
    return res.files!.first.id!;
  }

  Future<String> downloadCsv(String id) async {
    final api = await _api();
    final media =
    await api.files.get(id, downloadOptions: drive.DownloadOptions.fullMedia)
    as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }
}

// private auth client
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  _GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) =>
      _inner.send(r..headers.addAll(_headers));
}
