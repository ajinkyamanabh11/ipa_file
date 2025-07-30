// lib/services/lazy_csv_service.dart
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:developer';
import 'dart:isolate';

import '../constants/paths.dart';
import 'google_drive_service.dart';
import 'background_processor.dart';
import '../util/csv_worker.dart';

/// Enum to define different CSV types for easy management
enum CsvType {
  salesMaster('SalesInvoiceMaster.csv', 'salesMasterCsv', 1),
  salesDetails('SalesInvoiceDetails.csv', 'salesDetailsCsv', 1),
  itemMaster('ItemMaster.csv', 'itemMasterCsv', 1),
  itemDetail('ItemDetail.csv', 'itemDetailCsv', 1),
  accountMaster('AccountMaster.csv', 'accountMasterCsv', 2),
  allAccounts('AllAccounts.csv', 'allAccountsCsv', 2),
  customerInfo('CustomerInformation.csv', 'customerInfoCsv', 2),
  supplierInfo('SupplierInformation.csv', 'supplierInfoCsv', 2);

  const CsvType(this.filename, this.cacheKey, this.priority);
  
  final String filename;
  final String cacheKey;
  final int priority; // 1 = essential, 2 = optional
}

/// Loading state for individual CSV files
class CsvLoadingState {
  final bool isLoading;
  final double progress;
  final String? error;
  final DateTime? lastUpdated;
  final int? sizeInBytes;

  const CsvLoadingState({
    this.isLoading = false,
    this.progress = 0.0,
    this.error,
    this.lastUpdated,
    this.sizeInBytes,
  });

  CsvLoadingState copyWith({
    bool? isLoading,
    double? progress,
    String? error,
    DateTime? lastUpdated,
    int? sizeInBytes,
  }) {
    return CsvLoadingState(
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
    );
  }
}

/// Service for lazy loading CSV data on-demand with intelligent caching
class LazyCsvService extends GetxController {
  final GoogleDriveService _drive = Get.find<GoogleDriveService>();
  final BackgroundProcessor _backgroundProcessor = Get.find<BackgroundProcessor>();
  final GetStorage _box = GetStorage();

  // Cache duration - longer than before since we're being more selective
  static const Duration _cacheDuration = Duration(hours: 2);
  
  // Memory management
  static const int _maxMemoryUsageMB = 50; // Reduced since we're loading on-demand
  static const double _memoryCleanupThreshold = 0.8; // Cleanup at 80% of max

  // Observable states for each CSV type
  final RxMap<CsvType, CsvLoadingState> _loadingStates = <CsvType, CsvLoadingState>{}.obs;
  final RxMap<CsvType, String> _csvData = <CsvType, String>{}.obs;
  final RxMap<CsvType, List<Map<String, dynamic>>> _parsedData = <CsvType, List<Map<String, dynamic>>>{}.obs;
  
  // Overall memory usage tracking
  final RxDouble memoryUsageMB = 0.0.obs;
  final RxBool isMemoryWarning = false.obs;

  // Active loading futures to prevent duplicate requests
  final Map<CsvType, Future<void>> _loadingFutures = {};
  
  @override
  void onInit() {
    super.onInit();
    _initializeLoadingStates();
    _startMemoryMonitoring();
  }

  void _initializeLoadingStates() {
    for (final csvType in CsvType.values) {
      _loadingStates[csvType] = const CsvLoadingState();
    }
  }

  void _startMemoryMonitoring() {
    // Monitor memory usage
    ever(memoryUsageMB, (usage) {
      if (usage > _maxMemoryUsageMB * _memoryCleanupThreshold) {
        isMemoryWarning.value = true;
        log('⚠️ LazyCsvService: High memory usage: ${usage}MB. Triggering cleanup.');
        _performMemoryCleanup();
      } else {
        isMemoryWarning.value = false;
      }
    });
  }

  /// Get loading state for a specific CSV type
  CsvLoadingState getLoadingState(CsvType csvType) {
    return _loadingStates[csvType] ?? const CsvLoadingState();
  }

  /// Check if a CSV type is currently loading
  bool isLoading(CsvType csvType) {
    return _loadingStates[csvType]?.isLoading ?? false;
  }

  /// Get loading progress for a specific CSV type
  double getProgress(CsvType csvType) {
    return _loadingStates[csvType]?.progress ?? 0.0;
  }

