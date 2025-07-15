import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/customerLedger_Controller.dart';
import '../model/allaccounts_model.dart';
import '../widget/animated_Dots_LoadingText.dart';
import '../widget/custom_app_bar.dart';

class CustomerLedger_Screen extends StatefulWidget {
  const CustomerLedger_Screen({super.key});

  @override
  State<CustomerLedger_Screen> createState() => _CustomerLedger_ScreenState();
}

class _CustomerLedger_ScreenState extends State<CustomerLedger_Screen> {
  final ctrl = Get.put(CustomerLedgerController());

  final searchCtrl = TextEditingController();
  final scrollCtrl = ScrollController();

  final searchFocus = FocusNode();

  // reactive helpers (no setState)
  final RxBool   showFab  = false.obs;
  final RxString searchQ  = ''.obs;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    // toggle FAB
    scrollCtrl.addListener(() {
      showFab.value = scrollCtrl.offset > 300;
    });
  }

  @override
  void dispose() {
    scrollCtrl.dispose();
    searchCtrl.dispose();
    searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        ctrl.clearFilter();
        searchCtrl.clear();
        searchQ.value = '';
        return true;
      },
      child: Scaffold(
        appBar: CustomAppBar(title: const Text('Customer Ledger')),
        body: Obx(() {
          if (ctrl.isLoading.value) {
            return const Center(child: DotsWaveLoadingText());
          }

          final names =
          ctrl.accounts.map((e) => e.accountName.toLowerCase()).toList();
          final txns = ctrl.filtered.cast<AllAccountsModel>();
          final net  = ctrl.drTotal.value - ctrl.crTotal.value;

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async => ctrl.loadData(),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _autocomplete(names),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                        const EdgeInsets.fromLTRB(12, 20, 12, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Obx(() => _messages(names)),
                            if (txns.isNotEmpty)
                              _paginatedTable(context, txns),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 16,
                right: 16,
                child: _totals(net),
              ),
            ],
          );
        }),
        floatingActionButton: Obx(() => showFab.value
            ? FloatingActionButton(
          heroTag: 'topBtn',
          backgroundColor: Colors.green,
          onPressed: () => scrollCtrl.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          ),
          child: const Icon(Icons.arrow_upward),
        )
            : const SizedBox.shrink()   // 👈 return an inert widget instead of null
        ),
      ),
    );
  }

  // ────────────────────── autocomplete & banner ──────────────────────

  Widget _autocomplete(List<String> names) => RawAutocomplete<String>(
    textEditingController: searchCtrl,
      focusNode: searchFocus,
    optionsBuilder: (v) => v.text.isEmpty
        ? const Iterable<String>.empty()
        : names.where((n) => n.contains(v.text.toLowerCase())),
    onSelected: (value) {
      ctrl.filterByName(value);
      searchQ.value = value;
      searchFocus.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    },
    fieldViewBuilder: (c, t, f, _) => TextField(
      controller: t,
      focusNode: f,
      decoration: InputDecoration(
        hintText: 'Search by Account Name',
        prefixIcon: const Icon(Icons.search, color: Colors.green),
        suffixIcon: t.text.isEmpty
            ? null
            : IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            t.clear();
            searchQ.value = '';
            ctrl.clearFilter();
            FocusScope.of(context).unfocus();
          },
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
      onSubmitted: (v) {
        ctrl.filterByName(v.trim());
        searchQ.value = v.trim();
      },
      onChanged: (v) {
        _debounce?.cancel();
        _debounce =
            Timer(const Duration(milliseconds: 300), () => searchQ.value = v);
      },
    ),
    optionsViewBuilder: (c, onSel, opts) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: MediaQuery.of(c).size.width - 24,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: opts.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(opts.elementAt(i)),
              onTap: () => onSel(opts.elementAt(i)),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _messages(List<String> names) {
    final q = searchQ.value.trim();
    if (q.isEmpty) {
      return const Text('Search an account name to see outstanding…');
    }
    if (!names.contains(q.toLowerCase())) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('No customer or supplier named "$q" found.',
            style: const TextStyle(color: Colors.red)),
      );
    }
    if (ctrl.filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('No transactions found for "$q".',
            style: const TextStyle(color: Colors.orange)),
      );
    }
    return const SizedBox.shrink();
  }

  // ───────────────────────── table & totals ──────────────────────────

  Widget _paginatedTable(BuildContext _, List<AllAccountsModel> txns) {
    final totalRows = txns.length + 1;           // +1 for summary row
    final rowsPer   = totalRows < 10 ? totalRows : 10;

    return PaginatedDataTable(
      headingRowColor: MaterialStateProperty.all(Colors.lightGreen[100]),
      columnSpacing: 30,

      // if fewer than 10 rows, show them all; else fixed at 10
      rowsPerPage: rowsPer,
      availableRowsPerPage: totalRows < 10
          ? [rowsPer]          // no dropdown when only one page size
          : const [10],        // fixed 10 for larger datasets

      columns: const [
        DataColumn(label: Text('Sr.')),
        DataColumn(label: Text('Date')),
        DataColumn(label: SizedBox(width: 120, child: Text('Type'))),
        DataColumn(label: Text('Invoice')),
        DataColumn(label: Text('Debit')),
        DataColumn(label: Text('Credit')),
        DataColumn(label: Text('Balance')),
      ],
      source: _LedgerSource(txns),
    );
  }


  Widget _totals(double net) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.green.shade100),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('Dr Total', ctrl.drTotal.value),
        const SizedBox(height: 8),
        _row('Cr Total', ctrl.crTotal.value),
        const Divider(),
        Row(
          children: [
            const Text('Net Outstanding: ',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('₹${net.abs().toStringAsFixed(2)} ',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: net < 0 ? Colors.red : Colors.green)),
            Text(net < 0 ? 'Cr' : 'Dr',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: net < 0 ? Colors.red : Colors.green)),
          ],
        ),
      ],
    ),
  );

  Widget _row(String label, double amt) => Row(
    children: [
      Expanded(child: Text('$label:')),
      Text('₹${amt.toStringAsFixed(2)}',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.green)),
    ],
  );
}

