// lib/controllers/customer_ledger_controller.dart
import 'package:get/get.dart';

import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';

// typed rows
import '../model/account_master_model.dart';
import '../model/allaccounts_model.dart';

class CustomerLedgerController extends GetxController {
  final drive = Get.find<GoogleDriveService>();

  // ───────────── reactive stores ─────────────
  final accounts        = <AccountModel>[].obs;
  final transactions    = <AllAccountsModel>[].obs;

  /// raw row‑maps (all headers are lower‑cased once)
  final customerInfo    = <Map<String, dynamic>>[].obs;   // CustomerInformation.csv
  final supplierInfo    = <Map<String, dynamic>>[].obs;   // SupplierInformation.csv

  final debtors   = <Map<String, dynamic>>[].obs;         // balance > 0 (Dr)
  final creditors = <Map<String, dynamic>>[].obs;         // balance < 0 (Cr)

  // single‑name ledger screen
  final filtered  = <AllAccountsModel>[].obs;
  final drTotal   = 0.0.obs;
  final crTotal   = 0.0.obs;

  // status flags
  final isLoading = false.obs;
  final error     = RxnString();

  late final List<String> _softAgriPath;                  // Drive path segments

  // ───────────── life‑cycle ─────────────
  @override
  Future<void> onInit() async {
    super.onInit();
    _softAgriPath = await SoftAgriPath.build(drive);
    _load();
  }

  Future<void> loadData() => _load();                     // pull‑to‑refresh

  // ───────────── loader ─────────────
  Future<void> _load() async {
    try {
      isLoading(true);
      error.value = null;

      final parentId = await drive.folderId(_softAgriPath);

      // helper ── fetch + lower‑case headers
      Map<String, dynamic> _lc(Map<String, dynamic> row) => {
        for (final e in row.entries)
          e.key.toString().trim().toLowerCase(): e.value
      };
      Future<List<Map<String, dynamic>>> _csv(String file) async {
        final id  = await drive.fileId(file, parentId);
        final csv = await drive.downloadCsv(id);
        return CsvUtils.toMaps(csv).map(_lc).toList();
      }

      // download three information sets
      accounts.value     = (await _csv('AccountMaster.csv'))
          .map(AccountModel.fromMap).toList();
      transactions.value = (await _csv('AllAccounts.csv'))
          .map(AllAccountsModel.fromMap).toList();
      customerInfo.value = await _csv('CustomerInformation.csv');
      supplierInfo.value = await _csv('SupplierInformation.csv');

      _rebuildOutstanding();
    } catch (e, st) {
      error.value = e.toString();
      // ignore: avoid_print
      print('[CustomerLedgerController] $e\n$st');
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
