// lib/controllers/customerLedger_Controller.dart
import 'package:get/get.dart';

import '../constants/paths.dart';              // ➟ holds kSoftAgriBase & helper
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import '../model/account_master_model.dart';
import '../model/allaccounts_model.dart';

class CustomerLedgerController extends GetxController {
  final drive = Get.find<GoogleDriveService>();

  // ──────────────── dynamic 3‑segment Google‑Drive path ────────────────
  late final List<String> _softAgriPath;   // ['SoftAgri_Backups', '<FY>', 'softagri_csv']

  // ──────────────── reactive data stores ───────────────────────────────
  final accounts        = <AccountModel>[].obs;
  final transactions    = <AllAccountsModel>[].obs;
  final customerInfo    = <Map<String, dynamic>>[].obs;

  // outstanding lists
  final debtors         = <Map<String, dynamic>>[].obs; // >0  (Dr)
  final creditors       = <Map<String, dynamic>>[].obs; // <0  (Cr)

  // live ledger for single‑name screen
  final filtered        = <AllAccountsModel>[].obs;
  final drTotal         = 0.0.obs;
  final crTotal         = 0.0.obs;

  // status flags
  final isLoading       = false.obs;
  final error           = RxnString();

  // ───────────────────────── lifecycle ──────────────────────────
  @override
  Future<void> onInit() async {
    super.onInit();

    // 1️⃣  build the three‑segment path once per app run
    _softAgriPath = await SoftAgriPath.build(drive);    // helper in constants/paths.dart

    // 2️⃣  load all required csvs
    _load();
  }

  Future<void> loadData() => _load();                   // for RefreshIndicator

  // ───────────────────────── data fetch ─────────────────────────
  Future<void> _load() async {
    try {
      isLoading.value = true;
      error.value     = null;

      // 1️⃣ – resolve dynamic path
      final pathSegments = await SoftAgriPath.build(drive);
      print('[DEBUG] SoftAgriPath → $pathSegments');
      final parent = await drive.folderId(pathSegments);
      print('[DEBUG] parent‑folderId → $parent');

      // 2️⃣ – resolve each CSV file
      Future<String> _id(String file) async {
        final id = await drive.fileId(file, parent);
        print('[DEBUG] $file id → $id');
        return id;
      }

      final accId  = await _id('AccountMaster.csv');
      final txnId  = await _id('AllAccounts.csv');
      final infoId = await _id('CustomerInformation.csv');

      // 3️⃣ – download and parse
      Future<List<Map<String,dynamic>>> _rows(String id, String name) async {
        final csv = await drive.downloadCsv(id);
        final rows = CsvUtils.toMaps(csv);
        print('[DEBUG] $name rows → ${rows.length}');
        return rows;
      }

      accounts.value     = (await _rows(accId,  'AccountMaster'))
          .map(AccountModel.fromMap).toList();

      transactions.value = (await _rows(txnId,  'AllAccounts'))
          .map(AllAccountsModel.fromMap).toList();

      customerInfo.value = await _rows(infoId, 'CustomerInformation');

      _rebuildDebtors();
      _rebuildCreditors();
    } catch (e, st) {
      error.value = e.toString();
      print('[ERROR] $e\n$st');
    } finally {
      isLoading.value = false;
    }
  }


  // ───────────────────── outstanding builders ──────────────────
  void _rebuildDebtors()    => _buildOutstanding(isDebtor: true);   // balance > 0
  void _rebuildCreditors()  => _buildOutstanding(isDebtor: false);  // balance < 0

  void _buildOutstanding({required bool isDebtor}) {
    // quick lookup for mobile / area
    final infoMap = {
      for (final m in customerInfo)
        int.tryParse(m['AccountNumber']?.toString() ?? '0') ?? 0: m
    };

    final out = <Map<String, dynamic>>[];

    for (final acc in accounts) {
      final type = acc.type.toLowerCase();
      if (type != 'customer' && type != 'supplier') continue;

      final bal = transactions
          .where((t) => t.accountCode == acc.accountNumber)
          .fold<double>(0, (p, t) => p + (t.isDr ? t.amount : -t.amount));

      if (isDebtor && bal <= 0) continue;   // need positive for debtors
      if (!isDebtor && bal >= 0) continue;  // need negative for creditors

      final info = infoMap[acc.accountNumber];

      out.add({
        'accountNumber'  : acc.accountNumber,
        'name'           : acc.accountName,
        'type'           : acc.type,
        'openingBalance' : acc.openingBalance,
        'closingBalance' : bal.abs(),               // always positive for UI
        'drCr'           : isDebtor ? 'Dr' : 'Cr',
        'mobile'         : info?['Mobile'] ?? '-',
        'area'           : info?['Area']   ?? '-',
      });
    }

    isDebtor ? debtors(out) : creditors(out);
  }

  // ───────────────────── existing ledger helpers ─────────────────
  void filterByName(String name) {
    final acc = accounts.firstWhereOrNull(
          (a) => a.accountName.toLowerCase() == name.toLowerCase(),
    );
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
    drTotal(dr);
    crTotal(cr);
  }

  void clearFilter() {
    filtered.clear();
    drTotal(0);
    crTotal(0);
  }
}
