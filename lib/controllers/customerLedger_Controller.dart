// lib/controllers/customer_ledger_controller.dart
import 'dart:developer';

import 'package:get/get.dart';

import '../constants/paths.dart';
import '../services/CsvDataServices.dart';
import '../services/background_processor.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
// NEW IMPORT for CsvDataService
import '../services/background_processor.dart';

// typed rows
import '../model/account_master_model.dart';
import '../model/allaccounts_model.dart';
import 'google_signin_controller.dart';

class CustomerLedgerController extends GetxController {
  final GoogleDriveService drive = Get.find<GoogleDriveService>();
  final GoogleSignInController _googleSignInController = Get.find<GoogleSignInController>();
  final CsvDataService _csvDataService = Get.find<CsvDataService>(); // NEW: Get CsvDataService instance
  final BackgroundProcessor _backgroundProcessor = Get.find<BackgroundProcessor>(); // ADD THIS LINE

  // ───────────── reactive stores ─────────────
  final accounts = <AccountModel>[].obs;
  final transactions = <AllAccountsModel>[].obs;

  final customerInfo = <Map<String, dynamic>>[].obs;
  final supplierInfo = <Map<String, dynamic>>[].obs;

  final debtors = <Map<String, dynamic>>[].obs;
  final creditors = <Map<String, dynamic>>[].obs;

  final filtered = <AllAccountsModel>[].obs;
  final drTotal = 0.0.obs;
  final crTotal = 0.0.obs;

  // status flags
  final isLoading = false.obs;
  final error = RxnString();
  final requiresSignIn = false.obs;

  // Performance optimization flags
  final isProcessingData = false.obs;
  final dataProcessingProgress = 0.0.obs;

  // Pagination support
  final currentPage = 0.obs;
  final pageSize = 50; // Show 50 items per page
  final hasMoreDebtors = true.obs;
  final hasMoreCreditors = true.obs;

  // Cached processed data
  final List<Map<String, dynamic>> _allDebtors = [];
  final List<Map<String, dynamic>> _allCreditors = [];

  // Memory management
  final isMemoryOptimized = false.obs;

  // No longer need _softAgriPath here, as CsvDataService manages the file fetching.
  // late final List<String> _softAgriPath;


  // ───────────── life‑cycle ─────────────
  @override
  Future<void> onInit() async {
    super.onInit();
    // Listen to sign-in status changes
    _googleSignInController.user.listen((account) {
      if (account != null) {
        log('👤 CustomerLedgerController: Google user signed in. Loading data...');
        requiresSignIn(false);
        _load(); // Reload data if signed in after being signed out
      } else {
        log('👤 CustomerLedgerController: Google user signed out.');
        if (!isLoading.value) {
          requiresSignIn(true);
          error.value = 'Google Sign-In is required to access data.';
          // Clear existing data when sign-out/failure occurs
          _clearAllData();
        }
      }
    });

    // Initial load attempt based on current sign-in status
    // Now just trigger a load, CsvDataService will handle initial download/cache logic
    if (_googleSignInController.isSignedIn) {
      log('👤 CustomerLedgerController: Already signed in on init. Loading data...');
      _load();
    } else {
      log('👤 CustomerLedgerController: Not signed in on init. Awaiting sign-in.');
      requiresSignIn(true);
      error.value = 'Please sign in to your Google Account to load data.';
    }
  }

  void _clearAllData() {
    accounts.clear();
    transactions.clear();
    customerInfo.clear();
    supplierInfo.clear();
    debtors.clear();
    creditors.clear();
    _allDebtors.clear();
    _allCreditors.clear();
    currentPage.value = 0;
    hasMoreDebtors.value = true;
    hasMoreCreditors.value = true;
  }

  // refreshDebtors will now force a refresh of the underlying CSVs
  Future<void> refreshDebtors() async => _load(silent: true, forceRefreshCsv: true);
  Future<void> loadData() => _load();

