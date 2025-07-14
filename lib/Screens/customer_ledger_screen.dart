import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/customerLedger_Controller.dart';
import '../widget/custom_app_bar.dart';
import '../widget/animated_Dots_LoadingText.dart';

class CustomerLedger_Screen extends StatefulWidget {
  const CustomerLedger_Screen({super.key});

  @override
  State<CustomerLedger_Screen> createState() => _CustomerLedger_ScreenState();
}

class _CustomerLedger_ScreenState extends State<CustomerLedger_Screen> {
  final ctrl = Get.put(CustomerLedger_Controller());
  final TextEditingController search = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _showBackToTop = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.offset > 300 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollCtrl.offset <= 300 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    search.dispose();
    super.dispose();
    _debounce?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        ctrl.clearFilter();
        search.clear();
        return true;
      },
      child: Scaffold(
        appBar: CustomAppBar(title: const Text('Customer Ledger')),
        body: Obx(() {
          if (ctrl.isLoading.value) {
            return const Center(child: DotsWaveLoadingText());
          }

          final names = ctrl.accounts.map((e) => e.accountName.toLowerCase()).toList();
          final txns = ctrl.filtered;
          final net = ctrl.drTotal.value - ctrl.crTotal.value;

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
                        controller: _scrollCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 20, 12, 120), // bottom padding added
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _messages(names),
                            if (txns.isNotEmpty) _paginatedTable(context, txns),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              //SizedBox(height: 8,),
              // 👉 Floating Totals at the Bottom
              Positioned(
                bottom: 0,
                left: 16,
                right: 16,
                child: _totals(net),
              ),
            ],
          );
        }),
        floatingActionButton: _showBackToTop
            ? Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            heroTag: 'topBtn',
            backgroundColor: Colors.green,
            elevation: 0,
            onPressed: () {
              _scrollCtrl.animateTo(
                0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              );
            },
            child: const Icon(Icons.arrow_upward, color: Colors.white),
          ),
        )
            : null,
      ),
    );
  }

  Widget _autocomplete(List<String> names) => RawAutocomplete<String>(
    textEditingController: search,
    focusNode: FocusNode(),
    optionsBuilder: (v) => v.text.isEmpty
        ? const Iterable<String>.empty()
        : names.where((n) => n.contains(v.text.toLowerCase())),
    onSelected: (String value) {
      ctrl.filterByName(value);
      FocusManager.instance.primaryFocus?.unfocus();
    },
    fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
      return TextField(
        controller: textCtrl,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: 'Search by Account Name',
          prefixIcon: const Icon(Icons.search, color: Colors.green),
          suffixIcon: textCtrl.text.isEmpty
              ? null
              : IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              textCtrl.clear();
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.green, width: 1.5),
          ),
        ),
        onSubmitted: (v) => ctrl.filterByName(v.trim()),
        onChanged: (value) {
          if (_debounce?.isActive ?? false) _debounce!.cancel();
          _debounce = Timer(const Duration(milliseconds: 300), () {
            setState(() {});
          });
        },
      );
    },
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
    final q = search.text.trim();
    if (q.isEmpty) {
      return const Text('Search an account name to see outstanding…',
          style: TextStyle(fontSize: 16));
    }
    if (!names.contains(q.toLowerCase())) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('No customer or supplier named "$q" found.',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      );
    }
    if (ctrl.filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('No transactions found for "$q".',
            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _paginatedTable(BuildContext context, List txns) {
    /// show all rows when fewer than 10
    final int rowsPer = txns.length < 10 ? txns.length : 10;

    return PaginatedDataTable(
      headingRowColor: MaterialStateProperty.all(Colors.lightGreen[100]),
      columnSpacing: 30,

      rowsPerPage: rowsPer,
      // keep the dropdown sensible
      availableRowsPerPage: rowsPer < 10
          ? [rowsPer]                       // only one choice when <10
          : const [5, 10, 20, 50],

      columns: const [
        DataColumn(label: Text('Date')),
        DataColumn(label: SizedBox(width: 120, child: Text('Type'))),
        DataColumn(label: Text('Invoice')),
        DataColumn(label: Text('Debit')),
        DataColumn(label: Text('Credit')),
        DataColumn(label: Text('Balance')),
      ],
      source: _LedgerSource(txns, context),
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
        Row(children: [
          const Text('Net Outstanding: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('₹${net.abs().toStringAsFixed(2)} ',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: net < 0 ? Colors.red : Colors.green)),
          Text(net < 0 ? 'Cr' : 'Dr',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: net < 0 ? Colors.red : Colors.green)),
        ]),
      ],
    ),
  );

  Widget _row(String label, double amt) => Row(
    children: [
      Expanded(
          child: Text('$label:',
              style: const TextStyle(fontWeight: FontWeight.bold))),
      Text('₹${amt.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
    ],
  );

  void _showFullText(BuildContext ctx, String text) {
    Get.snackbar(
      '', '',
      titleText: const Text('Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      messageText: Text(text, style: const TextStyle(color: Colors.black)),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.white,
      borderRadius: 12,
      margin: const EdgeInsets.all(16),
      snackStyle: SnackStyle.FLOATING,
      duration: const Duration(seconds: 4),
      animationDuration: const Duration(milliseconds: 300),
      forwardAnimationCurve: Curves.easeOut,
      boxShadows: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
    );
  }
}

class _LedgerSource extends DataTableSource {
  final List txns;
  final BuildContext context;

  _LedgerSource(this.txns, this.context);

  double bal = 0;

  @override
  DataRow? getRow(int index) {
    if (index >= txns.length) return null;
    final t = txns[index];

    if (index == 0) bal = 0;
    if (t.isDr) {
      bal += t.amount;
    } else {
      bal -= t.amount;
    }

    return DataRow.byIndex(
      index: index,
      color: MaterialStateProperty.all(index.isEven ? Colors.white : Colors.green[50]),
      cells: [
        DataCell(Text(DateFormat('dd/MM/yy').format(t.transactionDate))),
        DataCell(
          SizedBox(
            width: 120,
            child: Text(
              t.narrations,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          onTap: () {
            Get.snackbar(
              '', '',
              titleText: const Text('Details',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              messageText: Text(t.narrations, style: const TextStyle(color: Colors.black)),
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.white,
              borderRadius: 12,
              margin: const EdgeInsets.all(16),
              snackStyle: SnackStyle.FLOATING,
              duration: const Duration(seconds: 4),
            );
          },
        ),
        DataCell(Center(child: Text(t.invoiceNo?.toString() ?? '-'))),
        DataCell(Text(t.isDr ? t.amount.toStringAsFixed(2) : '-')),
        DataCell(Text(!t.isDr ? t.amount.toStringAsFixed(2) : '-')),
        DataCell(Text(
          '₹${bal.toStringAsFixed(2)}',
          style: TextStyle(color: bal < 0 ? Colors.red : Colors.green),
        )),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => txns.length;
  @override
  int get selectedRowCount => 0;
}
