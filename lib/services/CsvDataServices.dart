// lib/services/csv_data_service.dart
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:developer';
import 'dart:isolate';
import 'dart:async';

import '../constants/paths.dart';
import 'google_drive_service.dart';
import 'package:flutter/foundation.dart'; // for compute
import '../util/csv_worker.dart'; // your new isolate parser

class CsvDataService extends GetxController {
  final GoogleDriveService drive = Get.find<GoogleDriveService>();
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
  
  // Progress tracking
  final RxBool isLoading = false.obs;
  final RxString loadingMessage = ''.obs;
  final RxDouble loadingProgress = 0.0.obs;
  final RxInt currentFileIndex = 0.obs;
  final RxInt totalFiles = 0.obs;

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
    log('🔄 CsvDataService: loadAllCsvs called (forceDownload: $forceDownload)');

    // Skip reloading if we've already downloaded and no force is required
    if (!forceDownload && _hasDownloadedOnce) {
      log('⏭️ CsvDataService: Skipping loadAllCsvs – already loaded this session.');
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

  Future<void> _loadCsvsInternal({required bool forceDownload}) async {
    isLoading.value = true;
    loadingMessage.value = 'Checking cache...';
    loadingProgress.value = 0.0;
    
    try {
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
            loadingMessage.value = 'Loading from cache...';
            for (int i = 0; i < csvConfigs.length; i++) {
              final config = csvConfigs[i];
              final cached = _box.read(config['key']);
              if (cached != null && cached.isNotEmpty) {
                _populateReactiveVarFromCache(config['key'], cached);
              }
              loadingProgress.value = (i + 1) / csvConfigs.length;
            }
            return;
          }
        }
      }

      if (needsDownload) {
        loadingMessage.value = 'Downloading data from Google Drive...';
        final path = await SoftAgriPath.build(drive);
        final folderId = await drive.folderId(path);
        await _downloadCsvsWithProgressTracking(csvConfigs, folderId);
        await _box.write(_lastCsvSyncTimestampKey, DateTime.now().millisecondsSinceEpoch);
        log('📦 CsvDataService: All CSVs downloaded and cached.');
      }
    } catch (e, st) {
      log('❌ CsvDataService: Error in _loadCsvsInternal: $e\n$st');
      _clearAllReactiveVars();
    } finally {
      isLoading.value = false;
      loadingMessage.value = '';
      loadingProgress.value = 0.0;
    }
  }

  /// Download CSVs with progress tracking and memory management
  Future<void> _downloadCsvsWithProgressTracking(
      List<Map<String, dynamic>> csvConfigs,
      String folderId,
      ) async {
    csvConfigs.sort((a, b) => a['priority'].compareTo(b['priority']));
    totalFiles.value = csvConfigs.length;

    // Download all files first
    final List<Map<String, dynamic>> downloadTasks = [];
    for (int i = 0; i < csvConfigs.length; i++) {
      final config = csvConfigs[i];
      currentFileIndex.value = i + 1;
      loadingMessage.value = 'Downloading ${config['filename']}...';
      
      try {
        final fileId = await drive.fileId(config['filename'], folderId);
        final csvData = await drive.downloadCsv(fileId);
        
        downloadTasks.add({
          'key': config['key'],
          'csvData': csvData,
          'chunkSize': _chunkSize,
        });
        
        loadingProgress.value = (i + 1) / csvConfigs.length;
        
        // Small delay to prevent overwhelming the network
        await Future.delayed(Duration(milliseconds: 200));
        
      } catch (e, st) {
        log('❌ CsvDataService: Failed to download ${config['filename']}: $e\n$st');
        continue;
      }
    }

    // Process all downloaded files using isolates
    if (downloadTasks.isNotEmpty) {
      loadingMessage.value = 'Processing data...';
      await _processCsvsInIsolates(downloadTasks);
    }
  }

  /// Process CSVs using isolates with progress tracking
  Future<void> _processCsvsInIsolates(List<Map<String, dynamic>> downloadTasks) async {
    // Create a receive port for progress updates
    final receivePort = ReceivePort();
    
    // Listen for progress updates
    receivePort.listen((message) {
      if (message is Map<String, dynamic>) {
        if (message['type'] == 'progress') {
          final current = message['current'] as int;
          final total = message['total'] as int;
          final progress = total > 0 ? current / total : 0.0;
          
          loadingMessage.value = message['message'] ?? 'Processing...';
          loadingProgress.value = progress;
        } else if (message['type'] == 'file_progress') {
          loadingMessage.value = message['message'] ?? 'Processing files...';
        }
      }
    });

    try {
      // Process files in batches to avoid memory issues
      const int batchSize = 3;
      for (int i = 0; i < downloadTasks.length; i += batchSize) {
        final end = (i + batchSize < downloadTasks.length) ? i + batchSize : downloadTasks.length;
        final batch = downloadTasks.sublist(i, end);
        
        // Process batch using isolate
        final results = await compute(processMultipleCsvs, {
          'csvConfigs': batch,
          'progressPort': receivePort.sendPort,
        });
        
        // Update reactive variables with results
        for (final entry in results.entries) {
          final key = entry.key;
          final result = entry.value as Map<String, dynamic>;
          
          final String parsedCsv = result['csvData'];
          final double estimatedSize = result['estimatedSizeMB'];
          
          memoryUsageMB.value += estimatedSize;
          _populateReactiveVarFromCache(key, parsedCsv);
          await _box.write(key, parsedCsv);
          
          log('📥 CsvDataService: Processed $key (${estimatedSize.toStringAsFixed(1)}MB)');
        }
        
        // Small delay between batches
        await Future.delayed(Duration(milliseconds: 100));
      }
    } finally {
      receivePort.close();
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