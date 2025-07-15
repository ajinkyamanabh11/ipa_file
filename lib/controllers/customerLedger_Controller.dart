// lib/controllers/customerLedger_Controller.dart
import 'package:get/get.dart';
import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import '../model/account_master_model.dart';
import '../model/allaccounts_model.dart';

class CustomerLedgerController extends GetxController {
  final drive = Get.find<GoogleDriveService>();

  // ─── csv data ──────────────────────────────────────────────────────────
  final accounts     = <AccountModel>[].obs;
  final transactions = <AllAccountsModel>[].obs;
  final customerInfo = <Map<String, dynamic>>[].obs;

  // ─── debtor / creditor lists ───────────────────────────────────────────
  final debtors      = <Map<String, dynamic>>[].obs;
  final creditors    = <Map<String, dynamic>>[].obs;        // 🔹 NEW

  // ─── ledger‑by‑name (existing) ─────────────────────────────────────────
  final filtered = <AllAccountsModel>[].obs;
  final drTotal  = 0.0.obs;
  final crTotal  = 0.0.obs;

  // simple flags
  final isLoading = false.obs;
  final error     = RxnString();

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> loadData() => _load();

  //─────────────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    try {
      isLoading.value = true;
      error.value     = null;

      final parent  = await drive.folderId(kSoftAgriPath);
      final accId   = await drive.fileId('AccountMaster.csv',      parent);
      final txnId   = await drive.fileId('AllAccounts.csv',        parent);
      final infoId  = await drive.fileId('CustomerInformation.csv', parent);

      accounts.value = CsvUtils.toMaps(await drive.downloadCsv(accId))
          .map(AccountModel.fromMap)
          .toList();

      transactions.value = CsvUtils.toMaps(await drive.downloadCsv(txnId))
          .map(AllAccountsModel.fromMap)
          .toList();

      customerInfo.value = CsvUtils.toMaps(await drive.downloadCsv(infoId));

      _rebuildDebtors();   // >0  (Dr)
      _rebuildCreditors(); // 🔹 <0  (Cr)
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  //─────────────────────────────────────────────────────────────────────────
  void _rebuildDebtors() => _buildOutstanding(isDebtor: true);   // >0
  void _rebuildCreditors() => _buildOutstanding(isDebtor: false); // 🔹 <0

  void _buildOutstanding({required bool isDebtor}) {
    final infoMap = {
      for (final m in customerInfo)
        int.tryParse(m['AccountNumber']?.toString() ?? '0') ?? 0: m
    };

    final list = <Map<String, dynamic>>[];

    for (final acc in accounts) {
      final type = acc.type.toLowerCase();
      if (type != 'customer' && type != 'supplier') continue;

      final bal = transactions
          .where((t) => t.accountCode == acc.accountNumber)
          .fold<double>(0, (p, t) => p + (t.isDr ? t.amount : -t.amount));

      if (isDebtor && bal <= 0) continue; // need >0
      if (!isDebtor && bal >= 0) continue; // need <0

      final info = infoMap[acc.accountNumber];

      list.add({
        'accountNumber'  : acc.accountNumber,
        'name'           : acc.accountName,
        'type'           : acc.type,
        'openingBalance' : acc.openingBalance,
        'closingBalance' : bal.abs(),              // always positive for UI
        'drCr'           : isDebtor ? 'Dr' : 'Cr',
        'mobile'         : info?['Mobile'] ?? '-',
        'area'           : info?['Area']   ?? '-',
      });
    }

    isDebtor ? debtors(list) : creditors(list);    // 🔹
  }

  //────────────────── (ledger‑by‑name helpers unchanged) ──────────────────
  void filterByName(String name) { /* … existing code … */ }
  void clearFilter()            { /* … existing code … */ }
}
