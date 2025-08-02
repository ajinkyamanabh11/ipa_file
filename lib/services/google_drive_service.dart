import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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

  // ───────────────────────────────── File Picker Methods ──────────────────

  /// List files from Google Drive with filtering options
  Future<List<DriveFile>> listFiles({
    List<String>? mimeTypes,
    String? folderId,
    String? nameContains,
    int pageSize = 100,
    String? pageToken,
  }) async {
    try {
      final api = await _api();

      // Build query string
      final queryParts = <String>[];

      // Filter by MIME types
      if (mimeTypes != null && mimeTypes.isNotEmpty) {
        final mimeQuery = mimeTypes.map((mime) => "mimeType='$mime'").join(' or ');
        queryParts.add('($mimeQuery)');
      }

      // Filter by parent folder
      if (folderId != null) {
        queryParts.add("'$folderId' in parents");
      }

      // Filter by name
      if (nameContains != null) {
        queryParts.add("name contains '$nameContains'");
      }

      // Exclude trashed files
      queryParts.add('trashed=false');

      final query = queryParts.join(' and ');

      log('Drive API query: $query');

      final fileList = await api.files.list(
        q: query,
        pageSize: pageSize,
        pageToken: pageToken,
        $fields: 'nextPageToken, files(id, name, mimeType, size, parents, createdTime, modifiedTime, webViewLink, webContentLink, thumbnailLink)',
      );

      return fileList.files?.map((file) => DriveFile.fromGoogleDriveFile(file)).toList() ?? [];

    } catch (e) {
      log('Error listing files: $e');
      throw Exception('Failed to list files: $e');
    }
  }

  /// Show a file picker dialog with the specified filters
  Future<List<DriveFile>?> pickFiles({
    bool multiSelect = false,
    List<String>? mimeTypes,
    String? folderId,
    String? title,
  }) async {
    try {
      final files = await listFiles(
        mimeTypes: mimeTypes,
        folderId: folderId,
      );

      if (files.isEmpty) {
        Get.snackbar(
          'No Files Found',
          'No files matching the criteria were found in your Google Drive.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return null;
      }

      // Show selection dialog
      return await _showFileSelectionDialog(
        files: files,
        multiSelect: multiSelect,
        title: title ?? 'Select Files',
      );

    } catch (e) {
      log('Error in pickFiles: $e');
      Get.snackbar(
        'Error',
        'Failed to load files: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }
  }

  /// Pick CSV files specifically
  Future<List<DriveFile>?> pickCsvFiles({bool multiSelect = false}) async {
    return pickFiles(
      multiSelect: multiSelect,
      mimeTypes: [
        'text/csv',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.google-apps.spreadsheet',
      ],
      title: 'Select CSV Files',
    );
  }

  /// Pick files from a specific folder
  Future<List<DriveFile>?> pickFilesFromFolder(
      String folderId, {
        bool multiSelect = false,
        List<String>? mimeTypes,
      }) async {
    return pickFiles(
      multiSelect: multiSelect,
      mimeTypes: mimeTypes,
      folderId: folderId,
      title: 'Select Files from Folder',
    );
  }

  /// Download file content as bytes
  Future<List<int>?> downloadFileAsBytes(String fileId) async {
    try {
      final api = await _api();

      final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

      final List<int> bytes = [];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      return bytes;

    } catch (e) {
      log('Error downloading file: $e');
      throw Exception('Failed to download file: $e');
    }
  }

  /// Get file metadata
  Future<DriveFile?> getFileMetadata(String fileId) async {
    try {
      final api = await _api();

      // Explicitly cast the result of api.files.get to drive.File
      final file = await api.files.get(
        fileId,
        $fields: 'id, name, mimeType, size, parents, createdTime, modifiedTime, webViewLink, webContentLink, thumbnailLink',
      ) as drive.File;

      // Now, you can safely pass the file object to the factory constructor
      return DriveFile.fromGoogleDriveFile(file);

    } catch (e) {
      log('Error getting file metadata: $e');
      throw Exception('Failed to get file metadata: $e');
    }
  }

  /// Show file selection dialog
  Future<List<DriveFile>?> _showFileSelectionDialog({
    required List<DriveFile> files,
    required bool multiSelect,
    required String title,
  }) async {
    final selectedFiles = <DriveFile>[];

    return await Get.dialog<List<DriveFile>?>(
      AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: Get.width * 0.8,
          height: Get.height * 0.6,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  if (multiSelect) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${selectedFiles.length} selected'),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedFiles.clear();
                            });
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                    const Divider(),
                  ],
                  Expanded(
                    child: ListView.builder(
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index];
                        final isSelected = selectedFiles.contains(file);

                        return ListTile(
                          leading: Icon(
                            _getFileIcon(file.mimeType),
                            color: _getFileIconColor(file.mimeType),
                          ),
                          title: Text(
                            file.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getFileTypeLabel(file.mimeType)),
                              if (file.sizeBytes != null)
                                Text(_formatFileSize(file.sizeBytes!)),
                              if (file.modifiedTime != null)
                                Text('Modified: ${_formatDate(file.modifiedTime!)}'),
                            ],
                          ),
                          trailing: multiSelect
                              ? Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selectedFiles.add(file);
                                } else {
                                  selectedFiles.remove(file);
                                }
                              });
                            },
                          )
                              : null,
                          selected: isSelected,
                          onTap: () {
                            if (multiSelect) {
                              setState(() {
                                if (isSelected) {
                                  selectedFiles.remove(file);
                                } else {
                                  selectedFiles.add(file);
                                }
                              });
                            } else {
                              Get.back(result: [file]);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: null),
            child: const Text('Cancel'),
          ),
          if (multiSelect)
            ElevatedButton(
              onPressed: selectedFiles.isEmpty
                  ? null
                  : () => Get.back(result: selectedFiles),
              child: Text('Select (${selectedFiles.length})'),
            ),
        ],
      ),
    );
  }

  // Helper methods for file display
  IconData _getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.video_file;
    if (mimeType.startsWith('audio/')) return Icons.audio_file;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel') || mimeType.contains('csv')) {
      return Icons.table_chart;
    }
    if (mimeType.contains('document') || mimeType.contains('word')) return Icons.description;
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return Icons.slideshow;
    if (mimeType.contains('folder')) return Icons.folder;
    return Icons.insert_drive_file;
  }

  Color _getFileIconColor(String mimeType) {
    if (mimeType.startsWith('image/')) return Colors.purple;
    if (mimeType.startsWith('video/')) return Colors.red;
    if (mimeType.startsWith('audio/')) return Colors.orange;
    if (mimeType.contains('pdf')) return Colors.red;
    if (mimeType.contains('spreadsheet') || mimeType.contains('excel') || mimeType.contains('csv')) {
      return Colors.green;
    }
    if (mimeType.contains('document') || mimeType.contains('word')) return Colors.blue;
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return Colors.orange;
    if (mimeType.contains('folder')) return Colors.amber;
    return Colors.grey;
  }

  String _getFileTypeLabel(String mimeType) {
    if (mimeType.startsWith('image/')) return 'Image';
    if (mimeType.startsWith('video/')) return 'Video';
    if (mimeType.startsWith('audio/')) return 'Audio';
    if (mimeType.contains('pdf')) return 'PDF';
    if (mimeType.contains('csv')) return 'CSV';
    if (mimeType.contains('spreadsheet')) return 'Spreadsheet';
    if (mimeType.contains('excel')) return 'Excel';
    if (mimeType.contains('document')) return 'Document';
    if (mimeType.contains('word')) return 'Word Document';
    if (mimeType.contains('presentation')) return 'Presentation';
    if (mimeType.contains('powerpoint')) return 'PowerPoint';
    if (mimeType.contains('folder')) return 'Folder';
    return 'File';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Data class representing a Google Drive file
class DriveFile {
  final String id;
  final String name;
  final String mimeType;
  final int? sizeBytes;
  final List<String>? parents;
  final DateTime? createdTime;
  final DateTime? modifiedTime;
  final String? webViewLink;
  final String? webContentLink;
  final String? thumbnailLink;

  DriveFile({
    required this.id,
    required this.name,
    required this.mimeType,
    this.sizeBytes,
    this.parents,
    this.createdTime,
    this.modifiedTime,
    this.webViewLink,
    this.webContentLink,
    this.thumbnailLink,
  });

  factory DriveFile.fromGoogleDriveFile(drive.File file) {
    return DriveFile(
      id: file.id ?? '',
      name: file.name ?? 'Unknown',
      mimeType: file.mimeType ?? 'application/octet-stream',
      sizeBytes: file.size != null ? int.tryParse(file.size!) : null,
      parents: file.parents,
      createdTime: file.createdTime,
      modifiedTime: file.modifiedTime,
      webViewLink: file.webViewLink,
      webContentLink: file.webContentLink,
      thumbnailLink: file.thumbnailLink,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'parents': parents,
      'createdTime': createdTime?.toIso8601String(),
      'modifiedTime': modifiedTime?.toIso8601String(),
      'webViewLink': webViewLink,
      'webContentLink': webContentLink,
      'thumbnailLink': thumbnailLink,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is DriveFile &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DriveFile(id: $id, name: $name, mimeType: $mimeType)';
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