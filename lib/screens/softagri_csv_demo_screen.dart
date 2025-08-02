import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/softagri_csv_controller.dart';
import '../controllers/google_signin_controller.dart';

class SoftagriCsvDemoScreen extends StatelessWidget {
  const SoftagriCsvDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize the controller
    final controller = Get.put(SoftagriCsvController());
    final authController = Get.find<GoogleSignInController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Softagri CSV Demo'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Obx(() {
        if (!authController.isSignedIn) {
          return const _SignInPrompt();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(controller),
              const SizedBox(height: 16),
              _buildActionButtons(controller),
              const SizedBox(height: 16),
              _buildFilesList(controller),
              const SizedBox(height: 16),
              _buildProgressSection(controller),
              const SizedBox(height: 16),
              _buildStatsCard(controller),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStatusCard(SoftagriCsvController controller) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  controller.hasAccess.value
                      ? Icons.check_circle
                      : Icons.warning,
                  color: controller.hasAccess.value
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Folder Access Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              controller.hasAccess.value
                  ? '✅ Access to Softagri folder confirmed'
                  : '❌ No access to Softagri folder structure',
              style: TextStyle(
                color: controller.hasAccess.value
                    ? Colors.green[700]
                    : Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            if (controller.statusMessage.value.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  controller.statusMessage.value,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(SoftagriCsvController controller) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.checkAccess(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check Access'),
                ),
                ElevatedButton.icon(
                  onPressed: !controller.hasAccess.value || controller.isLoading.value
                      ? null
                      : () => controller.getFilesInfo(),
                  icon: const Icon(Icons.info),
                  label: const Text('Get Files Info'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: !controller.hasAccess.value || controller.isLoading.value
                      ? null
                      : () => controller.downloadAllFiles(),
                  icon: const Icon(Icons.download),
                  label: const Text('Download All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: controller.downloadedFiles.isEmpty
                      ? null
                      : () => controller.clearData(),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesList(SoftagriCsvController controller) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CSV Files',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...controller.availableFiles.map((fileName) {
              final isDownloaded = controller.isFileDownloaded(fileName);
              final fileSize = controller.getFileSizeText(fileName);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isDownloaded ? Colors.green[50] : null,
                child: ListTile(
                  leading: Icon(
                    isDownloaded ? Icons.check_circle : Icons.description,
                    color: isDownloaded ? Colors.green : Colors.grey,
                  ),
                  title: Text(fileName),
                  subtitle: Text('Size: $fileSize'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.isLoading.value)
                        Text(controller.getProgressText(fileName))
                      else if (isDownloaded)
                        const Icon(Icons.download_done, color: Colors.green),
                      IconButton(
                        onPressed: !controller.hasAccess.value || controller.isLoading.value
                            ? null
                            : () => controller.downloadSpecificFile(fileName),
                        icon: const Icon(Icons.download),
                        tooltip: 'Download this file',
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(SoftagriCsvController controller) {
    if (!controller.isLoading.value && controller.downloadProgress.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Download Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (controller.isLoading.value)
              const LinearProgressIndicator(),
            const SizedBox(height: 8),
            ...controller.downloadProgress.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key),
                    LinearProgressIndicator(
                      value: entry.value,
                      backgroundColor: Colors.grey[300],
                    ),
                    Text('${(entry.value * 100).toStringAsFixed(0)}%'),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(SoftagriCsvController controller) {
    final stats = controller.getStats();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total Files', '${stats['totalFiles']}'),
                _buildStatItem('Downloaded', '${stats['downloadedFiles']}'),
                _buildStatItem('Failed', '${stats['failedFiles']}'),
                _buildStatItem('Success Rate', '${stats['successRate']}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<GoogleSignInController>();
    
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.login,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign In Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please sign in with Google to access\nSoftagri CSV files from Google Drive.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => authController.login(),
                icon: const Icon(Icons.login),
                label: const Text('Sign In with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}