import 'dart:developer';
import 'package:get/get.dart';
import '../services/automated_csv_service.dart';

class AutomatedCsvController extends GetxController {
  final AutomatedCsvService _csvService = Get.find<AutomatedCsvService>();

  // Observable state
  final RxList<CsvFileInfo> csvFiles = <CsvFileInfo>[].obs;
  final RxList<CsvFileInfo> downloadedFiles = <CsvFileInfo>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isDownloading = false.obs;
  final RxString searchQuery = ''.obs;
  final RxString downloadProgress = ''.obs;
  final RxString errorMessage = ''.obs;

  // Stats
  final RxInt totalFiles = 0.obs;
  final RxInt downloadedCount = 0.obs;
  final RxInt failedCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    searchCsvFiles();
  }

  /// Search for CSV files in the target folder
  Future<void> searchCsvFiles() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final files = await _csvService.searchCsvFiles();
      csvFiles.value = files;
      totalFiles.value = files.length;

      log('📊 AutomatedCsvController: Found ${files.length} CSV files');
    } catch (e) {
      errorMessage.value = 'Failed to search CSV files: $e';
      log('❌ AutomatedCsvController: Error searching CSV files: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Download all CSV files automatically
  Future<void> downloadAllFiles() async {
    try {
      isDownloading.value = true;
      downloadProgress.value = 'Preparing download...';
      errorMessage.value = '';
      downloadedCount.value = 0;
      failedCount.value = 0;

      final files = await _csvService.downloadAllCsvFiles();
      downloadedFiles.value = files;

      // Update stats
      downloadedCount.value = files.where((f) => f.isDownloaded).length;
      failedCount.value = files.where((f) => !f.isDownloaded).length;

      downloadProgress.value = downloadedCount.value == files.length
          ? 'All files downloaded successfully!'
          : 'Download completed with ${failedCount.value} failures';

      log('✅ AutomatedCsvController: Downloaded ${downloadedCount.value}/${files.length} files');
    } catch (e) {
      errorMessage.value = 'Failed to download CSV files: $e';
      downloadProgress.value = '';
      log('❌ AutomatedCsvController: Error downloading files: $e');
    } finally {
      isDownloading.value = false;
    }
  }

  /// Download a specific CSV file
  Future<void> downloadSpecificFile(CsvFileInfo fileInfo) async {
    try {
      downloadProgress.value = 'Downloading ${fileInfo.name}...';
      
      final downloadedFile = await _csvService.downloadSpecificCsvFile(fileInfo);
      
      // Update the file in the list
      final index = downloadedFiles.indexWhere((f) => f.id == fileInfo.id);
      if (index != -1) {
        downloadedFiles[index] = downloadedFile;
      } else {
        downloadedFiles.add(downloadedFile);
      }

      downloadProgress.value = 'Downloaded ${fileInfo.name}';
      
      // Update stats
      downloadedCount.value = downloadedFiles.where((f) => f.isDownloaded).length;

      log('✅ AutomatedCsvController: Downloaded ${fileInfo.name}');
    } catch (e) {
      errorMessage.value = 'Failed to download ${fileInfo.name}: $e';
      log('❌ AutomatedCsvController: Error downloading ${fileInfo.name}: $e');
    }
  }

  /// Search files with query
  Future<void> searchWithQuery(String query) async {
    try {
      searchQuery.value = query;
      isLoading.value = true;
      errorMessage.value = '';

      final files = await _csvService.searchCsvFilesWithQuery(query);
      csvFiles.value = files;

      log('🔍 AutomatedCsvController: Found ${files.length} files matching "$query"');
    } catch (e) {
      errorMessage.value = 'Failed to search files: $e';
      log('❌ AutomatedCsvController: Error searching with query "$query": $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Get file preview
  String getFilePreview(CsvFileInfo fileInfo) {
    if (fileInfo.content == null || fileInfo.content!.isEmpty) {
      return 'No content available. Download the file to view content.';
    }
    return _csvService.getFilePreview(fileInfo.content!);
  }

  /// Clear search and show all files
  void clearSearch() {
    searchQuery.value = '';
    searchCsvFiles();
  }

  /// Refresh the file list
  Future<void> refresh() async {
    if (searchQuery.value.isEmpty) {
      await searchCsvFiles();
    } else {
      await searchWithQuery(searchQuery.value);
    }
  }

  /// Clear error message
  void clearError() {
    errorMessage.value = '';
  }

  /// Get download progress percentage
  double get downloadProgressPercent {
    if (totalFiles.value == 0) return 0.0;
    return downloadedCount.value / totalFiles.value;
  }

  /// Check if a file is downloaded
  bool isFileDownloaded(String fileId) {
    return downloadedFiles.any((f) => f.id == fileId && f.isDownloaded);
  }

  /// Get downloaded file content
  CsvFileInfo? getDownloadedFile(String fileId) {
    try {
      return downloadedFiles.firstWhere((f) => f.id == fileId && f.isDownloaded);
    } catch (e) {
      return null;
    }
  }
}