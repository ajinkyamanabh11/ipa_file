import 'package:get/get.dart';

import '../constants/paths.dart';
import '../model/profit_report_models/Sales_invoice_details_row.dart';
import '../model/profit_report_models/sale_detail.dart';
import '../model/profit_report_models/sales_invoice_master_row.dart';
import '../model/profit_report_models/ item_profit_summary.dart';
import '../services/google_drive_service.dart';
import '../util/csv_utils.dart';
import 'base_remote_controller.dart';
import 'item_type_controller.dart';   // optional, for item names

class ProfitReportController extends GetxController
    with BaseRemoteController {
  // Services
  final _drive = Get.find<GoogleDriveService>();

  // Reactive state
  final selectedDate   = DateTime.now().obs;
  final dailyProfit    = 0.0.obs;
  final itemSummaries  = <ItemProfitSummary>[].obs;

  late List<String> _softAgriPath;   // ['SoftAgri_Backups', '20252026', 'softagri_csv']

  @override
  Future<void> onInit() async {
    super.onInit();
    _softAgriPath = await SoftAgriPath.build(_drive);
    guard(_load);
  }

  /* ------------ public API ------------ */
  Future<void> setDate(DateTime d) async {
    selectedDate.value = d;
    await guard(() => _load(silent: true));
  }

  /* ------------ core ------------ */
  Future<void> _load({bool silent = false}) async {
    if (!silent) isLoading(true);

    try {
      // 1) folder
      final fyFolderId = await _drive.folderId(_softAgriPath);

      // 2) CSV download
      final masterCsv = await _drive.downloadCsv(
          await _drive.fileId('SalesInvoiceMaster.csv',  fyFolderId));
      final detailCsv = await _drive.downloadCsv(
          await _drive.fileId('SalesInvoiceDetails.csv', fyFolderId));

      // 3) parse CSV → List<Map>
      final masterMaps = CsvUtils.toMaps(masterCsv);
      final detailMaps = CsvUtils.toMaps(detailCsv);

      // 4) map to row models
      final masterRows = masterMaps
          .map(SalesInvoiceMasterRow.fromCsv)
          .where((m) => m.billNo.isNotEmpty)
          .toList();
      final detailRows = detailMaps
          .map(SalesInvoiceDetailRow.fromCsv)
          .where((d) => d.billNo.isNotEmpty && d.qty > 0)
          .toList();

      // 5) index master rows by bill number
      final masterByNo = { for (var m in masterRows) m.billNo : m };

      // Selected day range
      final dayStart = DateTime(
          selectedDate.value.year,
          selectedDate.value.month,
          selectedDate.value.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      // Optional item names
      String _name(int code) {
        final itemCtrl = Get.isRegistered<ItemTypeController>()
            ? Get.find<ItemTypeController>() : null;
        return itemCtrl?.allItems
            .firstWhereOrNull((r) => r['ItemCode'] == code)
        ?['ItemName'] ?? 'Unknown Item';
      }

      // 6) build SaleDetail list grouped by item
      final salesByItem = <int, List<SaleDetail>>{};

      for (final d in detailRows) {
        final master = masterByNo[d.billNo];
        if (master == null) continue;
        if (master.entryDate.isBefore(dayStart) ||
            master.entryDate.isAfter(dayEnd)) continue;

        final sale = SaleDetail(
          invoiceNo     : d.billNo,
          itemCode      : d.itemCode,
          itemName      : _name(d.itemCode),
          packing       : d.packing,
          quantity      : d.qty,
          purchasePrice : d.purchasePrice,
          sellingPrice  : d.salesPrice,
          profit        : d.lineTotal - d.purchasePrice * d.qty,
        );
        salesByItem.putIfAbsent(d.itemCode, () => []).add(sale);
      }

      // 7) aggregate summaries
      final summaries = salesByItem.values
          .map(ItemProfitSummary.fromSales)
          .toList()
        ..sort((a, b) => b.totalProfit.compareTo(a.totalProfit));

      itemSummaries.value = summaries;
      dailyProfit.value   =
          summaries.fold(0.0, (s, e) => s + e.totalProfit);
    } catch (e) {
      error.value = e.toString();
      itemSummaries.clear();
      dailyProfit.value = 0;
    } finally {
      if (!silent) isLoading(false);
    }
  }
}
