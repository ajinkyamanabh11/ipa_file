import 'dart:developer';
import 'package:get/get.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../constants/paths.dart';
import 'google_drive_service.dart';
import 'file_picker_service.dart';
class CsvFileInfo {
  final String id;
  final String name;
  final String? size;
  final DateTime? modifiedTime;
  final String? content;
  final bool isDownloaded;
  final String source; // New field to track source directory

  CsvFileInfo({
    required this.id,
    required this.name,
    this.size,
    this.modifiedTime,
    this.content,
    this.isDownloaded = false,
    this.source = 'Unknown',
  });

  CsvFileInfo copyWith({
    String? id,
    String? name,
    String? size,
    DateTime? modifiedTime,
    String? content,
    bool? isDownloaded,
    String? source,
  }) {
    return CsvFileInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      modifiedTime: modifiedTime ?? this.modifiedTime,
      content: content ?? this.content,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      source: source ?? this.source,
    );
  }
}
/// Enhanced service for automatically discovering and managing CSV files
/// from multiple Google Drive directories:
/// 1. Softagri_Backups/<year>/<year+1>/softagri_csv (dynamic year detection)
/// 2. Financialyear_csv (static directory)
/// 
/// Features:
/// - Dual directory search with fallback mechanisms
/// - Automatic year detection from FinancialYear.csv
/// - Source tracking for each discovered file
/// - Duplicate file handling
class AutomatedCsvService extends GetxService {
  final GoogleDriveService _driveService = Get.find<GoogleDriveService>();
  final FilePickerService _filePickerService = Get.find<FilePickerService>();



  /// Search for all CSV files in both Softagri_Backups and Financialyear_csv folders
  Future<List<CsvFileInfo>> searchCsvFiles() async {
  try {
  log('🔍 AutomatedCsvService: Starting comprehensive CSV file search...');
  
  final allCsvFiles = <CsvFileInfo>[];
  
  // Search in Softagri_Backups path
  try {
    final softagriFiles = await _searchInSoftagriBackups();
    allCsvFiles.addAll(softagriFiles);
    log('📁 AutomatedCsvService: Found ${softagriFiles.length} files in Softagri_Backups');
  } catch (e) {
    log('⚠️ AutomatedCsvService: Error searching Softagri_Backups: $e');
  }
  
  // Search in Financialyear_csv path
  try {
    final financialYearFiles = await _searchInFinancialYearCsv();
    allCsvFiles.addAll(financialYearFiles);
    log('📁 AutomatedCsvService: Found ${financialYearFiles.length} files in Financialyear_csv');
  } catch (e) {
    log('⚠️ AutomatedCsvService: Error searching Financialyear_csv: $e');
  }

  // Remove duplicates based on file name (keep the first occurrence)
  final uniqueFiles = <String, CsvFileInfo>{};
  for (final file in allCsvFiles) {
    if (!uniqueFiles.containsKey(file.name)) {
      uniqueFiles[file.name] = file;
    }
  }
  
  final finalList = uniqueFiles.values.toList();
  log('✅ AutomatedCsvService: Total unique CSV files found: ${finalList.length}');
  return finalList;
  } catch (e) {
  log('❌ AutomatedCsvService: Error during comprehensive CSV search: $e');
  throw Exception('Failed to search CSV files: $e');
  }
  }

  /// Search CSV files in Softagri_Backups directory
  Future<List<CsvFileInfo>> _searchInSoftagriBackups() async {
    try {
      // Get the Softagri_Backups path using the existing SoftAgriPath
      final pathSegments = await SoftAgriPath.build(_driveService);
      log('📁 AutomatedCsvService: Softagri_Backups path: ${pathSegments.join('/')}');

      // Get the folder ID for the target path
      final folderId = await _driveService.folderId(pathSegments);
      log('📂 AutomatedCsvService: Softagri_Backups folder ID: $folderId');

      return await _searchCsvInFolder(folderId, 'Softagri_Backups');
    } catch (e) {
      log('⚠️ AutomatedCsvService: Primary path failed, trying fallback paths: $e');
      
      // Try fallback paths
      final possiblePaths = SoftAgriPath.getPossiblePaths();
      for (final pathSegments in possiblePaths) {
        try {
          log('📁 AutomatedCsvService: Trying fallback path: ${pathSegments.join('/')}');
          final folderId = await _driveService.folderId(pathSegments);
          log('📂 AutomatedCsvService: Found fallback folder ID: $folderId');
          return await _searchCsvInFolder(folderId, 'Softagri_Backups');
        } catch (fallbackError) {
          log('⚠️ AutomatedCsvService: Fallback path failed: ${pathSegments.join('/')} - $fallbackError');
          continue;
        }
      }
      
      throw Exception('All Softagri_Backups paths failed: $e');
    }
  }

