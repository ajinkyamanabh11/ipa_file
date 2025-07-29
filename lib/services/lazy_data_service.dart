// lib/services/lazy_data_service.dart
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:developer';
import 'dart:isolate';

import '../constants/paths.dart';
import 'google_drive_service.dart';
import 'background_processor.dart';
import 'package:flutter/foundation.dart';
import '../util/csv_worker.dart';

class LazyDataService extends GetxController {
  final GoogleDriveService drive = Get.find<GoogleDriveService>();
  final BackgroundProcessor _backgroundProcessor = Get.find<BackgroundProcessor>();
  final GetStorage _box = GetStorage();

  // Cache keys for different data types
  static const String _salesMasterCacheKey = 'salesMasterCsv';
  static const String _salesDetailsCacheKey = 'salesDetailsCsv';
  static const String _itemMasterCacheKey = 'itemMasterCsv';
  static const String _itemDetailCacheKey = 'itemDetailCsv';
  static const String _accountMasterCacheKey = 'accountMasterCsv';
  static const String _allAccountsCacheKey = 'allAccountsCsv';
  static const String _customerInfoCacheKey = 'customerInfoCsv';
  static const String _supplierInfoCacheKey = 'supplierInfoCacheKey';

  // Cache duration
  static const Duration _cacheDuration = Duration(hours: 1);

  // Memory management
  static const int _maxMemoryUsageMB = 100;
  final RxDouble memoryUsageMB = 0.0.obs;
  final RxBool isMemoryWarning = false.obs;

  // Loading state tracking
  final Map<String, Future<void>?> _loadingFutures = {};
  final Map<String, bool> _isLoaded = {};

