import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widget/google_file_picker_widget.dart';
import '../controllers/google_signin_controller.dart';

class DriveFilePickerDemo extends StatefulWidget {
  const DriveFilePickerDemo({Key? key}) : super(key: key);

  @override
  State<DriveFilePickerDemo> createState() => _DriveFilePickerDemoState();
}

class _DriveFilePickerDemoState extends State<DriveFilePickerDemo> {
  final _googleController = Get.find<GoogleSignInController>();
  
  List<Map<String, dynamic>> _selectedFiles = [];
  Map<String, String> _downloadedContent = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Drive File Picker Demo'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          Obx(() => _googleController.isSignedIn
            ? TextButton.icon(
                onPressed: _googleController.logout,
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Logout', style: TextStyle(color: Colors.white)),
              )
            : TextButton.icon(
                onPressed: _googleController.login,
                icon: const Icon(Icons.login, color: Colors.white),
                label: const Text('Login', style: TextStyle(color: Colors.white)),
              )
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: Colors.blue.shade50,
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_download,
                    size: 64,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Google Drive File Picker',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select and download files from your Google Drive using the drive.file scope',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.blue.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Login Status Section
            Obx(() => Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _googleController.isSignedIn 
                  ? Colors.green.shade50 
                  : Colors.orange.shade50,
                border: Border.all(
                  color: _googleController.isSignedIn 
                    ? Colors.green.shade300 
                    : Colors.orange.shade300,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _googleController.isSignedIn 
                      ? Icons.check_circle 
                      : Icons.warning,
                    color: _googleController.isSignedIn 
                      ? Colors.green.shade700 
                      : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _googleController.isSignedIn 
                            ? 'Signed in successfully!' 
                            : 'Please sign in to continue',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _googleController.isSignedIn 
                              ? Colors.green.shade700 
                              : Colors.orange.shade700,
                          ),
                        ),
                        if (_googleController.isSignedIn && _googleController.user.value != null)
                          Text(
                            'Email: ${_googleController.user.value!.email}',
                            style: TextStyle(
                              color: Colors.green.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )),

            // File Picker Section
            Obx(() => _googleController.isSignedIn
              ? GoogleFilePickerWidget(
                  title: 'Select Files from Google Drive',
                  multiSelect: true,
                  allowedMimeTypes: [
                    'text/csv',
                    'application/vnd.ms-excel',
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    'application/vnd.google-apps.spreadsheet',
                  ],
                  onFilesSelected: (files) {
                    setState(() {
                      _selectedFiles = files;
                    });
                  },
                  onFilesDownloaded: (content) {
                    setState(() {
                      _downloadedContent = content;
                    });
                  },
                )
              : Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.login,
                        size: 48,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Please sign in with Google to access Drive files',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _googleController.login,
                        icon: const Icon(Icons.login),
                        label: const Text('Sign In with Google'),
                      ),
                    ],
                  ),
                ),
            ),

            // Downloaded Content Preview Section
            if (_downloadedContent.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.all(16),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Downloaded Content Preview',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._downloadedContent.entries.map((entry) {
                          final fileName = entry.key;
                          final content = entry.value;
                          final lines = content.split('\n');
                          final preview = lines.take(5).join('\n');
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ExpansionTile(
                              leading: const Icon(Icons.description, color: Colors.blue),
                              title: Text(fileName),
                              subtitle: Text('${lines.length} lines, ${content.length} characters'),
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Preview (first 5 lines):',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        preview,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (lines.length > 5) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          '... and ${lines.length - 5} more lines',
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Information Section
            Container(
              margin: const EdgeInsets.all(16),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'About drive.file Scope',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '• The drive.file scope allows access only to files that the user explicitly selects through the Google Picker\n'
                        '• This provides better security and user control compared to drive.readonly\n'
                        '• No verification is required from Google for this scope\n'
                        '• Users can select files from any folder they have access to\n'
                        '• Multiple file selection is supported',
                        style: TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer spacing
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}