  /// Search CSV files in Financialyear_csv directory
  Future<List<CsvFileInfo>> _searchInFinancialYearCsv() async {
    // Get the Financialyear_csv folder ID
    final folderId = await _driveService.folderId(['Financialyear_csv']);
    log('📂 AutomatedCsvService: Financialyear_csv folder ID: $folderId');

    return await _searchCsvInFolder(folderId, 'Financialyear_csv');
  }

  /// Search CSV files in a specific folder
  Future<List<CsvFileInfo>> _searchCsvInFolder(String folderId, String sourcePath) async {
    // Search for CSV files in the folder
    final csvFiles = await _filePickerService.browseGoogleDriveFiles(
      folderId: folderId,
      query: '.csv',
    );

    // Filter only CSV files and convert to CsvFileInfo
    final csvFileInfos = csvFiles
        .where((file) =>
    file.name?.toLowerCase().endsWith('.csv') == true &&
    file.mimeType?.contains('csv') == true)
        .map((file) => CsvFileInfo(
    id: file.id!,
    name: file.name!,
    size: _formatFileSize(file.size),
    modifiedTime: file.modifiedTime,
    source: sourcePath,
    ))
        .toList();

    return csvFileInfos;
  }

  /// Download all CSV files automatically
  Future<List<CsvFileInfo>> downloadAllCsvFiles() async {
  try {
  log('📥 AutomatedCsvService: Starting automatic CSV download...');

  final csvFiles = await searchCsvFiles();
  final downloadedFiles = <CsvFileInfo>[];

  for (int i = 0; i < csvFiles.length; i++) {
  final file = csvFiles[i];
  try {
  log('📥 AutomatedCsvService: Downloading ${file.name} from ${file.source} (${i + 1}/${csvFiles.length})');

  final content = await _filePickerService.downloadDriveFileToLocal(
  file.id,
  file.name,
  );

  final downloadedFile = file.copyWith(
  content: content,
  isDownloaded: true,
  );

  downloadedFiles.add(downloadedFile);
  log('✅ AutomatedCsvService: Downloaded ${file.name} (${content.length} characters)');
  } catch (e) {
  log('❌ AutomatedCsvService: Failed to download ${file.name}: $e');
  // Add file without content to show download failed
  downloadedFiles.add(file.copyWith(isDownloaded: false));
  }
  }

  log('✅ AutomatedCsvService: Download complete. ${downloadedFiles.where((f) => f.isDownloaded).length}/${downloadedFiles.length} files downloaded successfully');
  return downloadedFiles;
  } catch (e) {
  log('❌ AutomatedCsvService: Error during automatic download: $e');
  throw Exception('Failed to download CSV files: $e');
  }
  }

  /// Download a specific CSV file
  Future<CsvFileInfo> downloadSpecificCsvFile(CsvFileInfo fileInfo) async {
  try {
  log('📥 AutomatedCsvService: Downloading specific file: ${fileInfo.name} from ${fileInfo.source}');

  final content = await _filePickerService.downloadDriveFileToLocal(
  fileInfo.id,
  fileInfo.name,
  );

  final downloadedFile = fileInfo.copyWith(
  content: content,
  isDownloaded: true,
  );

  log('✅ AutomatedCsvService: Downloaded ${fileInfo.name} (${content.length} characters)');
  return downloadedFile;
  } catch (e) {
  log('❌ AutomatedCsvService: Error downloading ${fileInfo.name}: $e');
  throw Exception('Failed to download ${fileInfo.name}: $e');
  }
  }

  /// Search for CSV files with specific query
  Future<List<CsvFileInfo>> searchCsvFilesWithQuery(String query) async {
  try {
  final allFiles = await searchCsvFiles();

  if (query.isEmpty) return allFiles;

  final filteredFiles = allFiles
      .where((file) =>
      (file.name ?? '').toLowerCase().contains(query.toLowerCase()))
      .toList();

  log('🔍 AutomatedCsvService: Found ${filteredFiles.length} CSV files matching "$query"');
  return filteredFiles;
  } catch (e) {
  log('❌ AutomatedCsvService: Error searching with query "$query": $e');
  throw Exception('Failed to search CSV files with query: $e');
  }
  }

  /// Get file preview (first few lines)
  String getFilePreview(String content, {int maxLines = 5}) {
  if (content.isEmpty) return 'No content available';

  final lines = content.split('\n');
  final previewLines = lines.take(maxLines).toList();

  if (lines.length > maxLines) {
  previewLines.add('... (${lines.length - maxLines} more lines)');
  }

  return previewLines.join('\n');
  }

  /// Format file size helper
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
}