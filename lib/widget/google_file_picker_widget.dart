import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/google_picker_service.dart';
import '../services/google_drive_service.dart';

class GoogleFilePickerWidget extends StatefulWidget {
  final Function(List<Map<String, dynamic>> files)? onFilesSelected;
  final Function(Map<String, String> filesContent)? onFilesDownloaded;
  final bool multiSelect;
  final List<String>? allowedMimeTypes;
  final String? title;

  const GoogleFilePickerWidget({
    Key? key,
    this.onFilesSelected,
    this.onFilesDownloaded,
    this.multiSelect = false,
    this.allowedMimeTypes,
    this.title,
  }) : super(key: key);

  @override
  State<GoogleFilePickerWidget> createState() => _GoogleFilePickerWidgetState();
}

class _GoogleFilePickerWidgetState extends State<GoogleFilePickerWidget> {
  final _pickerService = Get.find<GooglePickerService>();
  final _driveService = Get.find<GoogleDriveService>();

  bool _isLoading = false;
  List<Map<String, dynamic>> _selectedFiles = [];
  Map<String, double> _downloadProgress = {};
  Map<String, String> _downloadedContent = {};
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title != null) ...[
              Text(
                widget.title!,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
            ],

            // Pick Files Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickFiles,
                icon: const Icon(Icons.drive_folder_upload),
                label: Text(
                  widget.multiSelect
                      ? 'Select Files from Google Drive'
                      : 'Select File from Google Drive',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _error = null),
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
            ],

            // Selected Files List
            if (_selectedFiles.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Selected Files:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(_selectedFiles.length, (index) {
                final file = _selectedFiles[index];
                final fileName = file['name'] as String;
                final fileSize = file['sizeBytes'] as String?;
                final progress = _downloadProgress[fileName] ?? 0.0;
                final isDownloaded = _downloadedContent.containsKey(fileName);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      _getFileIcon(file['mimeType'] as String?),
                      color: Colors.blue,
                    ),
                    title: Text(fileName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fileSize != null)
                          Text('Size: ${_formatFileSize(int.tryParse(fileSize) ?? 0)}'),
                        if (progress > 0 && progress < 1.0)
                          LinearProgressIndicator(value: progress),
                        if (isDownloaded)
                          const Text(
                            'Downloaded ✓',
                            style: TextStyle(color: Colors.green),
                          ),
                      ],
                    ),
                    trailing: isDownloaded
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : progress > 0
                        ? CircularProgressIndicator(value: progress)
                        : IconButton(
                      onPressed: () => _removeFile(index),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                );
              }),
            ],

            // Download Button
            if (_selectedFiles.isNotEmpty && _downloadedContent.isEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _downloadFiles,
                  icon: const Icon(Icons.download),
                  label: const Text('Download Selected Files'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],

            // Success Message
            if (_downloadedContent.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_downloadedContent.length} file(s) downloaded successfully!',
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final files = await _pickerService.pickFiles(
        multiSelect: widget.multiSelect,
        mimeTypes: widget.allowedMimeTypes ?? [
          'text/csv',
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ],
      );

      if (files != null && files.isNotEmpty) {
        setState(() {
          _selectedFiles = files;
          _downloadProgress.clear();
          _downloadedContent.clear();
        });

        widget.onFilesSelected?.call(files);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to select files: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadFiles() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _downloadProgress.clear();
    });

    try {
      final content = await _driveService.downloadMultipleFiles(
        _selectedFiles,
        onProgress: (fileName, progress) {
          setState(() {
            _downloadProgress[fileName] = progress;
          });
        },
      );

      setState(() {
        _downloadedContent = content;
      });

      widget.onFilesDownloaded?.call(content);
    } catch (e) {
      setState(() {
        _error = 'Failed to download files: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
        _downloadProgress.clear();
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      if (_selectedFiles.isEmpty) {
        _downloadedContent.clear();
        _downloadProgress.clear();
      }
    });
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.description;

    if (mimeType.contains('spreadsheet') || mimeType.contains('excel')) {
      return Icons.table_chart;
    } else if (mimeType.contains('csv')) {
      return Icons.grid_on;
    } else if (mimeType.contains('document')) {
      return Icons.description;
    } else if (mimeType.contains('image')) {
      return Icons.image;
    } else if (mimeType.contains('pdf')) {
      return Icons.picture_as_pdf;
    }

    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes == 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }
}