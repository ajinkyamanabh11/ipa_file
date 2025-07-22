// lib/controllers/customer_ledger_controller.dart
import 'dart:developer';

import 'package:get/get.dart';

import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';

// typed rows
import '../model/account_master_model.dart';
import '../model/allaccounts_model.dart';
import 'google_signin_controller.dart';

class CustomerLedgerController extends GetxController {
  final GoogleDriveService drive = Get.find<GoogleDriveService>();
  final GoogleSignInController _googleSignInController = Get.find<GoogleSignInController>(); // Get instance

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
  final requiresSignIn = false.obs; // New flag to indicate sign-in is required

  late final List<String> _softAgriPath;


  // ───────────── life‑cycle ─────────────
  @override
  Future<void> onInit() async {
    super.onInit();
    // Listen to sign-in status changes
    _googleSignInController.user.listen((account) {
      if (account != null) {
        requiresSignIn(false); // User is signed in
        _load(); // Reload data if signed in after being signed out
      } else {
        // If user becomes null, and we were previously loading data, it means sign-out happened
        // or silent sign-in failed. Mark as requiring sign-in.
        if (!isLoading.value) { // Only set if not already in a loading state trying to sign in
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

    // Initialize path, but only attempt data load if user is already signed in
    _softAgriPath = await SoftAgriPath.build(drive);

    // Initial load attempt based on current sign-in status
    if (_googleSignInController.isSignedIn) {
      _load();
    } else {
      requiresSignIn(true);
      error.value = 'Please sign in to your Google Account to load data.';
    }
  }

  Future<void> refreshDebtors() async => _load(silent: true);
  Future<void> loadData() => _load();

  // ───────────── loader ─────────────
  Future<void> _load({bool silent = false}) async {
    if (!_googleSignInController.isSignedIn) {
      // If not signed in, don't even try to load data
      error.value = 'Google Sign-In is required to access data.';
      requiresSignIn(true);
      return;
    }

    try {
      if (!silent) isLoading(true); // Only show full loader if not silent refresh
      error.value = null;
      requiresSignIn(false); // Reset sign-in required flag

      final parentId = await drive.folderId(_softAgriPath);
      if (parentId == null) {
        // This means _api() in GoogleDriveService returned null due to no auth
        error.value = 'Google Sign-In is required to access Google Drive.';
        requiresSignIn(true);
        return;
      }

      Map<String, dynamic> _lc(Map<String, dynamic> row) => {
        for (final e in row.entries)
          e.key.toString().trim().toLowerCase(): e.value
      };
      Future<List<Map<String, dynamic>>> _csv(String file) async {
        final id = await drive.fileId(file, parentId);
        if (id == null) {
          // This should ideally not happen if parentId was not null, but good to check
          throw Exception('Could not find file ID for $file. Sign-in issue?');
        }
        final csv = await drive.downloadCsv(id);
        if (csv == null) {
          // This should ideally not happen if id was not null, but good to check
          throw Exception('Could not download CSV for $file. Sign-in issue?');
        }
        return CsvUtils.toMaps(csv).map(_lc).toList();
      }

      accounts.value = (await _csv('AccountMaster.csv'))
          .map(AccountModel.fromMap).toList();
      transactions.value = (await _csv('AllAccounts.csv'))
          .map(AllAccountsModel.fromMap).toList();
      customerInfo.value = await _csv('CustomerInformation.csv');
      supplierInfo.value = await _csv('SupplierInformation.csv');

      _rebuildOutstanding();
    } catch (e, st) {
      error.value = e.toString();
      log('[CustomerLedgerController] Error loading data: $e\n$st');
      if (e.toString().contains('Google Sign-In required') ||
          e.toString().contains('oauth2_not_granted') ||
          e.toString().contains('sign_in_failed')) { // Catch specific Google Sign-in related errors
        requiresSignIn(true);
        error.value = 'Google Sign-In is required to access data.';
      }
    } finally {
      isLoading(false);
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
        'area'          : _pickadress(infoRow),
        'mobile'        : _pickPhone(infoRow),
        'drCr'          : bal > 0 ? 'Dr' : 'Cr',
      };

      (bal > 0 ? drTmp : crTmp).add(row);
    }

    debtors  (drTmp);
    creditors(crTmp);
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
  String _pickadress(Map<String,dynamic>?row){
    if(row==null)return'';
    const Keys=[
      'area', 'address1' ,'address'
    ];
    for(final k in Keys){
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
  }

  void clearFilter() {
    filtered.clear();
    drTotal(0);
    crTotal(0);
  }
}
