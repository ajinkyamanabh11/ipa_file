import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/customerLedger_Controller.dart';
import '../widget/custom_app_bar.dart';

class CustomerLedger_Screen extends StatelessWidget {
  CustomerLedger_Screen({super.key});
  final ctrl = Get.put(CustomerLedger_Controller());
  final TextEditingController search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async { ctrl.clearFilter(); search.clear(); return true; },
      child: Scaffold(
        appBar: CustomAppBar(title: const Text('Outstanding Report')),
        body: Obx(() {
          if (ctrl.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          final names = ctrl.accounts.map((e) => e.accountName.toLowerCase()).toList();
          final txns  = ctrl.filtered;
          final net   = ctrl.drTotal.value - ctrl.crTotal.value;

          return RefreshIndicator(
            onRefresh: () async => ctrl.loadData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _autocomplete(names),
                  const SizedBox(height: 20),
                  _messages(names),
                  if (txns.isNotEmpty) _table(txns),
                  const SizedBox(height: 12),
                  _totals(net),
                ],
              ),
            ),
          );
        }),
        floatingActionButton: FloatingActionButton(
          onPressed: ctrl.loadData,
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }

  // ——————————————————— UI helpers ———————————————————
  Widget _autocomplete(List<String> names) => RawAutocomplete<String>(
    textEditingController: search,
    focusNode: FocusNode(),
    optionsBuilder: (v) => v.text.isEmpty
        ? const Iterable<String>.empty()
        : names.where((n) => n.contains(v.text.toLowerCase())),
    onSelected: ctrl.filterByName,
    fieldViewBuilder: (c, t, f, s) => TextField(
      controller: t,
      focusNode: f,
      decoration: InputDecoration(
        hintText: 'Search by Account Name',
        prefixIcon: const Icon(Icons.search, color: Colors.green),
        filled: true, fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
      ),
      onSubmitted: (v) => ctrl.filterByName(v.trim()),
    ),
    optionsViewBuilder: (c, onSel, opts) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4, borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: MediaQuery.of(c).size.width - 24,
          child: ListView.builder(
            padding: EdgeInsets.zero, shrinkWrap: true, itemCount: opts.length,
            itemBuilder: (_, i) => ListTile(title: Text(opts.elementAt(i)), onTap: () => onSel(opts.elementAt(i))),
          ),
        ),
      ),
    ),
  );

  Widget _messages(List<String> names) {
    final q = search.text.trim();
    if (q.isEmpty) {
      return const Text('Search an account name to see outstanding…', style: TextStyle(fontSize: 16));
    }
    if (!names.contains(q.toLowerCase())) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('No customer or supplier named \"$q\" found.',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      );
    }
    if (ctrl.filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('No transactions found for \"$q\".',
            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _table(List txns) {
    double bal = 0, totDr = 0, totCr = 0;
    final rows = <DataRow>[];

    for (int i = 0; i < txns.length; i++) {
      final t = txns[i];
      if (t.isDr) { bal += t.amount; totDr += t.amount; } else { bal -= t.amount; totCr += t.amount; }
      rows.add(DataRow(
        color: MaterialStateProperty.all(i.isEven ? Colors.white : Colors.green[50]),
        cells: [
          DataCell(Text(DateFormat('dd/MM/yy').format(t.transactionDate))),
          DataCell(Text(t.narrations, maxLines: 1, overflow: TextOverflow.ellipsis)),
          DataCell(Center(child: Text(t.invoiceNo?.toString() ?? '-'))),
          DataCell(Text(t.isDr ? t.amount.toStringAsFixed(2) : '-')),
          DataCell(Text(!t.isDr ? t.amount.toStringAsFixed(2) : '-')),
          DataCell(Text('₹${bal.toStringAsFixed(2)}',
              style: TextStyle(color: bal < 0 ? Colors.red : Colors.green))),
        ],
      ));
    }
    // total rows
    rows.add(DataRow(
      color: MaterialStateProperty.all(Colors.lightGreen[100]),
      cells: [
        const DataCell(Text('')), const DataCell(Text('')),
        const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text('₹${totDr.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text('₹${totCr.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
        const DataCell(Text('')),
      ],
    ));
    rows.add(DataRow(
      color: MaterialStateProperty.all(Colors.lightGreen[100]),
      cells: [
        const DataCell(Text('')),
        const DataCell(Text('Closing Balance', style: TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(bal > 0 ? '₹${bal.toStringAsFixed(2)}' : '')),
        const DataCell(Text('')),
        DataCell(Text(bal < 0 ? '₹${bal.toStringAsFixed(2)}' : '')),
        const DataCell(Text('')),
      ],
    ));

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Scrollbar(                        // vertical bar
        thumbVisibility: true,
        child: SingleChildScrollView(          // vertical scroll
          child: Scrollbar(                    // horizontal bar
            thumbVisibility: true,
            notificationPredicate: (_) => false, // keep both bars visible
            controller: ScrollController(),
            child: SingleChildScrollView(      // horizontal scroll
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 30,
                headingRowColor: MaterialStateProperty.all(Colors.lightGreen[100]),
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Type')),
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
              style: TextStyle(fontWeight: FontWeight.bold, color: net < 0 ? Colors.red : Colors.green)),
          Text(net < 0 ? 'Cr' : 'Dr',
              style: TextStyle(fontWeight: FontWeight.bold, color: net < 0 ? Colors.red : Colors.green)),
        ]),
      ],
    ),
  );

  Widget _row(String label, double amt) => Row(
    children: [
      Expanded(child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
      Text('₹${amt.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
    ],
  );
}
