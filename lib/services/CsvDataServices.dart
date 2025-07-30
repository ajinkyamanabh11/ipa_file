// lib/services/csv_data_service.dart
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:developer';
import 'dart:isolate';

import '../constants/paths.dart';
import 'google_drive_service.dart';
import 'background_processor.dart';
import 'package:flutter/foundation.dart'; // for compute
import '../util/csv_worker.dart'; // your new isolate parser

class CsvDataService extends GetxController {
  final GoogleDriveService drive = Get.find<GoogleDriveService>();
  final BackgroundProcessor _backgroundProcessor = Get.find<BackgroundProcessor>();
  final GetStorage _box = GetStorage();
  Future<void>? _loadingFuture;
  bool _hasDownloadedOnce = false;

  static const String _salesMasterCacheKey = 'salesMasterCsv';
  static const String _salesDetailsCacheKey = 'salesDetailsCsv';
  static const String _itemMasterCacheKey = 'itemMasterCsv';
  static const String _itemDetailCacheKey = 'itemDetailCsv';

  static const String _accountMasterCacheKey = 'accountMasterCsv';
  static const String _allAccountsCacheKey = 'allAccountsCsv';
  static const String _customerInfoCacheKey = 'customerInfoCsv';
  static const String _supplierInfoCacheKey = 'supplierInfoCsv';

  static const String _lastCsvSyncTimestampKey = 'lastCsvSync';

  // Extended cache duration to prevent frequent re-downloads
  static const Duration _cacheDuration = Duration(hours: 6); // 6 hours cache

  // Memory management constants
  static const int _maxMemoryUsageMB = 150; // Increased max memory for better performance
  static const int _chunkSize = 2000; // Larger chunks for better performance

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
  final RxBool isLoading = false.obs;
  final RxDouble loadingProgress = 0.0.obs;

  // Cache validation tracking
  final Map<String, DateTime> _lastAccessTime = {};
  final Map<String, bool> _dataValidationCache = {};

  @override
  void onInit() {
    super.onInit();
    _startMemoryMonitoring();
    _loadFromCacheOnInit();
  }

