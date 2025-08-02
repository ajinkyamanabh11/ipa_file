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

  CsvFileInfo({
    required this.id,
    required this.name,
    this.size,
    this.modifiedTime,
    this.content,
    this.isDownloaded = false,
  });

  CsvFileInfo copyWith({
    String? id,
    String? name,
    String? size,
    DateTime? modifiedTime,
    String? content,
    bool? isDownloaded,
  }) {
    return CsvFileInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      modifiedTime: modifiedTime ?? this.modifiedTime,
      content: content ?? this.content,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }
}
class AutomatedCsvService extends GetxService {
  final GoogleDriveService _driveService = Get.find<GoogleDriveService>();
  final FilePickerService _filePickerService = Get.find<FilePickerService>();



  /// Search for all CSV files in the Softagri_Backups,Financialyear_csv folder
  Future<List<CsvFileInfo>> searchCsvFiles() async {
    log('🔍 AutomatedCsvService: Starting CSV file search...');
    
    // Try both Softagri_Backups and Financialyear_csv paths
    List<CsvFileInfo> csvFileInfos = [];
    
    // First try Softagri_Backups path
    try {
      csvFileInfos.addAll(await _searchInSoftagriBackups());
    } catch (e) {
      log('⚠️ AutomatedCsvService: Error searching Softagri_Backups: $e');
    }
    
    // Then try Financialyear_csv path  
    try {
      csvFileInfos.addAll(await _searchInFinancialYearCsv());
    } catch (e) {
      log('⚠️ AutomatedCsvService: Error searching Financialyear_csv: $e');
    }
    
    // Remove duplicates based on file ID
    final uniqueFiles = <String, CsvFileInfo>{};
    for (final file in csvFileInfos) {
      uniqueFiles[file.id] = file;
    }
    
    final finalFiles = uniqueFiles.values.toList();
    log('✅ AutomatedCsvService: Total unique CSV files found: ${finalFiles.length}');
    return finalFiles;
  }
  
  /// Search in Softagri_Backups with fallback year directories
  Future<List<CsvFileInfo>> _searchInSoftagriBackups() async {
    final currentYear = DateTime.now().year;
    final fallbackYears = [
      '${currentYear}${currentYear + 1}',   // 20252026
      '${currentYear + 1}${currentYear + 2}', // 20262027  
      '${currentYear + 2}${currentYear + 3}', // 20272028
      '${currentYear - 1}${currentYear}',     // 20242025 (previous year)
    ];
    
    // First try to get the year from SoftAgriPath (which reads from FinancialYear.csv)
    List<String> pathSegments;
    try {
      pathSegments = await SoftAgriPath.build(_driveService);
      log('📁 AutomatedCsvService: Softagri_Backups path: ${pathSegments.join('/')}');
      return await _searchCsvInPath(pathSegments);
    } catch (e) {
      log('⚠️ AutomatedCsvService: Primary path failed, trying fallback paths: $e');
    }
    
    // If primary path fails, try fallback years
    for (final year in fallbackYears) {
      final fallbackPath = ['Softagri_Backups', year, 'softagri_csv'];
      try {
        log('📁 AutomatedCsvService: Trying fallback path: ${fallbackPath.join('/')}');
        return await _searchCsvInPath(fallbackPath);
      } catch (e) {
        log('⚠️ AutomatedCsvService: Fallback path failed: ${fallbackPath.join('/')} - $e');
      }
    }
    
    throw Exception('All Softagri_Backups paths failed: Exception: Folder not found: Softagri_Backups');
  }
  
  /// Search in Financialyear_csv folder
  Future<List<CsvFileInfo>> _searchInFinancialYearCsv() async {
    final pathSegments = ['Financialyear_csv'];
    log('📁 AutomatedCsvService: Searching in Financialyear_csv');
    return await _searchCsvInPath(pathSegments);
  }
  
  /// Search for CSV files in the specified path
  Future<List<CsvFileInfo>> _searchCsvInPath(List<String> pathSegments) async {
    // Get the folder ID for the target path
    final folderId = await _driveService.folderId(pathSegments);
    log('📂 AutomatedCsvService: Found folder ID: $folderId for path: ${pathSegments.join('/')}');

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
        ))
        .toList();

    log('✅ AutomatedCsvService: Found ${csvFileInfos.length} CSV files in ${pathSegments.join('/')}');
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
  log('📥 AutomatedCsvService: Downloading ${file.name} (${i + 1}/${csvFiles.length})');

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
  log('📥 AutomatedCsvService: Downloading specific file: ${fileInfo.name}');

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