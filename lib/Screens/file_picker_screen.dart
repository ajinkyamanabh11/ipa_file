import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';

import '../services/file_picker_service.dart';
import '../services/google_drive_service.dart';
import '../controllers/google_signin_controller.dart';

class FilePickerScreen extends StatefulWidget {
  const FilePickerScreen({super.key});

  @override
  State<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends State<FilePickerScreen> {
  final FilePickerService _filePickerService = Get.find<FilePickerService>();
  final GoogleSignInController _googleSignIn = Get.find<GoogleSignInController>();

  final RxList<drive.File> _currentFiles = <drive.File>[].obs;
  final RxList<drive.File> _currentFolders = <drive.File>[].obs;
  final RxBool _isLoading = false.obs;
  final RxString _currentFolderId = 'root'.obs;
  final RxString _currentPath = 'My Drive'.obs;
  final RxString _uploadProgress = ''.obs;

  final List<String> _folderStack = ['root'];
  final List<String> _pathStack = ['My Drive'];

  @override
  void initState() {
    super.initState();
    _loadCurrentFolder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Drive File Manager'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCurrentFolder,
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: _showCreateFolderDialog,
          ),
        ],
      ),
      body: Obx(() => Column(
        children: [
          // Breadcrumb Navigation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(Icons.folder_open, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentPath.value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_folderStack.length > 1)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _navigateBack,
                  ),
              ],
            ),
          ),

          // Upload Progress
          if (_uploadProgress.value.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Text(
                _uploadProgress.value,
                style: TextStyle(color: Colors.blue[800]),
              ),
            ),

          // File List
          Expanded(
            child: _isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadCurrentFolder,
                    child: ListView(
                      children: [
                        // Folders Section
                        if (_currentFolders.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Folders',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ..._currentFolders.map((folder) => _buildFolderTile(folder)),
                          const Divider(),
                        ],

                        // Files Section
                        if (_currentFiles.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Files',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ..._currentFiles.map((file) => _buildFileTile(file)),
                        ],

                        // Empty State
                        if (_currentFiles.isEmpty && _currentFolders.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.folder_open_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'This folder is empty',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      )),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: "upload_local",
            onPressed: _pickAndUploadLocalFiles,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Files'),
            backgroundColor: Colors.blue,
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: "pick_csv",
            onPressed: _pickCsvFiles,
            icon: const Icon(Icons.table_chart),
            label: const Text('Pick CSV'),
            backgroundColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildFolderTile(drive.File folder) {
    return ListTile(
      leading: const Icon(Icons.folder, color: Colors.blue, size: 32),
      title: Text(
        folder.name ?? 'Unnamed Folder',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      onTap: () => _navigateToFolder(folder),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'delete':
              _deleteFile(folder);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTile(drive.File file) {
    final size = _formatFileSize(file.size);
    final date = _formatDate(file.modifiedTime);
    final isImage = file.mimeType?.startsWith('image/') ?? false;
    final isCsv = file.mimeType?.contains('csv') ?? false;

    IconData icon;
    Color iconColor;

    if (isImage) {
      icon = Icons.image;
      iconColor = Colors.green;
    } else if (isCsv) {
      icon = Icons.table_chart;
      iconColor = Colors.orange;
    } else {
      icon = Icons.insert_drive_file;
      iconColor = Colors.grey;
    }

    return ListTile(
      leading: Icon(icon, color: iconColor, size: 32),
      title: Text(
        file.name ?? 'Unnamed File',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text('$size • $date'),
      onTap: () => _downloadFile(file),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'download':
              _downloadFile(file);
              break;
            case 'delete':
              _deleteFile(file);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'download',
            child: Row(
              children: [
                Icon(Icons.download),
                SizedBox(width: 8),
                Text('Download'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCurrentFolder() async {
    _isLoading.value = true;
    try {
      final [folders, files] = await Future.wait([
        _filePickerService.getDriveFolders(parentId: _currentFolderId.value == 'root' ? null : _currentFolderId.value),
        _filePickerService.browseGoogleDriveFiles(folderId: _currentFolderId.value == 'root' ? null : _currentFolderId.value),
      ]);

      _currentFolders.value = folders;
      _currentFiles.value = files.where((f) => f.mimeType != 'application/vnd.google-apps.folder').toList();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load folder: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  void _navigateToFolder(drive.File folder) {
    if (folder.id != null) {
      _folderStack.add(folder.id!);
      _pathStack.add(folder.name ?? 'Unnamed');
      _currentFolderId.value = folder.id!;
      _currentPath.value = _pathStack.join(' / ');
      _loadCurrentFolder();
    }
  }

  void _navigateBack() {
    if (_folderStack.length > 1) {
      _folderStack.removeLast();
      _pathStack.removeLast();
      _currentFolderId.value = _folderStack.last;
      _currentPath.value = _pathStack.join(' / ');
      _loadCurrentFolder();
    }
  }

  Future<void> _pickAndUploadLocalFiles() async {
    try {
      final files = await _filePickerService.pickLocalFiles(
        allowMultiple: true,
      );

      if (files != null && files.isNotEmpty) {
        _uploadProgress.value = 'Uploading ${files.length} file(s)...';

        final uploadedIds = await _filePickerService.uploadFilesToDrive(
          files,
          _currentFolderId.value,
          onProgress: (fileName, progress) {
            _uploadProgress.value = 'Uploading $fileName: ${(progress * 100).toInt()}%';
          },
        );

        _uploadProgress.value = '';
        
        Get.snackbar(
          'Success',
          'Uploaded ${files.length} file(s) successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        _loadCurrentFolder();
      }
    } catch (e) {
      _uploadProgress.value = '';
      Get.snackbar(
        'Error',
        'Failed to upload files: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _pickCsvFiles() async {
    try {
      final files = await _filePickerService.pickLocalFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: true,
      );

      if (files != null && files.isNotEmpty) {
        // Process CSV files - you can add specific CSV handling logic here
        Get.snackbar(
          'CSV Files Selected',
          'Selected ${files.length} CSV file(s): ${files.map((f) => f.name).join(', ')}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );

        // Optionally upload them
        await _filePickerService.uploadFilesToDrive(files, _currentFolderId.value);
        _loadCurrentFolder();
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick CSV files: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _downloadFile(drive.File file) async {
    if (file.id == null) return;

    try {
      final content = await _filePickerService.downloadDriveFileToLocal(
        file.id!,
        file.name ?? 'download',
      );

      Get.snackbar(
        'Downloaded',
        'File ${file.name} downloaded successfully (${content.length} characters)',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to download file: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _deleteFile(drive.File file) async {
    if (file.id == null) return;

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Get.find<GoogleDriveService>().deleteFile(file.id!);
        Get.snackbar(
          'Deleted',
          'File ${file.name} deleted successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        _loadCurrentFolder();
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to delete file: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    
    final folderName = await Get.dialog<String>(
      AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (folderName != null && folderName.isNotEmpty) {
      try {
        await _filePickerService.createDriveFolder(
          folderName,
          parentId: _currentFolderId.value == 'root' ? null : _currentFolderId.value,
        );
        
        Get.snackbar(
          'Success',
          'Folder "$folderName" created successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        
        _loadCurrentFolder();
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to create folder: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return 'Unknown size';
    
    int bytes;
    try {
      bytes = int.parse(size.toString());
    } catch (e) {
      return 'Unknown size';
    }
    
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return DateFormat('MMM dd, yyyy').format(date);
  }
}