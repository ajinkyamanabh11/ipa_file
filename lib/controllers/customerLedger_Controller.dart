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
  final CsvDataService _csvDataService = Get.find<CsvDataService>(); // NEW: Get CsvDataService instance

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
    log('[CustomerLedgerController] Initializing customer ledger controller (lazy loading - no automatic data load)');
    // Removed automatic data loading - data will be loaded when loadCustomerLedger() is called
    // await loadCustomerLedger(); // REMOVED - implementing lazy loading
  }

  /// Public method to load customer ledger data.
  Future<void> loadCustomerLedger({bool forceRefreshCsv = false}) async {
    log('[CustomerLedgerController] Loading customer ledger data...');
    isLoading.value = true;
    error.value = null;

    try {
      // Load only customer/supplier and account data on demand
      await _csvDataService.loadCustomerSupplierData(forceDownload: forceRefreshCsv);
      await _csvDataService.loadAccountData(forceDownload: forceRefreshCsv);

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

  // refreshDebtors will now force a refresh of the underlying CSVs
  Future<void> refreshDebtors() async => loadCustomerLedger(forceRefreshCsv: true);
  Future<void> loadData() => loadCustomerLedger();

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