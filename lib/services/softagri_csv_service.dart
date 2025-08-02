import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'google_drive_service.dart';
import '../controllers/google_signin_controller.dart';

class SoftagriCsvService extends GetxService {
  final GoogleDriveService _driveService = Get.find<GoogleDriveService>();
  final GoogleSignInController _authController = Get.find<GoogleSignInController>();

  // The specific CSV files we need to download
  static const List<String> requiredCsvFiles = [
    'SalesInvoiceMaster.csv',
    'SalesInvoiceDetails.csv',
    'ItemMaster.csv',
    'ItemDetail.csv',
    'AccountMaster.csv',
    'AllAccounts.csv',
    'CustomerInformation.csv',
    'SupplierInformation.csv',
    'selfinformation.csv',
  ];

  // Progress tracking
  final RxMap<String, double> downloadProgress = <String, double>{}.obs;
  final RxBool isDownloading = false.obs;
  final RxString currentOperation = ''.obs;
  final RxMap<String, String> downloadedFiles = <String, String>{}.obs;

  /// Find the Softagri_Backups/20252026/softagri_csv folder ID
  Future<String> findSoftagriCsvFolderId() async {
    try {
      currentOperation.value = 'Finding Softagri folder structure...';
      
      // Navigate through the folder structure: My Drive -> Softagri_Backups -> 20252026 -> softagri_csv
      final folderId = await _driveService.folderId([
        'Softagri_Backups',
        '20252026', 
        'softagri_csv'
      ]);
      
      currentOperation.value = 'Found softagri_csv folder';
      return folderId;
    } catch (e) {
      currentOperation.value = 'Error finding folder';
      throw Exception('Failed to find Softagri CSV folder: $e');
    }
  }

  /// Download all required CSV files from the Softagri folder
  Future<Map<String, String>> downloadAllCsvFiles({
    Function(String fileName, double progress)? onProgress,
    Function(String fileName, String content)? onFileComplete,
  }) async {
    if (!_authController.isSignedIn) {
      throw Exception('Please sign in with Google to access CSV files');
    }

    isDownloading.value = true;
    downloadProgress.clear();
    downloadedFiles.clear();
    
    try {
      // Find the CSV folder
      final csvFolderId = await findSoftagriCsvFolderId();
      currentOperation.value = 'Downloading CSV files...';

      final Map<String, String> results = {};

      // Download each required CSV file
      for (int i = 0; i < requiredCsvFiles.length; i++) {
        final fileName = requiredCsvFiles[i];
        currentOperation.value = 'Downloading $fileName (${i + 1}/${requiredCsvFiles.length})';
        
        try {
          // Get file ID
          final fileId = await _driveService.fileId(fileName, csvFolderId);
          
          // Download file with progress tracking
          final csvContent = await _driveService.downloadCsvWithProgress(
            fileId,
            onProgress: (progress) {
              downloadProgress[fileName] = progress;
              onProgress?.call(fileName, progress);
            },
          );

          results[fileName] = csvContent;
          downloadedFiles[fileName] = csvContent;
          downloadProgress[fileName] = 1.0;
          
          onFileComplete?.call(fileName, csvContent);
          
          // Small delay to prevent overwhelming the API
          await Future.delayed(const Duration(milliseconds: 500));
          
        } catch (e) {
          // Log the error but continue with other files
          print('Warning: Failed to download $fileName: $e');
          downloadProgress[fileName] = 0.0;
        }
      }

      currentOperation.value = 'Download complete';
      return results;
      
    } catch (e) {
      currentOperation.value = 'Download failed';
      throw Exception('Failed to download CSV files: $e');
    } finally {
      isDownloading.value = false;
    }
  }