// ───────────────── LedgerSource (sorted + Net Outstanding) ──────────────
class _LedgerSource extends DataTableSource {
  _LedgerSource(this.txns) {
    txns.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
    netOutstanding =
        txns.fold<double>(0, (p, t) => p + (t.isDr ? t.amount : -t.amount));
  }

  final List<AllAccountsModel> txns;
  late final double netOutstanding;
  double runningBal = 0;

  @override
  DataRow? getRow(int index) {
    // ─── summary row (no Sr. number) ───────────────────────────
    if (index == txns.length) {
      final isCr = netOutstanding < 0;
      return DataRow.byIndex(
        index: index,
        color: MaterialStateProperty.all(Colors.lightGreen[100]),
        cells: [
          const DataCell(Text('')),                      // ← empty Sr.
          const DataCell(Text('')),                      // Date blank
          const DataCell(Text('Closing Balance',
              style: TextStyle(fontWeight: FontWeight.bold))),
          const DataCell(Text('-')),                     // Invoice
          const DataCell(Text('-')),                     // Debit
          const DataCell(Text('-')),                     // Credit
          DataCell(Text(
            '₹${netOutstanding.abs().toStringAsFixed(2)} ${isCr ? 'Cr' : 'Dr'}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCr ? Colors.red : Colors.green),
          )),
        ],
      );
    }

    // ─── normal row ────────────────────────────────────────────
    final t = txns[index];
    if (index == 0) runningBal = 0;
    runningBal += t.isDr ? t.amount : -t.amount;

    return DataRow.byIndex(
      index: index,
      color: MaterialStateProperty.all(
          index.isEven ? Colors.white : Colors.green[50]),
      cells: [
        DataCell(Text('${index + 1}')),                 // Sr. #
        DataCell(Text(DateFormat('dd/MM/yy').format(t.transactionDate))),
        DataCell(
          SizedBox(
            width: 120,
            child: Text(
              t.narrations,
              overflow: TextOverflow.ellipsis,
              style: t.narrations.toLowerCase() == 'opening balance'
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
          ),
          // 👇 show floating snackbar on tap
          onTap: () => Get.snackbar(
            '', '',
            titleText: const Text('Narration',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            messageText:
            Text(t.narrations, style: const TextStyle(color: Colors.black)),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.white,
            borderRadius: 12,
            margin: const EdgeInsets.all(16),
            snackStyle: SnackStyle.FLOATING,
            duration: const Duration(seconds: 4),
            animationDuration: const Duration(milliseconds: 300),
            boxShadows: const [
              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
            ],
          ),
        ),

        DataCell(Center(child: Text(t.invoiceNo?.toString() ?? '-'))),
        DataCell(Text(t.isDr ? t.amount.toStringAsFixed(2) : '-')),
        DataCell(Text(!t.isDr ? t.amount.toStringAsFixed(2) : '-')),
        DataCell(Text('₹${runningBal.toStringAsFixed(2)}',
            style: TextStyle(
                color: runningBal < 0 ? Colors.red : Colors.green))),
      ],
    );
  }

  @override
  int get rowCount => txns.length + 1; // + summary row
  @override
  bool get isRowCountApproximate => false;
  @override
  int get selectedRowCount => 0;
}