  // Load more debtors for pagination
  void loadMoreDebtors() {
    if (!hasMoreDebtors.value) return;

    final nextPage = currentPage.value + 1;
    final startIndex = nextPage * pageSize;
    final endIndex = startIndex + pageSize;

    if (startIndex >= _allDebtors.length) {
      hasMoreDebtors.value = false;
      return;
    }

    final moreItems = _allDebtors.skip(startIndex).take(pageSize).toList();
    debtors.addAll(moreItems);
    currentPage.value = nextPage;

    if (endIndex >= _allDebtors.length) {
      hasMoreDebtors.value = false;
    }
  }

  // Load more creditors for pagination
  void loadMoreCreditors() {
    if (!hasMoreCreditors.value) return;

    final nextPage = currentPage.value + 1;
    final startIndex = nextPage * pageSize;
    final endIndex = startIndex + pageSize;

    if (startIndex >= _allCreditors.length) {
      hasMoreCreditors.value = false;
      return;
    }

    final moreItems = _allCreditors.skip(startIndex).take(pageSize).toList();
    creditors.addAll(moreItems);
    currentPage.value = nextPage;

    if (endIndex >= _allCreditors.length) {
      hasMoreCreditors.value = false;
    }
  }

  // ───────────── loader ─────────────
  Future<void> _load({bool silent = false, bool forceRefreshCsv = false}) async {
    if (!_googleSignInController.isSignedIn) {
      log('🚫 CustomerLedgerController: Not signed in. Cannot load data.');
      error.value = 'Google Sign-In is required to access data.';
      requiresSignIn(true);
      return;
    }

    try {
      if (!silent) isLoading(true);
      error.value = null;
      requiresSignIn(false);

      await _csvDataService.loadAllCsvs(forceDownload: forceRefreshCsv);

      // CRITICAL CHANGE: Offload processing to background isolate
      isProcessingData(true);
      final results = await _backgroundProcessor.addTask(BackgroundTask(
        name: 'Processing Ledger Data',
        operation: 'process_ledger',
        data: {
          'accountsCsv': _csvDataService.accountMasterCsv.value,
          'transactionsCsv': _csvDataService.allAccountsCsv.value,
          'customerInfoCsv': _csvDataService.customerInfoCsv.value,
          'supplierInfoCsv': _csvDataService.supplierInfoCsv.value,
        },
        onProgress: (progressValue) => dataProcessingProgress(progressValue),
      ));

      // Update reactive stores with processed data from the isolate
      accounts.value = results['accounts'];
      transactions.value = results['transactions'];
      customerInfo.value = results['customerInfo'];
      supplierInfo.value = results['supplierInfo'];
      _allDebtors.addAll(results['allDebtors']);
      _allCreditors.addAll(results['allCreditors']);

      _loadInitialPages();

      log('✅ CustomerLedgerController: Data loaded and outstanding balances rebuilt.');

    }  catch (e, st) {
      log('[CustomerLedgerController] ❌ Error loading data: $e\n$st');
      error.value = e.toString();
      // Keep specific sign-in error handling here
      if (e.toString().contains('Google Sign-In required') ||
          e.toString().contains('oauth2_not_granted') ||
          e.toString().contains('sign_in_failed')) {
        requiresSignIn(true);
        error.value = 'Google Sign-In is required to access data.';
      } else {
        // Clear data on general errors too
        _clearAllData();
      }
    } finally {

      isLoading(false);
      isProcessingData(false);
      log('CustomerLedgerController: Loading finished. isLoading: ${isLoading.value}');
    }
  }

  // Process data in background with progress updates
  Future<void> _processDataInBackground() async {
    isProcessingData.value = true;
    dataProcessingProgress.value = 0.0;

    try {
      // Process data in chunks to avoid blocking UI
      await _processAccountsInChunks();
      dataProcessingProgress.value = 0.25;

      await _processTransactionsInChunks();
      dataProcessingProgress.value = 0.5;

      await _processCustomerInfoInChunks();
      dataProcessingProgress.value = 0.75;

      await _rebuildOutstandingOptimized();
      dataProcessingProgress.value = 1.0;

    } finally {
      isProcessingData.value = false;
    }
  }

