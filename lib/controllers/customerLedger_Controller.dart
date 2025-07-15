// lib/controllers/customerLedger_Controller.dart
import 'package:get/get.dart';
import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import '../model/account_master_model.dart';
import '../model/allaccounts_model.dart';

class CustomerLedgerController extends GetxController {
  final drive = Get.find<GoogleDriveService>();

  // ─── source csv data ─────────────────────────────────────────
  final accounts        = <AccountModel>[].obs;            // AccountMaster
  final transactions    = <AllAccountsModel>[].obs;        // AllAccounts
  final customerInfo    = <Map<String, dynamic>>[].obs;    // CustomerInformation

  // ─── ledger‑by‑name (existing feature) ───────────────────────
  final filtered        = <AllAccountsModel>[].obs;
  final drTotal         = 0.0.obs;
  final crTotal         = 0.0.obs;

  // ─── NEW: debtors (>0) list ─────────────────────────────────
  final debtors         = <Map<String, dynamic>>[].obs;

  // simple loading/error flags
  final isLoading       = false.obs;
  final error           = RxnString();

  @override
  void onInit() {
    super.onInit();
    _load();                      // start fetch immediately
  }

  Future<void> loadData() => _load();   // for RefreshIndicator

  //─────────────────────────────────────────────────────────────
  Future<void> _load() async {
    try {
      isLoading.value = true;
      error.value     = null;

      final parent   = await drive.folderId(kSoftAgriPath);
      final accId    = await drive.fileId('AccountMaster.csv',      parent);
      final txnId    = await drive.fileId('AllAccounts.csv',        parent);
      final infoId   = await drive.fileId('CustomerInformation.csv', parent);

      accounts.value = CsvUtils
          .toMaps(await drive.downloadCsv(accId))
          .map(AccountModel.fromMap)
          .toList();

      transactions.value = CsvUtils
          .toMaps(await drive.downloadCsv(txnId))
          .map(AllAccountsModel.fromMap)
          .toList();

      customerInfo.value = CsvUtils.toMaps(await drive.downloadCsv(infoId));

      _rebuildDebtors();      // ← compute once csvs are in
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  //─────────────────────────────────────────────────────────────
  //  OLD LEDGER FILTER FEATURE (unchanged)
  //─────────────────────────────────────────────────────────────
  void filterByName(String name) {
    final acc = accounts.firstWhereOrNull(
            (a) => a.accountName.toLowerCase() == name.toLowerCase());

    if (acc == null) {
      filtered.clear();
      drTotal(0); crTotal(0);
      return;
    }

    filtered.value = transactions
        .where((t) => t.accountCode == acc.accountNumber)
        .toList();

    double dr = 0, cr = 0;
    for (final t in filtered) {
      t.isDr ? dr += t.amount : cr += t.amount;
    }
    drTotal(dr); crTotal(cr);
  }

  void clearFilter() {
    filtered.clear();
    drTotal(0); crTotal(0);
  }

  //─────────────────────────────────────────────────────────────
  //  NEW: build debtors list
  //─────────────────────────────────────────────────────────────
  // ── NEW: build debtors list ───────────────────────────────────────────
  void _rebuildDebtors() {
    // 1️⃣ build a fast lookup keyed by account number
    final infoMap = {
      for (final m in customerInfo)
        int.tryParse(m['accountnumber']?.toString() ?? '0') ?? 0: m
    };

    final List<Map<String, dynamic>> list = [];

    for (final acc in accounts) {
      final type = acc.type.toLowerCase();
      if (type != 'customer' && type != 'supplier') continue;

      // net balance
      final bal = transactions
          .where((t) => t.accountCode == acc.accountNumber)
          .fold<double>(0, (p, t) => p + (t.isDr ? t.amount : -t.amount));

      if (bal <= 0) continue; // show only debtors (Dr)

      final info = infoMap[acc.accountNumber];

      list.add({
        'accountNumber'  : acc.accountNumber,
        'name'           : acc.accountName,
        'type'           : acc.type,
        'openingBalance' : acc.openingBalance,
        'closingBalance' : bal,
        'drCr'           : 'Dr',
        // ✅  use the exact lowercase keys from the CSV
        'mobile'         : info?['mobileno'] ?? info?['phoneno'] ?? '-',
        'area'           : info?['area'] ?? '-',
      });
    }

    debtors.value = list;
  }

}