  /// Download a specific CSV file by name
  Future<String?> downloadSpecificCsv(String fileName) async {
    if (!_authController.isSignedIn) {
      throw Exception('Please sign in with Google to access CSV files');
    }

    if (!requiredCsvFiles.contains(fileName)) {
      throw Exception('Invalid CSV file name. Must be one of: ${requiredCsvFiles.join(', ')}');
    }

    try {
      currentOperation.value = 'Downloading $fileName...';
      
      final csvFolderId = await findSoftagriCsvFolderId();
      final fileId = await _driveService.fileId(fileName, csvFolderId);
      
      final csvContent = await _driveService.downloadCsvWithProgress(
        fileId,
        onProgress: (progress) {
          downloadProgress[fileName] = progress;
        },
      );

      downloadedFiles[fileName] = csvContent;
      currentOperation.value = 'Download complete';
      return csvContent;
      
    } catch (e) {
      currentOperation.value = 'Download failed';
      throw Exception('Failed to download $fileName: $e');
    }
  }

  /// Save downloaded CSV to local storage
  Future<String> saveCsvToLocal(String fileName, String csvContent) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final csvDir = Directory('${directory.path}/softagri_csv');
      
      if (!await csvDir.exists()) {
        await csvDir.create(recursive: true);
      }
      
      final file = File('${csvDir.path}/$fileName');
      await file.writeAsString(csvContent);
      
      return file.path;
    } catch (e) {
      throw Exception('Failed to save $fileName locally: $e');
    }
  }

  /// Save all downloaded CSVs to local storage
  Future<Map<String, String>> saveAllCsvsToLocal() async {
    final Map<String, String> savedPaths = {};
    
    for (final entry in downloadedFiles.entries) {
      final localPath = await saveCsvToLocal(entry.key, entry.value);
      savedPaths[entry.key] = localPath;
    }
    
    return savedPaths;
  }

  /// Parse CSV content into List of Maps
  List<Map<String, dynamic>> parseCsvContent(String csvContent) {
    try {
      final List<List<dynamic>> csvData = const CsvToListConverter().convert(csvContent);
      
      if (csvData.isEmpty) return [];
      
      final headers = csvData.first.map((e) => e.toString()).toList();
      final List<Map<String, dynamic>> result = [];
      
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        final Map<String, dynamic> rowMap = {};
        
        for (int j = 0; j < headers.length && j < row.length; j++) {
          rowMap[headers[j]] = row[j];
        }
        
        result.add(rowMap);
      }
      
      return result;
    } catch (e) {
      throw Exception('Failed to parse CSV content: $e');
    }
  }

  /// Get parsed data for a specific CSV file
  List<Map<String, dynamic>>? getParsedCsv(String fileName) {
    final csvContent = downloadedFiles[fileName];
    if (csvContent == null) return null;
    
    return parseCsvContent(csvContent);
  }

  /// Get file information for all CSV files without downloading
  Future<Map<String, Map<String, dynamic>>> getCsvFilesInfo() async {
    if (!_authController.isSignedIn) {
      throw Exception('Please sign in with Google to access CSV files');
    }

    try {
      final csvFolderId = await findSoftagriCsvFolderId();
      final Map<String, Map<String, dynamic>> filesInfo = {};

      for (final fileName in requiredCsvFiles) {
        try {
          final fileInfo = await _driveService.getFileInfo(fileName, csvFolderId);
          if (fileInfo != null) {
            filesInfo[fileName] = fileInfo;
          }
        } catch (e) {
          print('Warning: Could not get info for $fileName: $e');
        }
      }

      return filesInfo;
    } catch (e) {
      throw Exception('Failed to get CSV files info: $e');
    }
  }

  /// Check if user has access to the required folder structure
  Future<bool> checkFolderAccess() async {
    if (!_authController.isSignedIn) {
      return false;
    }

    try {
      await findSoftagriCsvFolderId();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear downloaded data
  void clearDownloadedData() {
    downloadedFiles.clear();
    downloadProgress.clear();
    currentOperation.value = '';
  }

  /// Get download statistics
  Map<String, dynamic> getDownloadStats() {
    final total = requiredCsvFiles.length;
    final downloaded = downloadedFiles.length;
    final failed = downloadProgress.values.where((progress) => progress == 0.0).length;
    
    return {
      'totalFiles': total,
      'downloadedFiles': downloaded,
      'failedFiles': failed,
      'successRate': total > 0 ? (downloaded / total * 100).toStringAsFixed(1) : '0.0',
      'downloadedFileNames': downloadedFiles.keys.toList(),
    };
  }
}