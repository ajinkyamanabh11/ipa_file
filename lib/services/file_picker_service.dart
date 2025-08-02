import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'dart:developer';

import '../controllers/google_signin_controller.dart';
import 'google_drive_service.dart';

class FilePickerService extends GetxService {
  final GoogleDriveService _driveService = Get.find<GoogleDriveService>();
  final GoogleSignInController _googleSignIn = Get.find<GoogleSignInController>();

  /// Pick files from local device storage
  Future<List<PlatformFile>?> pickLocalFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: true, // Include file data for upload
      );

      if (result != null) {
        log('📁 FilePickerService: Selected ${result.files.length} file(s)');
        return result.files;
      }
      return null;
    } catch (e) {
      log('❌ FilePickerService: Error picking local files: $e');
      throw Exception('Failed to pick files: $e');
    }
  }

  /// Upload selected files to Google Drive
  Future<List<String>> uploadFilesToDrive(
      List<PlatformFile> files,
      String targetFolderId, {
        Function(String fileName, double progress)? onProgress,
      }) async {
    final uploadedFileIds = <String>[];

    try {
      final api = await _getDriveApi();

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        log('📤 FilePickerService: Uploading ${file.name} (${i + 1}/${files.length})');

        final fileId = await _uploadSingleFile(
          api,
          file,
          targetFolderId,
          onProgress: (progress) {
            onProgress?.call(file.name, progress);
          },
        );

        uploadedFileIds.add(fileId);
        log('✅ FilePickerService: Uploaded ${file.name} with ID: $fileId');
      }

      return uploadedFileIds;
    } catch (e) {
      log('❌ FilePickerService: Error uploading files: $e');
      throw Exception('Failed to upload files: $e');
    }
  }

  /// Upload a single file to Google Drive
  Future<String> _uploadSingleFile(
      drive.DriveApi api,
      PlatformFile platformFile,
      String parentFolderId, {
        Function(double progress)? onProgress,
      }) async {
    try {
      // Validate file data
      if (platformFile.bytes == null && platformFile.path == null) {
        throw Exception('No file data available for ${platformFile.name}');
      }

      // Get file data
      Uint8List fileData;
      if (platformFile.bytes != null) {
        fileData = platformFile.bytes!;
      } else {
        final file = File(platformFile.path!);
        fileData = await file.readAsBytes();
      }

      // Create drive file metadata
      final driveFile = drive.File()
        ..name = platformFile.name
        ..parents = [parentFolderId];

      // Create media upload
      final media = drive.Media(
        Stream.fromIterable([fileData]),
        fileData.length,
        contentType: _getMimeType(platformFile.name),
      );

      // Upload to Google Drive
      final uploadedFile = await api.files.create(
        driveFile,
        uploadMedia: media,
      );

      return uploadedFile.id!;
    } catch (e) {
      log('❌ FilePickerService: Error uploading ${platformFile.name}: $e');
      rethrow;
    }
  }

  /// Get MIME type based on file extension
  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'csv':
        return 'text/csv';
      case 'txt':
        return 'text/plain';
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'xls':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }

  /// Browse and select files from Google Drive
  Future<List<drive.File>> browseGoogleDriveFiles({
    String? folderId,
    String? query,
    int pageSize = 20,
  }) async {
    try {
      final api = await _getDriveApi();

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
        $fields: 'files(id,name,mimeType,size,modifiedTime,parents)',
        orderBy: 'modifiedTime desc',
      );

      return fileList.files ?? [];
    } catch (e) {
      log('❌ FilePickerService: Error browsing Google Drive: $e');
      throw Exception('Failed to browse Google Drive: $e');
    }
  }

  /// Get folders from Google Drive for navigation
  Future<List<drive.File>> getDriveFolders({String? parentId}) async {
    try {
      final api = await _getDriveApi();

      String query = "mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      if (parentId != null) {
        query += " and '$parentId' in parents";
      }

      final folderList = await api.files.list(
        q: query,
        $fields: 'files(id,name,parents)',
        orderBy: 'name',
      );

      return folderList.files ?? [];
    } catch (e) {
      log('❌ FilePickerService: Error getting Drive folders: $e');
      throw Exception('Failed to get Drive folders: $e');
    }
  }

  /// Create a new folder in Google Drive
  Future<String> createDriveFolder(String folderName, {String? parentId}) async {
    try {
      final api = await _getDriveApi();

      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      if (parentId != null) {
        folder.parents = [parentId];
      }

      final createdFolder = await api.files.create(folder);
      log('📁 FilePickerService: Created folder "$folderName" with ID: ${createdFolder.id}');

      return createdFolder.id!;
    } catch (e) {
      log('❌ FilePickerService: Error creating folder: $e');
      throw Exception('Failed to create folder: $e');
    }
  }

  /// Download file from Google Drive to local storage
  Future<String> downloadDriveFileToLocal(String fileId, String fileName) async {
    try {
      final csvContent = await _driveService.downloadCsv(fileId);

      // For mobile, you might want to save to app documents directory
      // This is a simplified implementation - adjust based on your needs
      log('📥 FilePickerService: Downloaded file "$fileName" (${csvContent.length} characters)');

      return csvContent;
    } catch (e) {
      log('❌ FilePickerService: Error downloading file: $e');
      throw Exception('Failed to download file: $e');
    }
  }

  /// Get Google Drive API instance
  Future<drive.DriveApi> _getDriveApi() async {
    final headers = await _googleSignIn.getAuthHeaders();
    if (headers == null) throw Exception('Google Sign-In required');
    return drive.DriveApi(_GoogleAuthClient(headers));
  }
}

/// Private auth client for Google Drive API
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request..headers.addAll(_headers));
}