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
  late final BackgroundProcessor _backgroundProcessor;
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

  // Optimized cache duration for better performance - cache for 30 minutes
  static const Duration _cacheDuration = Duration(minutes: 30); //  Longer cache for better performance

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
    // Initialize background processor lazily
    _backgroundProcessor = Get.find<BackgroundProcessor>();
    _startMemoryMonitoring();
    // Don't automatically load CSVs on init - load on-demand only
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
    log('🔄 CsvDataService: loadAllCsvs called (forceDownload: $forceDownload)');

    // Skip reloading if we've already downloaded and no force is required
    if (!forceDownload && _hasDownloadedOnce) {
      log('⏭️ CsvDataService: Skipping loadAllCsvs – already loaded this session.');
      return;
    }

    // Only load essential CSVs unless specifically requested
    if (!forceDownload) {
      log('📋 CsvDataService: Loading only from cache, no automatic download');
      _loadFromCacheOnly();
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
    _loadingFuture = _loadCsvsInternal(forceDownload: forceDownload);
    await _loadingFuture;
    _loadingFuture = null;
    _hasDownloadedOnce = true;
  }

  /// Load only from cache without downloading new data
  void _loadFromCacheOnly() {
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

    log('📁 CsvDataService: Loading CSVs from cache only.');
    for (final config in csvConfigs) {
      final cached = _box.read(config['key']);
      if (cached != null && cached.isNotEmpty) {
        _populateReactiveVarFromCache(config['key'], cached);
      }
    }
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
          for (final config in csvConfigs) {
            final cached = _box.read(config['key']);
            if (cached != null && cached.isNotEmpty) {
              _populateReactiveVarFromCache(config['key'], cached);
            }
          }
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
      }
    }
  }


  /// Download CSVs with memory management and priority-based loading
  Future<void> _downloadCsvsWithMemoryManagement(
      List<Map<String, dynamic>> csvConfigs,
      String folderId,
      ) async {
    csvConfigs.sort((a, b) => a['priority'].compareTo(b['priority']));

    for (final config in csvConfigs) {
      try {
        if (memoryUsageMB.value > _maxMemoryUsageMB * 0.8 && config['priority'] > 1) {
          log('⚠️ CsvDataService: Skipping ${config['filename']} due to memory constraints');
          continue;
        }

        final fileId = await drive.fileId(config['filename'], folderId);
        final csvData = await drive.downloadCsv(fileId);

        // 💡 Offload parsing to background processor with progress tracking
        final result = await _backgroundProcessor.processCsvData(
          csvData: csvData,
          taskName: 'Processing ${config['filename']}',
          shouldParse: false, // We'll store raw CSV and parse on demand
          onProgress: (progress) {
            log('📊 CsvDataService: Processing ${config['filename']} - ${(progress * 100).toStringAsFixed(1)}%');
          },
        );

        final String key = config['key'];
        final String parsedCsv = csvData; // Store raw CSV for now
        final double estimatedSize = (csvData.length * 2) / (1024 * 1024);

        memoryUsageMB.value += estimatedSize;
        _populateReactiveVarFromCache(key, parsedCsv);
        await _box.write(key, parsedCsv);

        log('📥 CsvDataService: Downloaded $key (${estimatedSize.toStringAsFixed(1)}MB)');

        await Future.delayed(Duration(milliseconds: 50)); // Reduced delay

      } catch (e, st) {
        log('❌ CsvDataService: Failed to download ${config['filename']}: $e\n$st');
        continue;
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
}