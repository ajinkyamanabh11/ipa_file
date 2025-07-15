import 'package:get/get.dart';

import '../constants/paths.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import '../model/account_master_model.dart';
import '../model/allaccounts_model.dart';
import 'base_remote_controller.dart';

class CustomerLedgerController extends GetxController with BaseRemoteController {
  final drive = Get.find<GoogleDriveService>();

  // typed collections – UI relies on these getters
  final accounts     = <AccountModel>[].obs;
  final transactions = <AllAccountsModel>[].obs;
  final filtered     = <AllAccountsModel>[].obs;

  // reactive totals
  final drTotal = 0.0.obs;
  final crTotal = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    guard(_load);
  }

  /// allows RefreshIndicator(onRefresh: ctrl.loadData)
  Future<void> loadData() async => guard(_load);

  // ───────────────────────────────────────────────────────────
  Future<void> _load() async {
    final parent = await drive.folderId(kSoftAgriPath);
    final accId  = await drive.fileId('AccountMaster.csv', parent);
    final allId  = await drive.fileId('AllAccounts.csv', parent);

    accounts.value = CsvUtils
        .toMaps(await drive.downloadCsv(accId))
        .map(AccountModel.fromMap)
        .toList();

    transactions.value = CsvUtils
        .toMaps(await drive.downloadCsv(allId))
        .map(AllAccountsModel.fromMap)
        .toList();
  }

  void filterByName(String name) {
    final acc = accounts.firstWhereOrNull(
            (a) => a.accountName.toLowerCase() == name.toLowerCase());
    if (acc == null) {
      filtered.clear();
      drTotal(0);
      crTotal(0);
      return;
    }

    filtered.value =
        transactions.where((t) => t.accountCode == acc.accountNumber).toList();

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
