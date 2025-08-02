import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/google_drive_service.dart';
import '../controllers/google_signin_controller.dart';

/// A widget that demonstrates the mobile-compatible Google Drive file picker
class GoogleDriveFilePickerWidget extends StatefulWidget {
  const GoogleDriveFilePickerWidget({super.key});

  @override
  State<GoogleDriveFilePickerWidget> createState() => _GoogleDriveFilePickerWidgetState();
}

class _GoogleDriveFilePickerWidgetState extends State<GoogleDriveFilePickerWidget> {
  final _googleSignIn = Get.find<GoogleSignInController>();
  final _driveService = Get.find<GoogleDriveService>();
  
  List<DriveFile> _selectedFiles = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Drive File Picker'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sign-in status
            Obx(() => Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Account Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_googleSignIn.isSignedIn) ...[
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Signed in as: ${_googleSignIn.user.value?.email ?? 'Unknown'}',
                              style: const TextStyle(color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _googleSignIn.logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Not signed in',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _googleSignIn.login,
                        icon: const Icon(Icons.login),
                        label: const Text('Sign In with Google'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )),
            
            const SizedBox(height: 16),
            
            // File picker buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'File Picker Options',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    
                    // Pick any files
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _pickFiles(false),
                      icon: const Icon(Icons.file_present),
                      label: const Text('Pick Single File'),
                    ),
                    const SizedBox(height: 8),
                    
                    // Pick multiple files
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _pickFiles(true),
                      icon: const Icon(Icons.library_books),
                      label: const Text('Pick Multiple Files'),
                    ),
                    const SizedBox(height: 8),
                    
                    // Pick CSV files
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickCsvFiles,
                      icon: const Icon(Icons.table_chart),
                      label: const Text('Pick CSV Files'),
                    ),
                    const SizedBox(height: 8),
                    
                    // Pick images
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickImages,
                      icon: const Icon(Icons.image),
                      label: const Text('Pick Images'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Selected files display
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Selected Files (${_selectedFiles.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (_selectedFiles.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedFiles.clear();
                                });
                              },
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      if (_isLoading) ...[
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ] else if (_selectedFiles.isEmpty) ...[
                        const Expanded(
                          child: Center(
                            child: Text(
                              'No files selected',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ListView.builder(
                            itemCount: _selectedFiles.length,
                            itemBuilder: (context, index) {
                              final file = _selectedFiles[index];
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
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => _downloadFile(file),
                                      icon: const Icon(Icons.download),
                                      tooltip: 'Download',
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedFiles.removeAt(index);
                                        });
                                      },
                                      icon: const Icon(Icons.delete),
                                      tooltip: 'Remove',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles(bool multiSelect) async {
    if (!_googleSignIn.isSignedIn) {
      Get.snackbar(
        'Sign In Required',
        'Please sign in with your Google account first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final files = await _driveService.pickFiles(
        multiSelect: multiSelect,
        title: multiSelect ? 'Select Multiple Files' : 'Select a File',
      );

      if (files != null && files.isNotEmpty) {
        setState(() {
          if (multiSelect) {
            _selectedFiles.addAll(files);
          } else {
            _selectedFiles = files;
          }
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick files: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickCsvFiles() async {
    if (!_googleSignIn.isSignedIn) {
      Get.snackbar(
        'Sign In Required',
        'Please sign in with your Google account first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final files = await _driveService.pickCsvFiles(multiSelect: true);

      if (files != null && files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick CSV files: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImages() async {
    if (!_googleSignIn.isSignedIn) {
      Get.snackbar(
        'Sign In Required',
        'Please sign in with your Google account first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final files = await _driveService.pickFiles(
        multiSelect: true,
        mimeTypes: [
          'image/jpeg',
          'image/png',
          'image/gif',
          'image/webp',
          'image/bmp',
        ],
        title: 'Select Images',
      );

      if (files != null && files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick images: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadFile(DriveFile file) async {
    try {
      Get.snackbar(
        'Downloading',
        'Starting download of ${file.name}...',
        snackPosition: SnackPosition.BOTTOM,
      );

      if (file.mimeType.contains('csv') || file.mimeType.contains('text')) {
        // For CSV files, use the existing downloadCsv method
        final content = await _driveService.downloadCsv(file.id);
        
        Get.dialog(
          AlertDialog(
            title: Text('File Content: ${file.name}'),
            content: SizedBox(
              width: Get.width * 0.8,
              height: Get.height * 0.6,
              child: SingleChildScrollView(
                child: Text(
                  content.length > 1000 
                    ? '${content.substring(0, 1000)}...\n\n(Content truncated for display)'
                    : content,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        // For other files, download as bytes
        final bytes = await _driveService.downloadFileAsBytes(file.id);
        
        if (bytes != null) {
          Get.snackbar(
            'Download Complete',
            'Downloaded ${file.name} (${_formatFileSize(bytes.length)})',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Download Error',
        'Failed to download ${file.name}: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Helper methods for UI
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
    return 'File';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}