  /// Load data from cache on initialization if available
  void _loadFromCacheOnInit() {
    final lastSync = _box.read<int?>(_lastCsvSyncTimestampKey);
    if (lastSync != null) {
      final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);
      final isCacheValid = DateTime.now().difference(lastSyncTime) < _cacheDuration;
      
      if (isCacheValid) {
        log('📦 CsvDataService: Loading cached data on initialization');
        _loadFromCache();
        _hasDownloadedOnce = true;
      }
    }
  }

  /// Load all data from cache
  void _loadFromCache() {
    final csvConfigs = [
      {'key': _salesMasterCacheKey},
      {'key': _salesDetailsCacheKey},
      {'key': _itemMasterCacheKey},
      {'key': _itemDetailCacheKey},
      {'key': _accountMasterCacheKey},
      {'key': _allAccountsCacheKey},
      {'key': _customerInfoCacheKey},
      {'key': _supplierInfoCacheKey},
    ];

    for (final config in csvConfigs) {
      final cached = _box.read(config['key']);
      if (cached != null && cached.isNotEmpty) {
        _populateReactiveVarFromCache(config['key'], cached);
      }
    }
    
    getCurrentMemoryUsageMB(); // Update memory usage
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
    // Clear non-essential cached data based on access time
    final now = DateTime.now();
    final cutoffTime = now.subtract(Duration(minutes: 30));

    // Clear least recently used data
    if (_lastAccessTime[_accountMasterCacheKey]?.isBefore(cutoffTime) ?? true) {
      accountMasterCsv.value = '';
      log('🧹 CsvDataService: Cleared accountMasterCsv from memory');
    }
    if (_lastAccessTime[_allAccountsCacheKey]?.isBefore(cutoffTime) ?? true) {
      allAccountsCsv.value = '';
      log('🧹 CsvDataService: Cleared allAccountsCsv from memory');
    }
    if (_lastAccessTime[_customerInfoCacheKey]?.isBefore(cutoffTime) ?? true) {
      customerInfoCsv.value = '';
      log('🧹 CsvDataService: Cleared customerInfoCsv from memory');
    }
    if (_lastAccessTime[_supplierInfoCacheKey]?.isBefore(cutoffTime) ?? true) {
      supplierInfoCsv.value = '';
      log('🧹 CsvDataService: Cleared supplierInfoCsv from memory');
    }

    // Clear parsed cache
    clearParsedCache();

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
    log('🔄 CsvDataService: loadAllCsvs called (forceDownload: $forceDownload)');

    // Skip reloading if we've already downloaded and no force is required
    if (!forceDownload && _hasDownloadedOnce && _hasValidCachedData()) {
      log('⏭️ CsvDataService: Skipping loadAllCsvs – already loaded with valid cache.');
      return;
    }

    // If another load is in progress
    if (_loadingFuture != null) {
      if (forceDownload) {
        log('⚠️ CsvDataService: Force download requested — waiting for current load to finish, then restarting...');
        try {
          await _loadingFuture;
        } catch (_) {
          // Swallow errors from previous future
        }
        // Clear and re-run
        _loadingFuture = null;
      } else {
        log('⏳ CsvDataService: loadAllCsvs already in progress – awaiting existing future...');
        return _loadingFuture!;
      }
    }

    log('🚀 CsvDataService: Starting CSV loading (forceDownload: $forceDownload)...');
    isLoading.value = true;
    loadingProgress.value = 0.0;
    
    _loadingFuture = _loadCsvsInternal(forceDownload: forceDownload);
    await _loadingFuture;
    _loadingFuture = null;
    _hasDownloadedOnce = true;
    isLoading.value = false;
    loadingProgress.value = 1.0;
  }

  /// Check if we have valid cached data for essential CSVs
  bool _hasValidCachedData() {
    final essentialKeys = [_salesMasterCacheKey, _salesDetailsCacheKey, _itemMasterCacheKey, _itemDetailCacheKey];
    
    for (final key in essentialKeys) {
      final cached = _box.read(key);
      if (cached == null || cached.isEmpty) {
        return false;
      }
    }
    
    final lastSync = _box.read<int?>(_lastCsvSyncTimestampKey);
    if (lastSync == null) return false;
    
    final isCacheValid = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastSync)
    ) < _cacheDuration;
    
    return isCacheValid;
  }

  Future<void> _loadCsvsInternal({required bool forceDownload}) async {
    final lastSync = _box.read<int?>(_lastCsvSyncTimestampKey);
    final isCacheValid = lastSync != null &&
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastSync)) < _cacheDuration;

    final List<Map<String, dynamic>> csvConfigs = [
      {'key': _salesMasterCacheKey, 'filename': 'SalesInvoiceMaster.csv', 'priority': 1},
      {'key': _salesDetailsCacheKey, 'filename': 'SalesInvoiceDetails.csv', 'priority': 1},
      {'key': _itemMasterCacheKey, 'filename': 'ItemMaster.csv', 'priority': 1},
      {'key': _itemDetailCacheKey, 'filename': 'ItemDetail.csv', 'priority': 1},
      {'key': _accountMasterCacheKey, 'filename': 'AccountMaster.csv', 'priority': 2},
      {'key': _allAccountsCacheKey, 'filename': 'AllAccounts.csv', 'priority': 2},
      {'key': _customerInfoCacheKey, 'filename': 'CustomerInformation.csv', 'priority': 2},
      {'key': _supplierInfoCacheKey, 'filename': 'SupplierInformation.csv', 'priority': 2},
    ];

    bool needsDownload = forceDownload;
    if (!forceDownload) {
      if (!isCacheValid) {
        log('💡 CsvDataService: Cache expired. Will download.');
        needsDownload = true;
      } else {
        for (final config in csvConfigs.where((c) => c['priority'] == 1)) {
          final cached = _box.read(config['key']);
          if (cached == null || cached.isEmpty) {
            log('⚠️ CsvDataService: Missing essential cache for key: ${config['key']}');
            needsDownload = true;
            break;
          }
        }

        if (!needsDownload) {
          log('✅ CsvDataService: Loading CSVs from cache.');
          _loadFromCache();
          return;
        }
      }
    }

    if (needsDownload) {
      try {
        final path = await SoftAgriPath.build(drive);
        final folderId = await drive.folderId(path);
        await _downloadCsvsWithMemoryManagement(csvConfigs, folderId);
        await _box.write(_lastCsvSyncTimestampKey, DateTime.now().millisecondsSinceEpoch);
        log('📦 CsvDataService: All CSVs downloaded and cached.');
      } catch (e, st) {
        log('❌ CsvDataService: Error in _loadCsvsInternal: $e\n$st');
        _clearAllReactiveVars();
        rethrow; // Re-throw to let controllers handle the error
      }
    }
  }

  /// Download CSVs with memory management and priority-based loading
  Future<void> _downloadCsvsWithMemoryManagement(
      List<Map<String, dynamic>> csvConfigs,
      String folderId,
      ) async {
    csvConfigs.sort((a, b) => a['priority'].compareTo(b['priority']));

    int processedCount = 0;
    final totalCount = csvConfigs.length;

    for (final config in csvConfigs) {
      try {
        // Update progress
        loadingProgress.value = processedCount / totalCount;
        
        // Skip non-essential files if memory is high
        if (memoryUsageMB.value > _maxMemoryUsageMB * 0.8 && config['priority'] > 1) {
          log('⚠️ CsvDataService: Skipping ${config['filename']} due to memory constraints');
          processedCount++;
          continue;
        }

        log('📥 CsvDataService: Downloading ${config['filename']}...');
        
        final fileId = await drive.fileId(config['filename'], folderId);
        
        // Check file size before downloading
        final fileSize = await drive.getFileSize(fileId);
        final fileSizeMB = fileSize / (1024 * 1024);
        
        if (fileSizeMB > 50) { // 50MB limit per file
          log('⚠️ CsvDataService: File ${config['filename']} is too large (${fileSizeMB.toStringAsFixed(1)}MB). Skipping.');
          processedCount++;
          continue;
        }
        
        final csvData = await drive.downloadCsvWithProgress(fileId, onProgress: (progress) {
          final overallProgress = (processedCount + progress) / totalCount;
          loadingProgress.value = overallProgress;
        });

        final String key = config['key'];
        final String parsedCsv = csvData; // Store raw CSV for now
        final double estimatedSize = (csvData.length * 2) / (1024 * 1024);

        memoryUsageMB.value += estimatedSize;
        _populateReactiveVarFromCache(key, parsedCsv);
        await _box.write(key, parsedCsv);

        log('📥 CsvDataService: Downloaded $key (${estimatedSize.toStringAsFixed(1)}MB)');

        // Allow UI updates and garbage collection
        await Future.delayed(Duration(milliseconds: 100));
        
        processedCount++;

      } catch (e, st) {
        log('❌ CsvDataService: Failed to download ${config['filename']}: $e\n$st');
        processedCount++;
        continue;
      }
    }
    
    loadingProgress.value = 1.0;
  }

  void _populateReactiveVarFromCache(String key, String? cachedData) {
    if (cachedData == null || cachedData.isEmpty) return;

    // Track access time for memory management
    _lastAccessTime[key] = DateTime.now();

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
    _lastAccessTime.clear();
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
    clearParsedCache();
    _hasDownloadedOnce = false;
    log('🗑️ CsvDataService: All CSV cache cleared.');
  }

  /// Parse CSV data on-demand using background processor
  Future<List<Map<String, dynamic>>> parseCsvData(String csvKey, {String? taskName}) async {
    String csvData = '';

    // Track access for memory management
    _lastAccessTime[csvKey] = DateTime.now();

    switch (csvKey) {
      case _salesMasterCacheKey: 
        csvData = salesMasterCsv.value;
        if (csvData.isEmpty) {
          final cached = _box.read(csvKey);
          if (cached != null && cached.isNotEmpty) {
            salesMasterCsv.value = cached;
            csvData = cached;
          }
        }
        break;
      case _salesDetailsCacheKey: 
        csvData = salesDetailsCsv.value;
        if (csvData.isEmpty) {
          final cached = _box.read(csvKey);
          if (cached != null && cached.isNotEmpty) {
            salesDetailsCsv.value = cached;
            csvData = cached;
          }
        }
        break;
      case _itemMasterCacheKey: 
        csvData = itemMasterCsv.value;
        if (csvData.isEmpty) {
          final cached = _box.read(csvKey);
          if (cached != null && cached.isNotEmpty) {
            itemMasterCsv.value = cached;
            csvData = cached;
          }
        }
        break;
      case _itemDetailCacheKey: 
        csvData = itemDetailCsv.value;
        if (csvData.isEmpty) {
          final cached = _box.read(csvKey);
          if (cached != null && cached.isNotEmpty) {
            itemDetailCsv.value = cached;
            csvData = cached;
          }
        }
        break;
      case _accountMasterCacheKey: 
        csvData = accountMasterCsv.value;
        if (csvData.isEmpty) {
          final cached = _box.read(csvKey);
          if (cached != null && cached.isNotEmpty) {
            accountMasterCsv.value = cached;
            csvData = cached;
          }
        }
        break;
      case _allAccountsCacheKey: 
        csvData = allAccountsCsv.value;
        if (csvData.isEmpty) {
          final cached = _box.read(csvKey);
          if (cached != null && cached.isNotEmpty) {
            allAccountsCsv.value = cached;
            csvData = cached;
          }
        }
        break;
      case _customerInfoCacheKey: 
        csvData = customerInfoCsv.value;
        if (csvData.isEmpty) {
          final cached = _box.read(csvKey);
          if (cached != null && cached.isNotEmpty) {
            customerInfoCsv.value = cached;
            csvData = cached;
          }
        }
        break;
      case _supplierInfoCacheKey: 
        csvData = supplierInfoCsv.value;
        if (csvData.isEmpty) {
          final cached = _box.read(csvKey);
          if (cached != null && cached.isNotEmpty) {
            supplierInfoCsv.value = cached;
            csvData = cached;
          }
        }
        break;
    }

    if (csvData.isEmpty) {
      log('⚠️ CsvDataService: No CSV data found for key: $csvKey');
      return [];
    }

    return await _backgroundProcessor.processCsvData(
      csvData: csvData,
      taskName: taskName ?? 'Parsing $csvKey',
      shouldParse: true,
      onProgress: (progress) {
        log('📊 CsvDataService: Parsing $csvKey - ${(progress * 100).toStringAsFixed(1)}%');
      },
    );
  }

  /// Get parsed data with caching to avoid re-parsing
  final Map<String, List<Map<String, dynamic>>> _parsedDataCache = {};
  final Map<String, DateTime> _parsedCacheTime = {};

  Future<List<Map<String, dynamic>>> getCachedParsedData(String csvKey) async {
    // Check if cached parsed data is still valid (30 minutes)
    final cacheTime = _parsedCacheTime[csvKey];
    final isExpired = cacheTime == null || 
        DateTime.now().difference(cacheTime) > Duration(minutes: 30);

    if (_parsedDataCache.containsKey(csvKey) && !isExpired) {
      return _parsedDataCache[csvKey]!;
    }

    final parsed = await parseCsvData(csvKey);
    _parsedDataCache[csvKey] = parsed;
    _parsedCacheTime[csvKey] = DateTime.now();
    return parsed;
  }

  /// Clear parsed data cache to free memory
  void clearParsedCache() {
    _parsedDataCache.clear();
    _parsedCacheTime.clear();
    log('🧹 CsvDataService: Cleared parsed data cache');
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

    // Add parsed cache size
    for (final entry in _parsedDataCache.entries) {
      totalSize += (entry.value.length * 0.5) / 1024; // Rough estimate for parsed data
    }

    memoryUsageMB.value = totalSize;
    return totalSize;
  }

  /// Check data availability without loading
  bool hasData(String csvKey) {
    switch (csvKey) {
      case _salesMasterCacheKey: return salesMasterCsv.value.isNotEmpty;
      case _salesDetailsCacheKey: return salesDetailsCsv.value.isNotEmpty;
      case _itemMasterCacheKey: return itemMasterCsv.value.isNotEmpty;
      case _itemDetailCacheKey: return itemDetailCsv.value.isNotEmpty;
      case _accountMasterCacheKey: return accountMasterCsv.value.isNotEmpty;
      case _allAccountsCacheKey: return allAccountsCsv.value.isNotEmpty;
      case _customerInfoCacheKey: return customerInfoCsv.value.isNotEmpty;
      case _supplierInfoCacheKey: return supplierInfoCsv.value.isNotEmpty;
      default: return false;
    }
  }

  /// Force refresh specific data
  Future<void> refreshSpecificData(List<String> csvKeys) async {
    // Clear specific cached data
    for (final key in csvKeys) {
      await _box.remove(key);
      _parsedDataCache.remove(key);
      _parsedCacheTime.remove(key);
    }
    
    // Reload all data
    await loadAllCsvs(forceDownload: true);
  }
}