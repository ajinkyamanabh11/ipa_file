// lib/controllers/customer_ledger_controller.dart
import 'dart:developer';

import 'package:get/get.dart';

import '../constants/paths.dart';
import '../services/CsvDataServices.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
 // NEW IMPORT for CsvDataService

// typed rows
import '../model/account_master_model.dart';
import '../model/allaccounts_model.dart';
import 'google_signin_controller.dart';

class CustomerLedgerController extends GetxController {
  final GoogleDriveService drive = Get.find<GoogleDriveService>();
  final GoogleSignInController _googleSignInController = Get.find<GoogleSignInController>();
  late final CsvDataService _csvDataService ; // NEW: Get CsvDataService instance

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

  // No longer need _softAgriPath here, as CsvDataService manages the file fetching.
  // late final List<String> _softAgriPath;


  // ───────────── life‑cycle ─────────────
  @override
  Future<void> onInit() async {
    super.onInit();
    // Initialize CSV data service lazily
    _csvDataService = Get.find<CsvDataService>();
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
          accounts.clear();
          transactions.clear();
          customerInfo.clear();
          supplierInfo.clear();
          debtors.clear();
          creditors.clear();
        }
      }
    });

    // Initial load attempt based on current sign-in status
    // Don't load data immediately to improve startup performance
    if (_googleSignInController.isSignedIn) {
      log('👤 CustomerLedgerController: Already signed in on init. Data will be loaded on demand.');
      requiresSignIn(false);
    } else {
      log('👤 CustomerLedgerController: Not signed in on init. Awaiting sign-in.');
      requiresSignIn(true);
      error.value = 'Please sign in to your Google Account to load data.';
    }
  }

  // refreshDebtors will now force a refresh of the underlying CSVs
  Future<void> refreshDebtors() async => _load(silent: true, forceRefreshCsv: true);
  // Add method for refreshing creditors specifically
  Future<void> refreshCreditors() async => _load(silent: true, forceRefreshCsv: true);

  // Add method to ensure data is loaded when screens are accessed
  Future<void> ensureDataLoaded() async {
    // If we have no data at all, trigger a load
    if (accounts.isEmpty && transactions.isEmpty &&
        customerInfo.isEmpty && supplierInfo.isEmpty) {
      await _load();
    }
  }
  Future<void> loadData() => _load();

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

      // 🔴 CRITICAL CHANGE: Load all necessary CSVs via CsvDataService
      await _csvDataService.loadAllCsvs(forceDownload: forceRefreshCsv);

      // Check if the necessary CSVs from CsvDataService are available
      if (_csvDataService.accountMasterCsv.value.isEmpty ||
          _csvDataService.allAccountsCsv.value.isEmpty ||
          _csvDataService.customerInfoCsv.value.isEmpty ||
          _csvDataService.supplierInfoCsv.value.isEmpty)
      {
        log('⚠️ CustomerLedgerController: Required CSV data missing after CsvDataService load.');
        // This might indicate a network issue or Google Drive permission problem
        // that CsvDataService couldn't fully resolve.
        error.value = 'Failed to load essential ledger data. Please check your internet connection or Google Drive permissions.';
        // Don't set requiresSignIn unless specifically a sign-in error propagated
        return; // Exit if data isn't available
      }


      Map<String, dynamic> _lc(Map<String, dynamic> row) => {
        for (final e in row.entries)
          e.key.toString().trim().toLowerCase(): e.value
      };

      // Populate controller's data from CsvDataService's reactive properties
      accounts.value = CsvUtils.toMaps(_csvDataService.accountMasterCsv.value)
          .map(_lc) // Apply lowercase keys conversion
          .map(AccountModel.fromMap)
          .toList();

      transactions.value = CsvUtils.toMaps(_csvDataService.allAccountsCsv.value)
          .map(_lc) // Apply lowercase keys conversion
          .map(AllAccountsModel.fromMap)
          .toList();

      customerInfo.value = CsvUtils.toMaps(_csvDataService.customerInfoCsv.value)
          .map(_lc) // Apply lowercase keys conversion
          .toList();

      supplierInfo.value = CsvUtils.toMaps(_csvDataService.supplierInfoCsv.value)
          .map(_lc) // Apply lowercase keys conversion
          .toList();

      _rebuildOutstanding();
      log('✅ CustomerLedgerController: Data loaded and outstanding balances rebuilt.');

    } catch (e, st) {
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
        accounts.clear();
        transactions.clear();
        customerInfo.clear();
        supplierInfo.clear();
        debtors.clear();
        creditors.clear();
      }
    } finally {
      isLoading(false);
      log('CustomerLedgerController: Loading finished. isLoading: ${isLoading.value}');
    }
  }

  // ───────────── outstanding lists ─────────────
  void _rebuildOutstanding() {
    // two quick look‑up maps
    final custMap = {
      for (final r in customerInfo)
        int.tryParse(r['accountnumber']?.toString() ?? '0') ?? 0: r
    };
    final supMap = {
      for (final r in supplierInfo)
        int.tryParse(r['accountnumber']?.toString() ?? '0') ?? 0: r
    };

    final List<Map<String, dynamic>> drTmp = [];
    final List<Map<String, dynamic>> crTmp = [];

    for (final acc in accounts) {
      final isCust = acc.type.toLowerCase() == 'customer';
      final isSupp = acc.type.toLowerCase() == 'supplier';
      if (!isCust && !isSupp) continue;

      // net balance
      final bal = transactions
          .where((t) => t.accountCode == acc.accountNumber)
          .fold<double>(0,
              (p, t) => p + (t.isDr ? t.amount : -t.amount)); // +Dr, −Cr
      if (bal == 0) continue;

      // pick info from correct table
      final infoRow = isCust ? custMap[acc.accountNumber]
          : supMap [acc.accountNumber];

      final row = {
        'accountNumber' : acc.accountNumber,
        'name'          : acc.accountName,
        'type'          : acc.type,
        'closingBalance': bal.abs(),
        'area'          : _pickAddress(infoRow), // Corrected call
        'mobile'        : _pickPhone(infoRow),
        'drCr'          : bal > 0 ? 'Dr' : 'Cr',
      };

      (bal > 0 ? drTmp : crTmp).add(row);
    }

    debtors(drTmp);
    creditors(crTmp);
    log('CustomerLedgerController: Debtors: ${debtors.length}, Creditors: ${creditors.length}');
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

    filtered.value = transactions
        .where((t) => t.accountCode == acc.accountNumber)
        .toList();

    double dr = 0, cr = 0;
    for (final t in filtered) t.isDr ? dr += t.amount : cr += t.amount;
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
}