  // Reactive variables for loaded data
  final RxString salesMasterCsv = ''.obs;
  final RxString salesDetailsCsv = ''.obs;
  final RxString itemMasterCsv = ''.obs;
  final RxString itemDetailCsv = ''.obs;
  final RxString accountMasterCsv = ''.obs;
  final RxString allAccountsCsv = ''.obs;
  final RxString customerInfoCsv = ''.obs;
  final RxString supplierInfoCsv = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _startMemoryMonitoring();
  }

  /// Monitor memory usage and trigger cleanup if needed
  void _startMemoryMonitoring() {
    ever(memoryUsageMB, (usage) {
      if (usage > _maxMemoryUsageMB) {
        isMemoryWarning.value = true;
        log('⚠️ LazyDataService: High memory usage detected: ${usage}MB. Triggering cleanup.');
        performMemoryCleanup();
      } else {
        isMemoryWarning.value = false;
      }
    });
  }

  /// Perform memory cleanup when usage is high
  void performMemoryCleanup() {
    // Clear least recently used data first
    _clearDataIfNeeded();
    _requestGarbageCollection();
  }

  void _requestGarbageCollection() {
    List.generate(100, (index) => []).clear();
  }

  /// Load specific CSV data on demand
  Future<void> loadSalesData({bool forceRefresh = false}) async {
    await _loadData('sales', [
      {'key': _salesMasterCacheKey, 'filename': 'SalesInvoiceMaster.csv'},
      {'key': _salesDetailsCacheKey, 'filename': 'SalesInvoiceDetails.csv'},
    ], forceRefresh: forceRefresh);
  }

  Future<void> loadItemData({bool forceRefresh = false}) async {
    await _loadData('items', [
      {'key': _itemMasterCacheKey, 'filename': 'ItemMaster.csv'},
      {'key': _itemDetailCacheKey, 'filename': 'ItemDetail.csv'},
    ], forceRefresh: forceRefresh);
  }

  Future<void> loadAccountData({bool forceRefresh = false}) async {
    await _loadData('accounts', [
      {'key': _accountMasterCacheKey, 'filename': 'AccountMaster.csv'},
      {'key': _allAccountsCacheKey, 'filename': 'AllAccounts.csv'},
    ], forceRefresh: forceRefresh);
  }

  Future<void> loadCustomerData({bool forceRefresh = false}) async {
    await _loadData('customers', [
      {'key': _customerInfoCacheKey, 'filename': 'CustomerInformation.csv'},
    ], forceRefresh: forceRefresh);
  }

  Future<void> loadSupplierData({bool forceRefresh = false}) async {
    await _loadData('suppliers', [
      {'key': _supplierInfoCacheKey, 'filename': 'SupplierInformation.csv'},
    ], forceRefresh: forceRefresh);
  }

  /// Generic data loading method
  Future<void> _loadData(String dataType, List<Map<String, String>> configs, {bool forceRefresh = false}) async {
    final loadingKey = '${dataType}_loading';
    
    // Check if already loading
    if (_loadingFutures[loadingKey] != null && !forceRefresh) {
      log('⏳ LazyDataService: $dataType data already loading, waiting...');
      await _loadingFutures[loadingKey];
      return;
    }

    // Check if already loaded and cache is valid
    if (!forceRefresh && _isLoaded[dataType] == true && _isCacheValid()) {
      log('✅ LazyDataService: $dataType data already loaded and cache is valid');
      return;
    }

    log('🚀 LazyDataService: Loading $dataType data...');
    _loadingFutures[loadingKey] = _loadDataInternal(dataType, configs, forceRefresh);
    
    try {
      await _loadingFutures[loadingKey];
      _isLoaded[dataType] = true;
    } finally {
      _loadingFutures[loadingKey] = null;
    }
  }

  Future<void> _loadDataInternal(String dataType, List<Map<String, String>> configs, bool forceRefresh) async {
    try {
      // Check cache first
      if (!forceRefresh && _isCacheValid()) {
        bool allCached = true;
        for (final config in configs) {
          final cached = _box.read<String>(config['key']);
          if (cached == null || cached.isEmpty) {
            allCached = false;
            break;
          }
        }

        if (allCached) {
          log('📦 LazyDataService: Loading $dataType from cache');
          for (final config in configs) {
            final cached = _box.read<String>(config['key']);
            _populateReactiveVar(config['key']!, cached!);
          }
          return;
        }
      }

      // Download from Google Drive
      log('📥 LazyDataService: Downloading $dataType from Google Drive');
      final path = await SoftAgriPath.build(drive);
      final folderId = await drive.folderId(path);

      for (final config in configs) {
        await _downloadSingleCsv(config['key']!, config['filename']!, folderId);
      }

      // Update cache timestamp
      await _box.write('${dataType}_lastSync', DateTime.now().millisecondsSinceEpoch);
      log('✅ LazyDataService: $dataType data loaded successfully');

    } catch (e, st) {
      log('❌ LazyDataService: Error loading $dataType data: $e\n$st');
      rethrow;
    }
  }

  Future<void> _downloadSingleCsv(String cacheKey, String filename, String folderId) async {
    try {
      final fileId = await drive.fileId(filename, folderId);
      final csvData = await drive.downloadCsv(fileId);

      // Store in cache
      await _box.write(cacheKey, csvData);
      
      // Update reactive variable
      _populateReactiveVar(cacheKey, csvData);
      
      // Update memory usage
      final estimatedSize = (csvData.length * 2) / (1024 * 1024);
      memoryUsageMB.value += estimatedSize;

      log('📥 LazyDataService: Downloaded $filename (${estimatedSize.toStringAsFixed(1)}MB)');

    } catch (e, st) {
      log('❌ LazyDataService: Failed to download $filename: $e\n$st');
      rethrow;
    }
  }

  void _populateReactiveVar(String key, String data) {
    switch (key) {
      case _salesMasterCacheKey: salesMasterCsv.value = data; break;
      case _salesDetailsCacheKey: salesDetailsCsv.value = data; break;
      case _itemMasterCacheKey: itemMasterCsv.value = data; break;
      case _itemDetailCacheKey: itemDetailCsv.value = data; break;
      case _accountMasterCacheKey: accountMasterCsv.value = data; break;
      case _allAccountsCacheKey: allAccountsCsv.value = data; break;
      case _customerInfoCacheKey: customerInfoCsv.value = data; break;
      case _supplierInfoCacheKey: supplierInfoCsv.value = data; break;
    }
  }

  bool _isCacheValid() {
    // Check if any cache timestamp is within the valid duration
    final keys = ['sales_lastSync', 'items_lastSync', 'accounts_lastSync', 'customers_lastSync', 'suppliers_lastSync'];
    
    for (final key in keys) {
      final lastSync = _box.read<int?>(key);
      if (lastSync != null) {
        final cacheAge = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastSync));
        if (cacheAge < _cacheDuration) {
          return true;
        }
      }
    }
    return false;
  }

  void _clearDataIfNeeded() {
    // Clear least recently used data when memory is high
    if (memoryUsageMB.value > _maxMemoryUsageMB * 0.8) {
      // Clear customer and supplier data first (less frequently used)
      if (customerInfoCsv.value.isNotEmpty) {
        customerInfoCsv.value = '';
        _isLoaded['customers'] = false;
        log('🧹 LazyDataService: Cleared customer data from memory');
      }
      if (supplierInfoCsv.value.isNotEmpty) {
        supplierInfoCsv.value = '';
        _isLoaded['suppliers'] = false;
        log('🧹 LazyDataService: Cleared supplier data from memory');
      }
    }
  }

  /// Parse CSV data on-demand
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
      log('⚠️ LazyDataService: No CSV data found for key: $csvKey');
      return [];
    }

    return await _backgroundProcessor.processCsvData(
      csvData: csvData,
      taskName: taskName ?? 'Parsing $csvKey',
      shouldParse: true,
      onProgress: (progress) {
        log('📊 LazyDataService: Parsing $csvKey - ${(progress * 100).toStringAsFixed(1)}%');
      },
    );
  }

  /// Clear specific data from memory
  void clearData(String dataType) {
    switch (dataType) {
      case 'sales':
        salesMasterCsv.value = '';
        salesDetailsCsv.value = '';
        _isLoaded['sales'] = false;
        break;
      case 'items':
        itemMasterCsv.value = '';
        itemDetailCsv.value = '';
        _isLoaded['items'] = false;
        break;
      case 'accounts':
        accountMasterCsv.value = '';
        allAccountsCsv.value = '';
        _isLoaded['accounts'] = false;
        break;
      case 'customers':
        customerInfoCsv.value = '';
        _isLoaded['customers'] = false;
        break;
      case 'suppliers':
        supplierInfoCsv.value = '';
        _isLoaded['suppliers'] = false;
        break;
    }
    log('🧹 LazyDataService: Cleared $dataType data from memory');
  }

  /// Clear all data from memory
  void clearAllData() {
    salesMasterCsv.value = '';
    salesDetailsCsv.value = '';
    itemMasterCsv.value = '';
    itemDetailCsv.value = '';
    accountMasterCsv.value = '';
    allAccountsCsv.value = '';
    customerInfoCsv.value = '';
    supplierInfoCsv.value = '';
    
    _isLoaded.clear();
    memoryUsageMB.value = 0.0;
    
    log('🧹 LazyDataService: Cleared all data from memory');
  }

  /// Get current memory usage
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