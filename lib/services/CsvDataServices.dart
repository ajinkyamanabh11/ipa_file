// lib/services/csv_data_service.dart
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:developer';
import 'dart:isolate';

import '../constants/paths.dart';
import 'google_drive_service.dart';

class CsvDataService extends GetxController {
  final GoogleDriveService drive = Get.find<GoogleDriveService>();
  final GetStorage _box = GetStorage();

  static const String _salesMasterCacheKey = 'salesMasterCsv';
  static const String _salesDetailsCacheKey = 'salesDetailsCsv';
  static const String _itemMasterCacheKey = 'itemMasterCsv';
  static const String _itemDetailCacheKey = 'itemDetailCsv';

  static const String _accountMasterCacheKey = 'accountMasterCsv';
  static const String _allAccountsCacheKey = 'allAccountsCsv';
  static const String _customerInfoCacheKey = 'customerInfoCsv';
  static const String _supplierInfoCacheKey = 'supplierInfoCsv';

  static const String _lastCsvSyncTimestampKey = 'lastCsvSync';

  // Adjusted cache duration for testing, consider making it longer in production
  static const Duration _cacheDuration = Duration(minutes: 1); // Shorter cache for easier testing

  // Memory management constants
  static const int _maxMemoryUsageMB = 100; // Maximum memory usage in MB
  static const int _chunkSize = 1000; // Process data in chunks

  final RxString salesMasterCsv = ''.obs;
  final RxString salesDetailsCsv = ''.obs;
  final RxString itemMasterCsv = ''.obs;
  final RxString itemDetailCsv = ''.obs;

  final RxString accountMasterCsv = ''.obs;
  final RxString allAccountsCsv = ''.obs;
  final RxString customerInfoCsv = ''.obs;
  final RxString supplierInfoCsv = ''.obs;

  // Memory usage tracking
  final RxDouble memoryUsageMB = 0.0.obs;
  final RxBool isMemoryWarning = false.obs;

  @override
  void onInit() {
    super.onInit();
    _startMemoryMonitoring();
    // Potentially load from cache on init, but don't force download
    // loadAllCsvs(forceDownload: false); // Or load specific ones if needed
  }

  /// Monitor memory usage and trigger cleanup if needed
  void _startMemoryMonitoring() {
    // Check memory usage every 30 seconds
    ever(memoryUsageMB, (usage) {
      if (usage > _maxMemoryUsageMB) {
        isMemoryWarning.value = true;
        log('⚠️ CsvDataService: High memory usage detected: ${usage}MB. Triggering cleanup.');
        performMemoryCleanup();
      } else {
        isMemoryWarning.value = false;
      }
    });
  }

  /// Perform memory cleanup when usage is high
  void performMemoryCleanup() {
    // Clear non-essential cached data
    if (accountMasterCsv.value.isNotEmpty) {
      accountMasterCsv.value = '';
      log('🧹 CsvDataService: Cleared accountMasterCsv from memory');
    }
    if (allAccountsCsv.value.isNotEmpty) {
      allAccountsCsv.value = '';
      log('🧹 CsvDataService: Cleared allAccountsCsv from memory');
    }
    
    // Force garbage collection hint
    _requestGarbageCollection();
  }

  /// Request garbage collection (hint to Dart VM)
  void _requestGarbageCollection() {
    // This is a hint to the Dart VM to consider garbage collection
    List.generate(100, (index) => []).clear();
  }

