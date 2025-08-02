import 'package:get/get.dart';
import '../services/softagri_csv_service.dart';
import '../controllers/google_signin_controller.dart';

class SoftagriCsvController extends GetxController {
  final SoftagriCsvService _csvService = Get.find<SoftagriCsvService>();
  final GoogleSignInController _authController = Get.find<GoogleSignInController>();

  // Observable state
  final RxBool isLoading = false.obs;
  final RxString statusMessage = ''.obs;
  final RxMap<String, double> downloadProgress = <String, double>{}.obs;
  final RxMap<String, String> downloadedFiles = <String, String>{}.obs;
  final RxBool hasAccess = false.obs;
  final RxMap<String, Map<String, dynamic>> filesInfo = <String, Map<String, dynamic>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    
    // Listen to service updates
    _csvService.downloadProgress.listen((progress) {
      downloadProgress.value = progress;
    });
    
    _csvService.downloadedFiles.listen((files) {
      downloadedFiles.value = files;
    });
    
    _csvService.currentOperation.listen((operation) {
      statusMessage.value = operation;
    });
    
    // Check access when controller initializes
    if (_authController.isSignedIn) {
      checkAccess();
    }
  }

  /// Check if user has access to the Softagri folder
  Future<void> checkAccess() async {
    try {
      isLoading.value = true;
      statusMessage.value = 'Checking folder access...';
      
      hasAccess.value = await _csvService.checkFolderAccess();
      
      if (hasAccess.value) {
        statusMessage.value = 'Access confirmed';
        await getFilesInfo();
      } else {
        statusMessage.value = 'No access to Softagri folder structure';
      }
    } catch (e) {
      statusMessage.value = 'Error checking access: $e';
      hasAccess.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Get information about all CSV files
  Future<void> getFilesInfo() async {
    try {
      statusMessage.value = 'Getting files information...';
      final info = await _csvService.getCsvFilesInfo();
      filesInfo.value = info;
      statusMessage.value = 'Found ${info.length} files';
    } catch (e) {
      statusMessage.value = 'Error getting files info: $e';
    }
  }

  /// Download all CSV files with progress tracking
  Future<void> downloadAllFiles() async {
    if (!_authController.isSignedIn) {
      statusMessage.value = 'Please sign in first';
      return;
    }

    if (!hasAccess.value) {
      statusMessage.value = 'No access to folder. Please check your permissions.';
      return;
    }

    try {
      isLoading.value = true;
      statusMessage.value = 'Starting download...';
      
      final results = await _csvService.downloadAllCsvFiles(
        onProgress: (fileName, progress) {
          // Progress is automatically updated via service listeners
        },
        onFileComplete: (fileName, content) {
          print('✅ Downloaded: $fileName (${content.length} characters)');
        },
      );

      statusMessage.value = 'Download completed! Downloaded ${results.length} files.';
      
      // Optionally save to local storage
      await saveToLocal();
      
    } catch (e) {
      statusMessage.value = 'Download failed: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Download a specific CSV file
  Future<void> downloadSpecificFile(String fileName) async {
    if (!_authController.isSignedIn) {
      statusMessage.value = 'Please sign in first';
      return;
    }

    try {
      isLoading.value = true;
      statusMessage.value = 'Downloading $fileName...';
      
      final content = await _csvService.downloadSpecificCsv(fileName);
      
      if (content != null) {
        statusMessage.value = '$fileName downloaded successfully';
      } else {
        statusMessage.value = 'Failed to download $fileName';
      }
    } catch (e) {
      statusMessage.value = 'Error downloading $fileName: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Save all downloaded files to local storage
  Future<void> saveToLocal() async {
    try {
      statusMessage.value = 'Saving files locally...';
      final savedPaths = await _csvService.saveAllCsvsToLocal();
      statusMessage.value = 'Saved ${savedPaths.length} files locally';
    } catch (e) {
      statusMessage.value = 'Error saving files: $e';
    }
  }

  /// Get parsed data for a specific CSV file
  List<Map<String, dynamic>>? getParsedData(String fileName) {
    return _csvService.getParsedCsv(fileName);
  }

  /// Get raw CSV content for a specific file
  String? getRawCsvContent(String fileName) {
    return downloadedFiles[fileName];
  }

  /// Clear all downloaded data
  void clearData() {
    _csvService.clearDownloadedData();
    downloadProgress.clear();
    downloadedFiles.clear();
    statusMessage.value = 'Data cleared';
  }

  /// Get download statistics
  Map<String, dynamic> getStats() {
    return _csvService.getDownloadStats();
  }

  /// Get available CSV file names
  List<String> get availableFiles => SoftagriCsvService.requiredCsvFiles;

  /// Check if a specific file is downloaded
  bool isFileDownloaded(String fileName) {
    return downloadedFiles.containsKey(fileName);
  }

  /// Get file size information
  String getFileSizeText(String fileName) {
    final fileInfo = filesInfo[fileName];
    if (fileInfo == null) return 'Unknown size';
    
    final size = fileInfo['size'] as int? ?? 0;
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Get progress percentage for a specific file
  double getFileProgress(String fileName) {
    return downloadProgress[fileName] ?? 0.0;
  }

  /// Get progress text for UI display
  String getProgressText(String fileName) {
    final progress = getFileProgress(fileName);
    return '${(progress * 100).toStringAsFixed(0)}%';
  }
}