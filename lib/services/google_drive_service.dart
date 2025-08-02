import 'dart:convert';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:fixnum/fixnum.dart' as fixnum; // Corrected import for Int64

import '../controllers/google_signin_controller.dart';

class GoogleDriveService extends GetxService {
  GoogleDriveService(); // default ctor

  // Google‑sign‑in controller (already put before this service)
  final _google = Get.find<GoogleSignInController>();

  // Memory management constants
  static const int _maxChunkSize = 1024 * 1024; // 1MB chunks (not directly used in streaming logic, but good to have)
  static const int _maxFileSize = 50 * 1024 * 1024; // 50MB max file size

  /// Factory used by `InitialBindings.ensure()`
  /// Place any async warm‑up you need here.
  static Future<GoogleDriveService> init() async {
    // ‑‑ e.g. refresh tokens, preload cache, etc.
    return GoogleDriveService();
  }

  // ───────────────────────────────── Google Drive helpers ──────────────────
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

  /// Download CSV with memory-efficient streaming and size limits
  Future<String> downloadCsv(String id) async {
    final api = await _api();

    try {
      // First, get file metadata to check size
      final fileMetadata = await api.files.get(id) as drive.File;
      // CORRECTED: Access size as fixnum.Int64 and convert to String for int.tryParse
      final fileSize = int.tryParse(fileMetadata.size?.toString() ?? '0') ?? 0;

      // Check if file is too large
      if (fileSize > _maxFileSize) {
        throw Exception('File too large: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB. Maximum allowed: ${(_maxFileSize / (1024 * 1024)).toStringAsFixed(0)}MB');
      }

      final media = await api.files.get(id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

      // Use streaming approach with memory management
      return await _streamToString(media.stream, fileSize);

    } catch (e) {
      if (e.toString().contains('File too large')) {
        rethrow;
      }
      throw Exception('Failed to download CSV file: $e');
    }
  }

  /// Convert stream to string with memory management
  Future<String> _streamToString(Stream<List<int>> stream, int expectedSize) async {
    final chunks = <Uint8List>[];
    int totalBytes = 0;

    await for (final chunk in stream) {
      // Check memory limits
      totalBytes += chunk.length;
      if (totalBytes > _maxFileSize) {
        throw Exception('File size exceeded during download: ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)}MB');
      }

      chunks.add(Uint8List.fromList(chunk));

      // Process in smaller chunks to prevent memory spikes
      if (chunks.length > 10) { // Process every 10 chunks
        await Future.delayed(const Duration(milliseconds: 1)); // Allow garbage collection
      }
    }

    // Efficiently combine all chunks
    final totalLength = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final combined = Uint8List(totalLength);

    int offset = 0;
    for (final chunk in chunks) {
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    try {
      return utf8.decode(combined);
    } catch (e) {
      throw Exception('Failed to decode CSV file as UTF-8: $e');
    }
  }

  /// Get file size without downloading
  Future<int> getFileSize(String id) async {
    final api = await _api();
    final fileMetadata = await api.files.get(id) as drive.File; // <-- Explicit cast
    return int.tryParse(fileMetadata.size?.toString() ?? '0') ?? 0;
  }


  /// Check if file exists and get basic info
  Future<Map<String, dynamic>?> getFileInfo(String name, String parentId) async {
    try {
      final api = await _api();
      final res = await api.files.list(
        q: "'$parentId' in parents and name = '$name' and trashed = false",
      );

      if (res.files == null || res.files!.isEmpty) {
        return null;
      }

      final file = res.files!.first;
      return {
        'id': file.id,
        'name': file.name,
        // CORRECTED: Access size as fixnum.Int64 and convert to int
        'size': int.tryParse(file.size?.toString() ?? '0') ?? 0,
        'modifiedTime': file.modifiedTime?.toIso8601String(),
      };
    } catch (e) {
      return null;
    }
  }

  /// Download with progress callback for large files
  Future<String> downloadCsvWithProgress(
      String id,
      {Function(double)? onProgress}
      ) async {
    final api = await _api();

    try {
      // Get file size first
      final fileInfo = await api.files.get(id) as drive.File;
      final fileSize = int.tryParse(fileInfo.size?.toString() ?? '0') ?? 0;

      if (fileSize > _maxFileSize) {
        throw Exception('File too large: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB');
      }

      final media = await api.files.get(id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

      return await _streamToStringWithProgress(media.stream, fileSize, onProgress);

    } catch (e) {
      throw Exception('Failed to download CSV with progress: $e');
    }
  }

  /// Stream to string with progress reporting
  Future<String> _streamToStringWithProgress(
      Stream<List<int>> stream,
      int expectedSize,
      Function(double)? onProgress
      ) async {
    final chunks = <Uint8List>[];
    int totalBytes = 0;

    await for (final chunk in stream) {
      totalBytes += chunk.length;
      chunks.add(Uint8List.fromList(chunk));

      // Report progress
      if (onProgress != null && expectedSize > 0) {
        final progress = (totalBytes / expectedSize).clamp(0.0, 1.0);
        onProgress(progress);
      }

      // Memory management
      if (totalBytes > _maxFileSize) {
        throw Exception('File size exceeded during download');
      }

      // Allow UI updates
      if (chunks.length % 5 == 0) {
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }

    // Combine chunks efficiently
    final totalLength = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final combined = Uint8List(totalLength);

    int offset = 0;
    for (final chunk in chunks) {
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return utf8.decode(combined);
  }

  /// Upload file to Google Drive with drive.file scope
  Future<String> uploadFile({
    required String fileName,
    required List<int> fileData,
    required String parentFolderId,
    String? mimeType,
    Function(double)? onProgress,
  }) async {
    final api = await _api();

    try {
      // Create file metadata
      final fileMetadata = drive.File()
        ..name = fileName
        ..parents = [parentFolderId];

      // Create media for upload
      final media = drive.Media(
        Stream.fromIterable([fileData]),
        fileData.length,
        contentType: mimeType ?? 'application/octet-stream',
      );

      // Upload the file
      final uploadedFile = await api.files.create(
        fileMetadata,
        uploadMedia: media,
      );

      if (uploadedFile.id == null) {
        throw Exception('Failed to upload file: No file ID returned');
      }

      return uploadedFile.id!;
    } catch (e) {
      throw Exception('Failed to upload file $fileName: $e');
    }
  }

  /// Create a new folder in Google Drive
  Future<String> createFolder({
    required String folderName,
    String? parentFolderId,
  }) async {
    final api = await _api();

    try {
      final folderMetadata = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      if (parentFolderId != null) {
        folderMetadata.parents = [parentFolderId];
      }

      final createdFolder = await api.files.create(folderMetadata);

      if (createdFolder.id == null) {
        throw Exception('Failed to create folder: No folder ID returned');
      }

      return createdFolder.id!;
    } catch (e) {
      throw Exception('Failed to create folder $folderName: $e');
    }
  }

  /// List files in a specific folder
  Future<List<drive.File>> listFiles({
    String? folderId,
    String? query,
    int pageSize = 20,
  }) async {
    final api = await _api();

    try {
      String searchQuery = "trashed = false";
      
      if (folderId != null) {
        searchQuery += " and '$folderId' in parents";
      }
      
      if (query != null && query.isNotEmpty) {
        searchQuery += " and name contains '$query'";
      }

      final fileList = await api.files.list(
        q: searchQuery,
        pageSize: pageSize,
        fields: 'files(id,name,mimeType,size,modifiedTime,parents)',
        orderBy: 'modifiedTime desc',
      );

      return fileList.files ?? [];
    } catch (e) {
      throw Exception('Failed to list files: $e');
    }
  }

  /// Delete a file from Google Drive
  Future<void> deleteFile(String fileId) async {
    final api = await _api();

    try {
      await api.files.delete(fileId);
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Update file content
  Future<String> updateFile({
    required String fileId,
    required List<int> fileData,
    String? mimeType,
  }) async {
    final api = await _api();

    try {
      final media = drive.Media(
        Stream.fromIterable([fileData]),
        fileData.length,
        contentType: mimeType ?? 'application/octet-stream',
      );

      final updatedFile = await api.files.update(
        drive.File(),
        fileId,
        uploadMedia: media,
      );

      return updatedFile.id!;
    } catch (e) {
      throw Exception('Failed to update file: $e');
    }
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