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

  // controller for the main vertical scroll view
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

          return RefreshIndicator(
            onRefresh: () async => ctrl.loadData(),
            child: Column(
              children: [
                SizedBox(height: 12,),

                _autocomplete(names),
                // ——— scrollable area —————————————————————————
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,                        // 👈 controller
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        const SizedBox(height: 20),
                        _messages(names),
                        if (txns.isNotEmpty) _table(context, txns),
                      ],
                    ),
                  ),
                ),
                // ——— fixed bottom totals panel ——————————————
                _totals(net),
              ],
            ),
          );
        }),

        // ——— floating “Back to Top” button ————————————————
        floatingActionButton: _showBackToTop
            ? FloatingActionButton(
          heroTag: 'topBtn',
          backgroundColor: Colors.green,
          onPressed: () {
            _scrollCtrl.animateTo(
              0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
          },
          child: const Icon(Icons.arrow_upward),
        )
            : null,
      ),
    );
  }

  // ——————————————————— autocomplete ———————————————————
  Widget _autocomplete(List<String> names) => RawAutocomplete<String>(
    textEditingController: search,
    focusNode: FocusNode(),
    optionsBuilder: (v) => v.text.isEmpty
        ? const Iterable<String>.empty()
        : names.where((n) => n.contains(v.text.toLowerCase())),
    onSelected: (String value) {
      ctrl.filterByName(value);
      FocusManager.instance.primaryFocus?.unfocus(); // ⬅️ hide keyboard
    },
    fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
      return TextField(
        controller: textCtrl,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: 'Search by Account Name',
          prefixIcon: const Icon(Icons.search, color: Colors.green),

          // ——— clear icon ———
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


  // ——————————————————— empty / error messages ————————————
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
            style:
            const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      );
    }
    if (ctrl.filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('No transactions found for "$q".',
            style: const TextStyle(
                color: Colors.orange, fontWeight: FontWeight.bold)),
      );
    }
    return const SizedBox.shrink();
  }

  // ——————————————————— data table ————————————————————
  Widget _table(BuildContext ctx, List txns) {
    double bal = 0, totDr = 0, totCr = 0;
    final rows = <DataRow>[];

    for (int i = 0; i < txns.length; i++) {
      final t = txns[i];
      if (t.isDr) {
        bal += t.amount;
        totDr += t.amount;
      } else {
        bal -= t.amount;
        totCr += t.amount;
      }

      rows.add(DataRow(
        color:
        MaterialStateProperty.all(i.isEven ? Colors.white : Colors.green[50]),
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
            onTap: () => _showFullText(ctx, t.narrations),
          ),
          DataCell(Center(child: Text(t.invoiceNo?.toString() ?? '-'))),
          DataCell(Text(t.isDr ? t.amount.toStringAsFixed(2) : '-')),
          DataCell(Text(!t.isDr ? t.amount.toStringAsFixed(2) : '-')),
          DataCell(Text('₹${bal.toStringAsFixed(2)}',
              style:
              TextStyle(color: bal < 0 ? Colors.red : Colors.green))),
        ],
      ));
    }

    // closing balance row
    rows.add(DataRow(
      color: MaterialStateProperty.all(Colors.lightGreen[100]),
      cells: [
        const DataCell(Text('')),
        const DataCell(
          Text('Closing Balance',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        DataCell(Text(
          '₹${bal.toStringAsFixed(2)}',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: bal < 0 ? Colors.red : Colors.green),
        )),
      ],
    ));

    // scrollbars
    final ScrollController vCtrl = ScrollController();
    final ScrollController hCtrl = ScrollController();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Scrollbar(
        controller: vCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: vCtrl,
          child: Scrollbar(
            controller: hCtrl,
            thumbVisibility: true,
            notificationPredicate: (_) => false,
            child: SingleChildScrollView(
              controller: hCtrl,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 30,
                headingRowColor:
                MaterialStateProperty.all(Colors.lightGreen[100]),
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: SizedBox(width: 120, child: Text('Type'))),
                  DataColumn(label: Text('Invoice')),
                  DataColumn(label: Text('Debit')),
                  DataColumn(label: Text('Credit')),
                  DataColumn(label: Text('Balance')),
                ],
                rows: rows,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ——————————————————— totals card ————————————————————
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
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.green)),
    ],
  );

  // ——————————————————— snackbar full text ————————————————
  void _showFullText(BuildContext ctx, String text) {
    Get.snackbar(
      '', '',
      titleText: const Text('Details',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      messageText: Text(text, style: const TextStyle(color: Colors.black)),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.white,
      borderRadius: 12,
      margin: const EdgeInsets.all(16),
      snackStyle: SnackStyle.FLOATING,
      duration: const Duration(seconds: 4),
      animationDuration: const Duration(milliseconds: 300),
      forwardAnimationCurve: Curves.easeOut,
      boxShadows: const [
        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
      ],
    );
  }
}