  Future<void> _processAccountsInChunks() async {
    final csvData = _csvDataService.accountMasterCsv.value;
    if (csvData.isEmpty) return;

    Map<String, dynamic> _lc(Map<String, dynamic> row) => {
      for (final e in row.entries)
        e.key.toString().trim().toLowerCase(): e.value
    };

    // Process in smaller chunks to avoid blocking
    final allMaps = CsvUtils.toMaps(csvData);
    const chunkSize = 100;
    final List<AccountModel> processedAccounts = [];

    for (int i = 0; i < allMaps.length; i += chunkSize) {
      final chunk = allMaps.skip(i).take(chunkSize).toList();
      final processedChunk = chunk
          .map(_lc)
          .map(AccountModel.fromMap)
          .toList();

      processedAccounts.addAll(processedChunk);

      // Allow UI to update
      await Future.delayed(Duration(milliseconds: 1));
    }

    accounts.value = processedAccounts;
  }

  Future<void> _processTransactionsInChunks() async {
    final csvData = _csvDataService.allAccountsCsv.value;
    if (csvData.isEmpty) return;

    Map<String, dynamic> _lc(Map<String, dynamic> row) => {
      for (final e in row.entries)
        e.key.toString().trim().toLowerCase(): e.value
    };

    // Process in smaller chunks
    final allMaps = CsvUtils.toMaps(csvData);
    const chunkSize = 100;
    final List<AllAccountsModel> processedTransactions = [];

    for (int i = 0; i < allMaps.length; i += chunkSize) {
      final chunk = allMaps.skip(i).take(chunkSize).toList();
      final processedChunk = chunk
          .map(_lc)
          .map(AllAccountsModel.fromMap)
          .toList();

      processedTransactions.addAll(processedChunk);

      // Allow UI to update
      await Future.delayed(Duration(milliseconds: 1));
    }

    transactions.value = processedTransactions;
  }

  Future<void> _processCustomerInfoInChunks() async {
    Map<String, dynamic> _lc(Map<String, dynamic> row) => {
      for (final e in row.entries)
        e.key.toString().trim().toLowerCase(): e.value
    };

    // Process customer info
    final customerCsv = _csvDataService.customerInfoCsv.value;
    if (customerCsv.isNotEmpty) {
      final customerMaps = CsvUtils.toMaps(customerCsv);
      customerInfo.value = customerMaps.map(_lc).toList();
    }

    // Process supplier info
    final supplierCsv = _csvDataService.supplierInfoCsv.value;
    if (supplierCsv.isNotEmpty) {
      final supplierMaps = CsvUtils.toMaps(supplierCsv);
      supplierInfo.value = supplierMaps.map(_lc).toList();
    }
  }

  // ───────────── optimized outstanding lists ─────────────
  Future<void> _rebuildOutstandingOptimized() async {
    // Clear previous data
    _allDebtors.clear();
    _allCreditors.clear();
    debtors.clear();
    creditors.clear();

    // two quick look‑up maps
    final custMap = {
      for (final r in customerInfo)
        int.tryParse(r['accountnumber']?.toString() ?? '0') ?? 0: r
    };
    final supMap = {
      for (final r in supplierInfo)
        int.tryParse(r['accountnumber']?.toString() ?? '0') ?? 0: r
    };

    // Process accounts in batches to avoid blocking UI
    const batchSize = 50;
    for (int i = 0; i < accounts.length; i += batchSize) {
      final batch = accounts.skip(i).take(batchSize).toList();

      for (final acc in batch) {
        final isCust = acc.type.toLowerCase() == 'customer';
        final isSupp = acc.type.toLowerCase() == 'supplier';
        if (!isCust && !isSupp) continue;

        // Calculate balance efficiently
        final accountTransactions = transactions
            .where((t) => t.accountCode == acc.accountNumber)
            .toList();

        if (accountTransactions.isEmpty) continue;

        final bal = accountTransactions
            .fold<double>(0, (p, t) => p + (t.isDr ? t.amount : -t.amount));

        if (bal == 0) continue;

        // pick info from correct table
        final infoRow = isCust ? custMap[acc.accountNumber] : supMap[acc.accountNumber];

        final row = {
          'accountNumber': acc.accountNumber,
          'name': acc.accountName,
          'type': acc.type,
          'closingBalance': bal.abs(),
          'area': _pickAddress(infoRow),
          'mobile': _pickPhone(infoRow),
          'drCr': bal > 0 ? 'Dr' : 'Cr',
        };

        if (bal > 0) {
          _allDebtors.add(row);
        } else {
          _allCreditors.add(row);
        }
      }

      // Allow UI to update between batches
      await Future.delayed(Duration(milliseconds: 5));
    }

    // Sort the complete lists
    _allDebtors.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    _allCreditors.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

    // Load first page
    _loadInitialPages();

    log('CustomerLedgerController: Total Debtors: ${_allDebtors.length}, Total Creditors: ${_allCreditors.length}');
  }

