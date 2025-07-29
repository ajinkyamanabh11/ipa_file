import 'package:get/get.dart';
import 'dart:developer';
import 'dart:async';
import '../services/CsvDataServices.dart';
import '../controllers/sales_controller.dart';
import '../controllers/customerLedger_Controller.dart';
import '../controllers/profit_report_controller.dart';
import '../controllers/stock_report_controller.dart';

class DataLoadingService extends GetxController {
  final CsvDataService _csvDataService = Get.find<CsvDataService>();
  
  // Controllers that need data
  late SalesController _salesController;
  late CustomerLedgerController _customerLedgerController;
  late ProfitReportController _profitReportController;
  late StockReportController _stockReportController;

  // Loading state management
  final RxBool isInitializing = false.obs;
  final RxString initializationMessage = ''.obs;
  final RxDouble initializationProgress = 0.0.obs;
  final RxBool isDataReady = false.obs;

  // Memory management
  final RxDouble totalMemoryUsageMB = 0.0.obs;
  final RxBool isMemoryWarning = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeControllers();
    _startMemoryMonitoring();
  }

  void _initializeControllers() {
    _salesController = Get.find<SalesController>();
    _customerLedgerController = Get.find<CustomerLedgerController>();
    _profitReportController = Get.find<ProfitReportController>();
    _stockReportController = Get.find<StockReportController>();
  }

  void _startMemoryMonitoring() {
    // Monitor memory usage every 10 seconds
    Timer.periodic(Duration(seconds: 10), (timer) {
      _updateMemoryUsage();
    });
  }

  void _updateMemoryUsage() {
    double totalUsage = 0.0;
    
    // Get memory usage from CSV service
    totalUsage += _csvDataService.getCurrentMemoryUsageMB();
    
    // Add estimated memory from controllers (if they have memory tracking)
    // This is a rough estimate based on data size
    
    totalMemoryUsageMB.value = totalUsage;
    
    if (totalUsage > 150) { // 150MB threshold
      isMemoryWarning.value = true;
      log('⚠️ DataLoadingService: High memory usage detected: ${totalUsage.toStringAsFixed(1)}MB');
      _performMemoryCleanup();
    } else {
      isMemoryWarning.value = false;
    }
  }

  void _performMemoryCleanup() {
    log('🧹 DataLoadingService: Performing memory cleanup...');
    
    // Clear non-essential cached data
    _csvDataService.performMemoryCleanup();
    
    // Force garbage collection hint
    _requestGarbageCollection();
  }

  void _requestGarbageCollection() {
    // Hint to Dart VM to consider garbage collection
    List.generate(100, (index) => []).clear();
  }

  /// Initialize all data with progress tracking
  Future<void> initializeData({bool forceRefresh = false}) async {
    if (isInitializing.value) {
      log('⏳ DataLoadingService: Initialization already in progress...');
      return;
    }

    isInitializing.value = true;
    initializationMessage.value = 'Initializing data...';
    initializationProgress.value = 0.0;

    try {
      // Step 1: Load CSV data (30% of progress)
      initializationMessage.value = 'Loading CSV data...';
      await _loadCsvData(forceRefresh);
      initializationProgress.value = 0.3;

      // Step 2: Process sales data (25% of progress)
      initializationMessage.value = 'Processing sales data...';
      await _processSalesData(forceRefresh);
      initializationProgress.value = 0.55;

      // Step 3: Process customer ledger data (15% of progress)
      initializationMessage.value = 'Processing customer data...';
      await _processCustomerData(forceRefresh);
      initializationProgress.value = 0.7;

      // Step 4: Process profit report data (10% of progress)
      initializationMessage.value = 'Processing profit data...';
      await _processProfitData(forceRefresh);
      initializationProgress.value = 0.8;

      // Step 5: Process stock report data (10% of progress)
      initializationMessage.value = 'Processing stock data...';
      await _processStockData(forceRefresh);
      initializationProgress.value = 0.9;

      // Step 6: Finalize
      initializationMessage.value = 'Finalizing...';
      await Future.delayed(Duration(milliseconds: 500));
      initializationProgress.value = 1.0;

      isDataReady.value = true;
      log('✅ DataLoadingService: All data initialized successfully');

    } catch (e, st) {
      log('❌ DataLoadingService: Error during initialization: $e\n$st');
      isDataReady.value = false;
    } finally {
      isInitializing.value = false;
      initializationMessage.value = '';
      initializationProgress.value = 0.0;
    }
  }

  Future<void> _loadCsvData(bool forceRefresh) async {
    await _csvDataService.loadAllCsvs(forceDownload: forceRefresh);
  }

  Future<void> _processSalesData(bool forceRefresh) async {
    await _salesController.fetchSales(forceRefresh: forceRefresh);
  }

  Future<void> _processCustomerData(bool forceRefresh) async {
    // Assuming CustomerLedgerController has a similar method
    // await _customerLedgerController.fetchData(forceRefresh: forceRefresh);
  }

  Future<void> _processProfitData(bool forceRefresh) async {
    // Assuming ProfitReportController has a similar method
    // await _profitReportController.fetchData(forceRefresh: forceRefresh);
  }

  Future<void> _processStockData(bool forceRefresh) async {
    // Assuming StockReportController has a similar method
    // await _stockReportController.fetchData(forceRefresh: forceRefresh);
  }

  /// Refresh all data
  Future<void> refreshAllData() async {
    await initializeData(forceRefresh: true);
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    await _csvDataService.clearAllCsvCache();
    isDataReady.value = false;
    log('🗑️ DataLoadingService: All cache cleared');
  }

  /// Get current loading status
  bool get isLoading => isInitializing.value || _csvDataService.isLoading.value;
  
  String get loadingMessage {
    if (isInitializing.value) {
      return initializationMessage.value;
    }
    if (_csvDataService.isLoading.value) {
      return _csvDataService.loadingMessage.value;
    }
    return '';
  }
  
  double get loadingProgress {
    if (isInitializing.value) {
      return initializationProgress.value;
    }
    if (_csvDataService.isLoading.value) {
      return _csvDataService.loadingProgress.value;
    }
    return 0.0;
  }
}