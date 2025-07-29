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
  
  // Track which CSVs have been loaded
  final Map<String, bool> _loadedCsvs = {};
  final Map<String, Future<void>?> _loadingFutures = {};
  
  bool _hasDownloadedOnce = false;

  // Public constants for CSV keys
  static const String salesMasterCacheKey = 'salesMasterCsv';
  static const String salesDetailsCacheKey = 'salesDetailsCsv';
  static const String itemMasterCacheKey = 'itemMasterCsv';
  static const String itemDetailCacheKey = 'itemDetailCsv';

  static const String accountMasterCacheKey = 'accountMasterCsv';
  static const String allAccountsCacheKey = 'allAccountsCsv';
  static const String customerInfoCacheKey = 'customerInfoCsv';
  static const String supplierInfoCacheKey = 'supplierInfoCsv';

  // Private constants for internal use
  static const String _salesMasterCacheKey = salesMasterCacheKey;
  static const String _salesDetailsCacheKey = salesDetailsCacheKey;
  static const String _itemMasterCacheKey = itemMasterCacheKey;
  static const String _itemDetailCacheKey = itemDetailCacheKey;

  static const String _accountMasterCacheKey = accountMasterCacheKey;
  static const String _allAccountsCacheKey = allAccountsCacheKey;
  static const String _customerInfoCacheKey = customerInfoCacheKey;
  static const String _supplierInfoCacheKey = supplierInfoCacheKey;

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
    // Initialize loading status for all CSVs
    _initializeCsvStatus();
  }

  void _initializeCsvStatus() {
    final csvKeys = [
      _salesMasterCacheKey,
      _salesDetailsCacheKey,
      _itemMasterCacheKey,
      _itemDetailCacheKey,
      _accountMasterCacheKey,
      _allAccountsCacheKey,
      _customerInfoCacheKey,
      _supplierInfoCacheKey,
    ];
    
    for (final key in csvKeys) {
      _loadedCsvs[key] = false;
      _loadingFutures[key] = null;
    }
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
      _loadedCsvs[_accountMasterCacheKey] = false;
      log('🧹 CsvDataService: Cleared accountMasterCsv from memory');
    }
    if (allAccountsCsv.value.isNotEmpty) {
      allAccountsCsv.value = '';
      _loadedCsvs[_allAccountsCacheKey] = false;
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

  /// Load a specific CSV on-demand
  Future<void> loadCsv(String csvKey, {bool forceDownload = false}) async {
    log('🔄 CsvDataService: loadCsv called for $csvKey (forceDownload: $forceDownload)');

    // If already loaded and not forcing download, return immediately
    if (!forceDownload && _loadedCsvs[csvKey] == true) {
      log('✅ CsvDataService: $csvKey already loaded, returning cached data');
      return;
    }

    // If already loading, wait for the existing future
    if (_loadingFutures[csvKey] != null) {
      log('⏳ CsvDataService: $csvKey already loading, awaiting existing future...');
      await _loadingFutures[csvKey];
      return;
    }

    // Start loading
    _loadingFutures[csvKey] = _loadSingleCsv(csvKey, forceDownload: forceDownload);
    await _loadingFutures[csvKey];
    _loadingFutures[csvKey] = null;
  }

  /// Load multiple CSVs on-demand
  Future<void> loadCsvs(List<String> csvKeys, {bool forceDownload = false}) async {
    log('🔄 CsvDataService: loadCsvs called for ${csvKeys.join(', ')} (forceDownload: $forceDownload)');
    
    // Filter out already loaded CSVs (unless force download)
    final csvsToLoad = csvKeys.where((key) => 
      forceDownload || _loadedCsvs[key] != true
    ).toList();
    
    if (csvsToLoad.isEmpty) {
      log('✅ CsvDataService: All requested CSVs already loaded');
      return;
    }

    // Load CSVs in parallel
    await Future.wait(
      csvsToLoad.map((key) => loadCsv(key, forceDownload: forceDownload))
    );
  }

  /// Load a single CSV file
  Future<void> _loadSingleCsv(String csvKey, {required bool forceDownload}) async {
    try {
      final csvConfig = _getCsvConfig(csvKey);
      if (csvConfig == null) {
        log('❌ CsvDataService: Unknown CSV key: $csvKey');
        return;
      }

      final lastSync = _box.read<int?>(_lastCsvSyncTimestampKey);
      final isCacheValid = lastSync != null &&
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastSync)) < _cacheDuration;

      bool needsDownload = forceDownload;
      
      if (!forceDownload) {
        if (!isCacheValid) {
          log('💡 CsvDataService: Cache expired for $csvKey. Will download.');
          needsDownload = true;
        } else {
          final cached = _box.read(csvKey);
          if (cached == null || cached.isEmpty) {
            log('⚠️ CsvDataService: Missing cache for key: $csvKey');
            needsDownload = true;
          } else {
            log('✅ CsvDataService: Loading $csvKey from cache.');
            _populateReactiveVarFromCache(csvKey, cached);
            _loadedCsvs[csvKey] = true;
            return;
          }
        }
      }

      if (needsDownload) {
        await _downloadSingleCsv(csvConfig);
        await _box.write(_lastCsvSyncTimestampKey, DateTime.now().millisecondsSinceEpoch);
        _loadedCsvs[csvKey] = true;
        log('📦 CsvDataService: $csvKey downloaded and cached.');
      }
    } catch (e, st) {
      log('❌ CsvDataService: Error loading $csvKey: $e\n$st');
      _loadedCsvs[csvKey] = false;
      rethrow;
    }
  }

  /// Get CSV configuration by key
  Map<String, dynamic>? _getCsvConfig(String csvKey) {
    final csvConfigs = [
      {'key': _salesMasterCacheKey, 'filename': 'SalesInvoiceMaster.csv', 'priority': 1},
      {'key': _salesDetailsCacheKey, 'filename': 'SalesInvoiceDetails.csv', 'priority': 1},
      {'key': _itemMasterCacheKey, 'filename': 'ItemMaster.csv', 'priority': 1},
      {'key': _itemDetailCacheKey, 'filename': 'ItemDetail.csv', 'priority': 1},
      {'key': _accountMasterCacheKey, 'filename': 'AccountMaster.csv', 'priority': 2},
      {'key': _allAccountsCacheKey, 'filename': 'AllAccounts.csv', 'priority': 2},
      {'key': _customerInfoCacheKey, 'filename': 'CustomerInformation.csv', 'priority': 2},
      {'key': _supplierInfoCacheKey, 'filename': 'SupplierInformation.csv', 'priority': 2},
    ];
    
    return csvConfigs.firstWhere(
      (config) => config['key'] == csvKey,
      orElse: () => null,
    );
  }

  /// Download a single CSV file
  Future<void> _downloadSingleCsv(Map<String, dynamic> csvConfig) async {
    try {
      if (memoryUsageMB.value > _maxMemoryUsageMB * 0.8 && csvConfig['priority'] > 1) {
        log('⚠️ CsvDataService: Skipping ${csvConfig['filename']} due to memory constraints');
        return;
      }

      final path = await SoftAgriPath.build(drive);
      final folderId = await drive.folderId(path);
      final fileId = await drive.fileId(csvConfig['filename'], folderId);
      final csvData = await drive.downloadCsv(fileId);

      final String key = csvConfig['key'];
      final double estimatedSize = (csvData.length * 2) / (1024 * 1024);

      memoryUsageMB.value += estimatedSize;
      _populateReactiveVarFromCache(key, csvData);
      await _box.write(key, csvData);

      log('📥 CsvDataService: Downloaded $key (${estimatedSize.toStringAsFixed(1)}MB)');

    } catch (e, st) {
      log('❌ CsvDataService: Failed to download ${csvConfig['filename']}: $e\n$st');
      rethrow;
    }
  }

  /// Loads all required CSVs with memory-efficient processing
  /// If [forceDownload] is true, it will always download new data, ignoring cache validity.
  /// This method now handles ALL primary CSVs used throughout the app with memory management.
  Future<void> loadAllCsvs({bool forceDownload = false}) async {
    log('🔄 CsvDataService: loadAllCsvs called (forceDownload: $forceDownload)');

    // Skip reloading if we've already downloaded and no force is required
    if (!forceDownload && _hasDownloadedOnce) {
      log('⏭️ CsvDataService: Skipping loadAllCsvs – already loaded this session.');
      return;
    }

    final List<String> allCsvKeys = [
      _salesMasterCacheKey,
      _salesDetailsCacheKey,
      _itemMasterCacheKey,
      _itemDetailCacheKey,
      _accountMasterCacheKey,
      _allAccountsCacheKey,
      _customerInfoCacheKey,
      _supplierInfoCacheKey,
    ];

    await loadCsvs(allCsvKeys, forceDownload: forceDownload);
    _hasDownloadedOnce = true;
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

  /// Parse CSV data on-demand using background processor
  Future<List<Map<String, dynamic>>> parseCsvData(String csvKey, {String? taskName}) async {
    String csvData = '';

    switch (csvKey) {
      case _salesMasterCacheKey: csvData = salesMasterCsv.value; break;
      case _salesDetailsCacheKey: csvData = salesDetailsCsv.value; break;
      case _itemMasterCacheKey: csvData = itemMasterCsv.value; break;
      case _itemDetailCacheKey: csvData = itemDetailCsv.value; break;
      case _accountMasterCacheKey: csvData = accountMasterCsv.value; break;
      case _allAccountsCacheKey: csvData = allAccountsCsv.value; break;
      case _customerInfoCacheKey: csvData = customerInfoCsv.value; break;
      case _supplierInfoCacheKey: csvData = supplierInfoCsv.value; break;
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

  Future<List<Map<String, dynamic>>> getCachedParsedData(String csvKey) async {
    if (_parsedDataCache.containsKey(csvKey)) {
      return _parsedDataCache[csvKey]!;
    }

    final parsed = await parseCsvData(csvKey);
    _parsedDataCache[csvKey] = parsed;
    return parsed;
  }

  /// Clear parsed data cache to free memory
  void clearParsedCache() {
    _parsedDataCache.clear();
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

  /// Check if a specific CSV is loaded
  bool isCsvLoaded(String csvKey) {
    return _loadedCsvs[csvKey] == true;
  }

  /// Get list of loaded CSVs
  List<String> getLoadedCsvs() {
    return _loadedCsvs.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get list of CSVs that are currently loading
  List<String> getLoadingCsvs() {
    return _loadingFutures.entries
        .where((entry) => entry.value != null)
        .map((entry) => entry.key)
        .toList();
  }

  /// Clear specific CSV from memory
  void clearCsvFromMemory(String csvKey) {
    _loadedCsvs[csvKey] = false;
    switch (csvKey) {
      case _salesMasterCacheKey:
        salesMasterCsv.value = '';
        break;
      case _salesDetailsCacheKey:
        salesDetailsCsv.value = '';
        break;
      case _itemMasterCacheKey:
        itemMasterCsv.value = '';
        break;
      case _itemDetailCacheKey:
        itemDetailCsv.value = '';
        break;
      case _accountMasterCacheKey:
        accountMasterCsv.value = '';
        break;
      case _allAccountsCacheKey:
        allAccountsCsv.value = '';
        break;
      case _customerInfoCacheKey:
        customerInfoCsv.value = '';
        break;
      case _supplierInfoCacheKey:
        supplierInfoCsv.value = '';
        break;
    }
    log('🧹 CsvDataService: Cleared $csvKey from memory');
  }
}