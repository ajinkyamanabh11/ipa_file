// lib/controllers/customer_ledger_controller.dart
import 'package:get/get.dart';

import '../constants/paths.dart';              // ➜ SoftAgriPath helper
import '../model/CustomerInfoModel.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';

// models
import '../model/account_master_model.dart';
import '../model/allaccounts_model.dart';


class CustomerLedgerController extends GetxController {
  final drive = Get.find<GoogleDriveService>();

  // ────────────────────────────────────────────────────────────
  //  Reactive stores
  // ────────────────────────────────────────────────────────────
  final accounts     = <AccountModel>[].obs;
  final transactions = <AllAccountsModel>[].obs;
  final customerInfo = <CustomerInfoModel>[].obs;

  final debtors      = <Map<String, dynamic>>[].obs;   // balance > 0 (Dr)
  final creditors    = <Map<String, dynamic>>[].obs;   // balance < 0 (Cr)

  // ledger‑by‑name screen
  final filtered     = <AllAccountsModel>[].obs;
  final drTotal      = 0.0.obs;
  final crTotal      = 0.0.obs;

  // status
  final isLoading = false.obs;
  final error     = RxnString();

  // store the dynamic 3‑segment Drive path once
  late final List<String> _softAgriPath;

  // ──────────────────── lifecycle ─────────────────────────────
  @override
  Future<void> onInit() async {
    super.onInit();
    _softAgriPath = await SoftAgriPath.build(drive);
    _load();                                          // first pull
  }

  Future<void> loadData() => _load();                 // pull‑to‑refresh

  // ──────────────────── loader ───────────────────────────────
  Future<void> _load() async {
    try {
      isLoading(true);
      error.value = null;

      final parentId = await drive.folderId(_softAgriPath);

      // helpers ------------------------------------------------
      Future<String> _id(String file) => drive.fileId(file, parentId);

      Future<List<Map<String, dynamic>>> _csv(String id) async {
        // lower‑case & trim *all* headers once:
        Map<String, dynamic> _lc(Map<String, dynamic> row) => {
          for (final e in row.entries)
            e.key.toString().trim().toLowerCase(): e.value
        };
        return CsvUtils.toMaps(await drive.downloadCsv(id))
            .map(_lc)
            .toList();
      }
      // --------------------------------------------------------

      final accRows  = await _csv(await _id('AccountMaster.csv'));
      final txnRows  = await _csv(await _id('AllAccounts.csv'));
      final infoRows = await _csv(await _id('CustomerInformation.csv'));

      accounts.value     = accRows.map(AccountModel.fromMap).toList();
      transactions.value = txnRows.map(AllAccountsModel.fromMap).toList();
      customerInfo.value = infoRows.map(CustomerInfoModel.fromMap).toList();

      _rebuildLists();
    } catch (e, st) {
      error.value = e.toString();
      // ignore: avoid_print
      print('[CustomerLedgerController] $e\n$st');
    } finally {
      isLoading(false);
    }
  }

  // ──────────────────── outstanding (Dr / Cr) ────────────────
  void _rebuildLists() {
    // quick look‑up: accountNumber ➜ CustomerInfoModel
    final infoMap = {
      for (final c in customerInfo) c.accountNumber: c
    };

    final List<Map<String, dynamic>> drTmp = [];
    final List<Map<String, dynamic>> crTmp = [];

    for (final acc in accounts) {
      final kind = acc.type.toLowerCase();
      if (kind != 'customer' && kind != 'supplier') continue;

      // net balance
      final bal = transactions
          .where((t) => t.accountCode == acc.accountNumber)
          .fold<double>(0, (p, t) => p + (t.isDr ? t.amount : -t.amount));

      if (bal == 0) continue;

      final info = infoMap[acc.accountNumber];

      final row = {
        'accountNumber' : acc.accountNumber,
        'name'          : acc.accountName,
        'type'          : acc.type,
        'closingBalance': bal.abs(),                    // always +ve for UI
        'mobile'        : info?.mobile ?? '-',
        'area'          : info?.area   ?? '-',
        'drCr'          : bal > 0 ? 'Dr' : 'Cr',
      };

      (bal > 0 ? drTmp : crTmp).add(row);
    }

    debtors  (drTmp);
    creditors(crTmp);
  }
  // inside CustomerLedgerController

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


  // ──────────────────── old single‑name ledger ───────────────
  void filterByName(String name) {
    final acc = accounts.firstWhereOrNull(
            (a) => a.accountName.toLowerCase() == name.toLowerCase());
    if (acc == null) {
      filtered.clear();
      drTotal(0); crTotal(0);
      return;
    }

    filtered.value =
        transactions.where((t) => t.accountCode == acc.accountNumber).toList();

    double dr = 0, cr = 0;
    for (final t in filtered) t.isDr ? dr += t.amount : cr += t.amount;
    drTotal(dr); crTotal(cr);
  }

  void clearFilter() {
    filtered.clear();
    drTotal(0); crTotal(0);
  }
}
