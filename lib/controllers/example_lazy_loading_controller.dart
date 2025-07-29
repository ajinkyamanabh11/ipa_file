// Example controller demonstrating lazy loading approach
import 'package:get/get.dart';
import 'dart:developer';
import '../services/CsvDataServices.dart';

class ExampleLazyLoadingController extends GetxController {
  final CsvDataService _csvDataService = Get.find<CsvDataService>();
  
  // Observable variables for different data types
  final salesData = <Map<String, dynamic>>[].obs;
  final stockData = <Map<String, dynamic>>[].obs;
  final customerData = <Map<String, dynamic>>[].obs;
  
  final isLoading = false.obs;
  final errorMessage = RxString('');

  /// Example 1: Load only sales-related data when needed
  Future<void> loadSalesData({bool forceRefresh = false}) async {
    log('🔄 ExampleLazyLoadingController: Loading sales data...');
    isLoading.value = true;
    errorMessage.value = '';

    try {
      // Load only the CSVs needed for sales data
      await _csvDataService.loadCsvs([
        CsvDataService.salesMasterCacheKey,
        CsvDataService.salesDetailsCacheKey,
        CsvDataService.itemMasterCacheKey,
      ], forceDownload: forceRefresh);

      // Process the data
      final salesMasterCsv = _csvDataService.salesMasterCsv.value;
      if (salesMasterCsv.isNotEmpty) {
        // Process sales data here
        log('✅ Sales data loaded successfully');
      }
    } catch (e) {
      log('❌ Error loading sales data: $e');
      errorMessage.value = 'Failed to load sales data: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Example 2: Load only stock-related data when needed
  Future<void> loadStockData({bool forceRefresh = false}) async {
    log('🔄 ExampleLazyLoadingController: Loading stock data...');
    isLoading.value = true;
    errorMessage.value = '';

    try {
      // Load only the CSVs needed for stock data
      await _csvDataService.loadCsvs([
        CsvDataService.itemMasterCacheKey,
        CsvDataService.itemDetailCacheKey,
      ], forceDownload: forceRefresh);

      // Process the data
      final itemMasterCsv = _csvDataService.itemMasterCsv.value;
      final itemDetailCsv = _csvDataService.itemDetailCsv.value;
      
      if (itemMasterCsv.isNotEmpty && itemDetailCsv.isNotEmpty) {
        // Process stock data here
        log('✅ Stock data loaded successfully');
      }
    } catch (e) {
      log('❌ Error loading stock data: $e');
      errorMessage.value = 'Failed to load stock data: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Example 3: Load only customer-related data when needed
  Future<void> loadCustomerData({bool forceRefresh = false}) async {
    log('🔄 ExampleLazyLoadingController: Loading customer data...');
    isLoading.value = true;
    errorMessage.value = '';

    try {
      // Load only the CSVs needed for customer data
      await _csvDataService.loadCsvs([
        CsvDataService.accountMasterCacheKey,
        CsvDataService.allAccountsCacheKey,
        CsvDataService.customerInfoCacheKey,
      ], forceDownload: forceRefresh);

      // Process the data
      final customerInfoCsv = _csvDataService.customerInfoCsv.value;
      if (customerInfoCsv.isNotEmpty) {
        // Process customer data here
        log('✅ Customer data loaded successfully');
      }
    } catch (e) {
      log('❌ Error loading customer data: $e');
      errorMessage.value = 'Failed to load customer data: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Example 4: Load a single CSV on-demand
  Future<void> loadSingleCsv(String csvKey, {bool forceRefresh = false}) async {
    log('🔄 ExampleLazyLoadingController: Loading single CSV: $csvKey');
    isLoading.value = true;
    errorMessage.value = '';

    try {
      // Load only the specific CSV needed
      await _csvDataService.loadCsv(csvKey, forceDownload: forceRefresh);
      log('✅ Single CSV loaded successfully: $csvKey');
    } catch (e) {
      log('❌ Error loading single CSV: $e');
      errorMessage.value = 'Failed to load CSV: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Example 5: Check if specific CSV is already loaded
  bool isCsvLoaded(String csvKey) {
    return _csvDataService.isCsvLoaded(csvKey);
  }

  /// Example 6: Clear specific data from memory to free up space
  void clearSpecificData(String csvKey) {
    _csvDataService.clearCsvFromMemory(csvKey);
  }

  /// Example 9: Get list of loaded CSVs
  List<String> getLoadedCsvs() {
    return _csvDataService.getLoadedCsvs();
  }

  /// Example 10: Get list of CSVs currently loading
  List<String> getLoadingCsvs() {
    return _csvDataService.getLoadingCsvs();
  }

  /// Example 7: Get memory usage information
  double getCurrentMemoryUsage() {
    return _csvDataService.getCurrentMemoryUsageMB();
  }

  /// Example 8: Force cleanup when memory is high
  void performMemoryCleanup() {
    _csvDataService.performMemoryCleanup();
    log('🧹 Memory cleanup performed');
  }
}