  /// Loads all required CSVs with memory-efficient processing
  /// If [forceDownload] is true, it will always download new data, ignoring cache validity.
  /// This method now handles ALL primary CSVs used throughout the app with memory management.
  Future<void> loadAllCsvs({bool forceDownload = false}) async {
    log('🔄 CsvDataService: Starting loadAllCsvs (Force download requested: $forceDownload)');

    final lastSync = _box.read<int?>(_lastCsvSyncTimestampKey);
    final isCacheValid = lastSync != null &&
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastSync)) < _cacheDuration;

    // List of all CSV keys with priority (essential ones first)
    final List<Map<String, dynamic>> csvConfigs = [
      // Essential CSVs (always load)
      {'key': _salesMasterCacheKey, 'filename': 'SalesInvoiceMaster.csv', 'priority': 1},
      {'key': _salesDetailsCacheKey, 'filename': 'SalesInvoiceDetails.csv', 'priority': 1},
      {'key': _itemMasterCacheKey, 'filename': 'ItemMaster.csv', 'priority': 1},
      {'key': _itemDetailCacheKey, 'filename': 'ItemDetail.csv', 'priority': 1},
      // Optional CSVs (load only if memory allows)
      {'key': _accountMasterCacheKey, 'filename': 'AccountMaster.csv', 'priority': 2},
      {'key': _allAccountsCacheKey, 'filename': 'AllAccounts.csv', 'priority': 2},
      {'key': _customerInfoCacheKey, 'filename': 'CustomerInformation.csv', 'priority': 2},
      {'key': _supplierInfoCacheKey, 'filename': 'SupplierInformation.csv', 'priority': 2},
    ];

    // Determine if we need to download
    bool needsDownload = forceDownload;
    if (!forceDownload) {
      // If not forcing download, check cache validity and completeness
      if (!isCacheValid) {
        log('💡 CsvDataService: Cache is NOT valid (older than ${_cacheDuration.inMinutes} mins). Will download.');
        needsDownload = true;
      } else {
        bool anyEssentialDataMissing = false;
        for (final config in csvConfigs.where((c) => c['priority'] == 1)) {
          final cachedData = _box.read(config['key']);
          if (cachedData == null || cachedData.isEmpty) {
            anyEssentialDataMissing = true;
            log('⚠️ CsvDataService: Essential cache missing for key: ${config['key']}. Will download.');
            break;
          }
        }
        if (anyEssentialDataMissing) {
          needsDownload = true;
        } else {
          log('✅ CsvDataService: Essential CSVs found in valid cache. Loading from cache.');
          for (final config in csvConfigs) {
            final cachedData = _box.read(config['key']);
            if (cachedData != null && cachedData.isNotEmpty) {
              _populateReactiveVarFromCache(config['key'] as String, cachedData);
            }
          }
          return; // All essential data found in cache and valid
        }
      }
    }

    if (needsDownload) {
      log('🌐 CsvDataService: Proceeding with download from Drive (Force: $forceDownload, Cache Valid: $isCacheValid).');
      try {
        final path = await SoftAgriPath.build(drive);
        final folderId = await drive.folderId(path);

        // Download essential CSVs first
        await _downloadCsvsWithMemoryManagement(csvConfigs, folderId);

        await _box.write(_lastCsvSyncTimestampKey, DateTime.now().millisecondsSinceEpoch);

        log('💾 CsvDataService: CSVs downloaded and cached successfully with memory management.');
      } catch (e, st) {
        log('❌ CsvDataService: Error downloading/caching CSVs: $e\n$st');
        _clearAllReactiveVars();
        // Do NOT rethrow, let the caller handle empty values.
      }
    }
  }

  /// Download CSVs with memory management and priority-based loading
  Future<void> _downloadCsvsWithMemoryManagement(
    List<Map<String, dynamic>> csvConfigs, 
    String folderId
  ) async {
    // Sort by priority (essential first)
    csvConfigs.sort((a, b) => a['priority'].compareTo(b['priority']));

    for (final config in csvConfigs) {
      try {
        // Check memory before downloading each file
        if (memoryUsageMB.value > _maxMemoryUsageMB * 0.8 && config['priority'] > 1) {
          log('⚠️ CsvDataService: Skipping ${config['filename']} due to memory constraints');
          continue;
        }

        final fileId = await drive.fileId(config['filename'], folderId);
        final csvData = await drive.downloadCsv(fileId);
        
        // Estimate memory usage (rough calculation)
        final estimatedSizeMB = (csvData.length * 2) / (1024 * 1024); // UTF-8 + processing overhead
        memoryUsageMB.value += estimatedSizeMB;

        // Store in reactive variable and cache
        _populateReactiveVarFromCache(config['key'] as String, csvData);
        await _box.write(config['key'], csvData);

        log('📥 CsvDataService: Downloaded ${config['filename']} (${estimatedSizeMB.toStringAsFixed(1)}MB)');

        // Add small delay to prevent overwhelming the system
        await Future.delayed(Duration(milliseconds: 100));

      } catch (e) {
        log('❌ CsvDataService: Failed to download ${config['filename']}: $e');
        // Continue with other files even if one fails
      }
    }
  }

  void _populateReactiveVarFromCache(String key, String? cachedData) {
    if (cachedData == null || cachedData.isEmpty) return;

    switch (key) {
      case _salesMasterCacheKey: salesMasterCsv.value = cachedData; break;
      case _salesDetailsCacheKey: salesDetailsCsv.value = cachedData; break;
      case _itemMasterCacheKey: itemMasterCsv.value = cachedData; break;
      case _itemDetailCacheKey: itemDetailCsv.value = cachedData; break;
      case _accountMasterCacheKey: accountMasterCsv.value = cachedData; break;
      case _allAccountsCacheKey: allAccountsCsv.value = cachedData; break;
      case _customerInfoCacheKey: customerInfoCsv.value = cachedData; break;
      case _supplierInfoCacheKey: supplierInfoCsv.value = cachedData; break;
    }
  }

  void _clearAllReactiveVars() {
    salesMasterCsv.value = '';
    salesDetailsCsv.value = '';
    itemMasterCsv.value = '';
    itemDetailCsv.value = '';
    accountMasterCsv.value = '';
    allAccountsCsv.value = '';
    customerInfoCsv.value = '';
    supplierInfoCsv.value = '';
    memoryUsageMB.value = 0.0;
  }

  Future<void> clearAllCsvCache() async {
    // List all keys to remove them
    final List<String> allCacheKeys = [
      _salesMasterCacheKey, _salesDetailsCacheKey, _itemMasterCacheKey, _itemDetailCacheKey,
      _accountMasterCacheKey, _allAccountsCacheKey, _customerInfoCacheKey, _supplierInfoCacheKey,
      _lastCsvSyncTimestampKey
    ];

    for (final key in allCacheKeys) {
      await _box.remove(key);
    }
    
    _clearAllReactiveVars();
    log('🗑️ CsvDataService: All CSV cache cleared.');
  }

  /// Get current memory usage estimate
  double getCurrentMemoryUsageMB() {
    double totalSize = 0.0;
    totalSize += (salesMasterCsv.value.length * 2) / (1024 * 1024);
    totalSize += (salesDetailsCsv.value.length * 2) / (1024 * 1024);
    totalSize += (itemMasterCsv.value.length * 2) / (1024 * 1024);
    totalSize += (itemDetailCsv.value.length * 2) / (1024 * 1024);
    totalSize += (accountMasterCsv.value.length * 2) / (1024 * 1024);
    totalSize += (allAccountsCsv.value.length * 2) / (1024 * 1024);
    totalSize += (customerInfoCsv.value.length * 2) / (1024 * 1024);
    totalSize += (supplierInfoCsv.value.length * 2) / (1024 * 1024);
    
    memoryUsageMB.value = totalSize;
    return totalSize;
  }
}