  /// Load a specific CSV file on-demand
  Future<String> loadCsv(CsvType csvType, {bool forceDownload = false}) async {
    // Return cached data if available and still valid
    if (!forceDownload && _csvData.containsKey(csvType) && _csvData[csvType]!.isNotEmpty) {
      if (_isCacheValid(csvType)) {
        log('✅ LazyCsvService: Returning cached data for ${csvType.filename}');
        return _csvData[csvType]!;
      }
    }

    // Check if already loading
    if (_loadingFutures.containsKey(csvType)) {
      log('⏳ LazyCsvService: ${csvType.filename} already loading, waiting...');
      await _loadingFutures[csvType];
      return _csvData[csvType] ?? '';
    }

    // Start loading
    final loadingFuture = _loadCsvInternal(csvType, forceDownload: forceDownload);
    _loadingFutures[csvType] = loadingFuture;

    try {
      await loadingFuture;
      return _csvData[csvType] ?? '';
    } finally {
      _loadingFutures.remove(csvType);
    }
  }

  /// Load multiple CSV files efficiently
  Future<Map<CsvType, String>> loadMultipleCsvs(
    List<CsvType> csvTypes, {
    bool forceDownload = false,
    Function(CsvType, double)? onProgress,
  }) async {
    final Map<CsvType, String> results = {};
    final List<Future<void>> loadingFutures = [];

    for (final csvType in csvTypes) {
      loadingFutures.add(
        loadCsv(csvType, forceDownload: forceDownload).then((data) {
          results[csvType] = data;
          onProgress?.call(csvType, 1.0);
        }).catchError((error) {
          log('❌ LazyCsvService: Error loading ${csvType.filename}: $error');
          results[csvType] = '';
        }),
      );
    }

    await Future.wait(loadingFutures);
    return results;
  }

  /// Internal method to load a single CSV file
  Future<void> _loadCsvInternal(CsvType csvType, {bool forceDownload = false}) async {
    log('🔄 LazyCsvService: Loading ${csvType.filename}...');
    
    _updateLoadingState(csvType, const CsvLoadingState(isLoading: true, progress: 0.0));

    try {
      // Check cache first
      if (!forceDownload) {
        final cachedData = _loadFromCache(csvType);
        if (cachedData != null && cachedData.isNotEmpty) {
          _csvData[csvType] = cachedData;
          _updateLoadingState(csvType, CsvLoadingState(
            isLoading: false,
            progress: 1.0,
            lastUpdated: DateTime.now(),
            sizeInBytes: cachedData.length,
          ));
          _updateMemoryUsage();
          log('📦 LazyCsvService: Loaded ${csvType.filename} from cache');
          return;
        }
      }

      // Download from Google Drive
      _updateLoadingState(csvType, const CsvLoadingState(isLoading: true, progress: 0.3));
      
      final path = await SoftAgriPath.build(_drive);
      final folderId = await _drive.folderId(path);
      final fileId = await _drive.fileId(csvType.filename, folderId);
      
      _updateLoadingState(csvType, const CsvLoadingState(isLoading: true, progress: 0.6));
      
      final csvData = await _drive.downloadCsv(fileId);
      
      _updateLoadingState(csvType, const CsvLoadingState(isLoading: true, progress: 0.9));

      // Store in memory and cache
      _csvData[csvType] = csvData;
      await _saveToCache(csvType, csvData);
      
      _updateLoadingState(csvType, CsvLoadingState(
        isLoading: false,
        progress: 1.0,
        lastUpdated: DateTime.now(),
        sizeInBytes: csvData.length,
      ));

      _updateMemoryUsage();
      log('📥 LazyCsvService: Downloaded and cached ${csvType.filename} (${(csvData.length / 1024).toStringAsFixed(1)}KB)');

    } catch (e, st) {
      log('❌ LazyCsvService: Error loading ${csvType.filename}: $e\n$st');
      _updateLoadingState(csvType, CsvLoadingState(
        isLoading: false,
        progress: 0.0,
        error: e.toString(),
      ));
      _csvData[csvType] = '';
    }
  }