  void _loadInitialPages() {
    // Reset pagination
    currentPage.value = 0;
    hasMoreDebtors.value = _allDebtors.length > pageSize;
    hasMoreCreditors.value = _allCreditors.length > pageSize;

    // Load initial pages
    debtors.value = _allDebtors.take(pageSize).toList();
    creditors.value = _allCreditors.take(pageSize).toList();
  }

  /// find first non‑empty phone / mobile column (many exports differ)
  String _pickPhone(Map<String, dynamic>? row) {
    if (row == null) return '-';
    const keys = [
      'mobile', 'mobileno', 'mobile no',
      'phone',  'phoneno',  'phone no',
      'mobile_number', 'phone_number'
    ];
    for (final k in keys) {
      final v = row[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '-';
  }
  // Renamed _pickadress to _pickAddress for consistency and clarity
  String _pickAddress(Map<String,dynamic>?row){
    if(row==null)return'';
    const keys=[ // Corrected to `keys` from `Keys`
      'area', 'address1' ,'address'
    ];
    for(final k in keys){
      final v=row[k];
      if (v!=null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '';
  }

  // ───────────── old single‑name ledger helpers ─────────────
  void filterByName(String name) {
    final acc = accounts.firstWhereOrNull(
            (a) => a.accountName.toLowerCase() == name.toLowerCase());
    if (acc == null) {
      filtered.clear();
      drTotal(0);
      crTotal(0);
      return;
    }

    // Use more efficient filtering
    final accountTransactions = transactions
        .where((t) => t.accountCode == acc.accountNumber)
        .toList();

    filtered.value = accountTransactions;

    double dr = 0, cr = 0;
    for (final t in accountTransactions) {
      t.isDr ? dr += t.amount : cr += t.amount;
    }
    drTotal(dr);
    crTotal(cr);
    log('CustomerLedgerController: Filtered by name "$name". Dr: $drTotal, Cr: $crTotal');
  }

  void clearFilter() {
    filtered.clear();
    drTotal(0);
    crTotal(0);
    log('CustomerLedgerController: Filter cleared.');
  }

  // Memory optimization methods
  void optimizeMemory() {
    if (isMemoryOptimized.value) return;

    // Clear non-essential data when memory is constrained
    if (_allDebtors.length > 1000 || _allCreditors.length > 1000) {
      // Keep only currently displayed items
      final currentDebtors = List<Map<String, dynamic>>.from(debtors);
      final currentCreditors = List<Map<String, dynamic>>.from(creditors);

      _allDebtors.clear();
      _allCreditors.clear();

      debtors.value = currentDebtors;
      creditors.value = currentCreditors;

      isMemoryOptimized.value = true;
      log('CustomerLedgerController: Memory optimized - cached data cleared');
    }
  }

  void resetMemoryOptimization() {
    if (!isMemoryOptimized.value) return;

    // Rebuild data if memory optimization was applied
    isMemoryOptimized.value = false;
    _rebuildOutstandingOptimized();
  }
}