  /// Parse CSV data on-demand
  Future<List<Map<String, dynamic>>> getParsedData(CsvType csvType) async {
    // Return cached parsed data if available
    if (_parsedData.containsKey(csvType) && _parsedData[csvType]!.isNotEmpty) {
      return _parsedData[csvType]!;
    }

    // Load raw CSV if not available
    final rawCsv = await loadCsv(csvType);
    if (rawCsv.isEmpty) {
      return [];
    }

    // Parse in background
    try {
      final parsed = await _backgroundProcessor.processCsvData(
        csvData: rawCsv,
        taskName: 'Parsing ${csvType.filename}',
        shouldParse: true,
        onProgress: (progress) {
          log('📊 LazyCsvService: Parsing ${csvType.filename} - ${(progress * 100).toStringAsFixed(1)}%');
        },
      );

      _parsedData[csvType] = parsed;
      _updateMemoryUsage();
      return parsed;
    } catch (e) {
      log('❌ LazyCsvService: Error parsing ${csvType.filename}: $e');
      return [];
    }
  }

  /// Check if cached data is still valid
  bool _isCacheValid(CsvType csvType) {
    final lastSync = _box.read<int?>('${csvType.cacheKey}_timestamp');
    if (lastSync == null) return false;
    
    final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);
    return DateTime.now().difference(lastSyncTime) < _cacheDuration;
  }

  /// Load data from cache
  String? _loadFromCache(CsvType csvType) {
    if (!_isCacheValid(csvType)) return null;
    return _box.read<String?>(csvType.cacheKey);
  }

  /// Save data to cache
  Future<void> _saveToCache(CsvType csvType, String data) async {
    await _box.write(csvType.cacheKey, data);
    await _box.write('${csvType.cacheKey}_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  /// Update loading state for a CSV type
  void _updateLoadingState(CsvType csvType, CsvLoadingState state) {
    _loadingStates[csvType] = state;
  }

  /// Update memory usage calculation
  void _updateMemoryUsage() {
    double totalSize = 0.0;
    
    // Calculate raw CSV data size
    for (final entry in _csvData.entries) {
      totalSize += (entry.value.length * 2) / (1024 * 1024); // UTF-16 encoding estimate
    }
    
    // Calculate parsed data size (rough estimate)
    for (final entry in _parsedData.entries) {
      totalSize += (entry.value.length * 0.5) / 1024; // Rough estimate
    }
    
    memoryUsageMB.value = totalSize;
  }

  /// Perform memory cleanup
  void _performMemoryCleanup() {
    // Clear optional CSV data first (priority 2)
    final optionalTypes = CsvType.values.where((type) => type.priority > 1).toList();
    
    for (final csvType in optionalTypes) {
      if (_csvData.containsKey(csvType)) {
        _csvData.remove(csvType);
        log('🧹 LazyCsvService: Cleared ${csvType.filename} from memory');
      }
      if (_parsedData.containsKey(csvType)) {
        _parsedData.remove(csvType);
      }
    }
    
    _updateMemoryUsage();
  }

  /// Clear all data from memory (but keep cache)
  void clearMemory() {
    _csvData.clear();
    _parsedData.clear();
    _updateMemoryUsage();
    log('🧹 LazyCsvService: Cleared all data from memory');
  }

  /// Clear specific CSV from memory and cache
  Future<void> clearCsv(CsvType csvType) async {
    _csvData.remove(csvType);
    _parsedData.remove(csvType);
    await _box.remove(csvType.cacheKey);
    await _box.remove('${csvType.cacheKey}_timestamp');
    _updateMemoryUsage();
    log('🗑️ LazyCsvService: Cleared ${csvType.filename} from memory and cache');
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    for (final csvType in CsvType.values) {
      await _box.remove(csvType.cacheKey);
      await _box.remove('${csvType.cacheKey}_timestamp');
    }
    clearMemory();
    log('🗑️ LazyCsvService: Cleared all cache and memory');
  }

  /// Get cache info for debugging
  Map<String, dynamic> getCacheInfo() {
    final Map<String, dynamic> info = {};
    
    for (final csvType in CsvType.values) {
      final timestamp = _box.read<int?>('${csvType.cacheKey}_timestamp');
      final hasData = _box.read<String?>(csvType.cacheKey) != null;
      final isValid = _isCacheValid(csvType);
      
      info[csvType.filename] = {
        'cached': hasData,
        'valid': isValid,
        'timestamp': timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null,
        'inMemory': _csvData.containsKey(csvType),
        'parsed': _parsedData.containsKey(csvType),
      };
    }
    
    return info;
  }
}