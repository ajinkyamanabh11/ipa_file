// lib/screens/sales_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/sales_controller.dart';
import '../widget/animated_Dots_LoadingText.dart';
import '../widget/custom_app_bar.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // ─── controllers & state ──────────────────────────────────────
  final sc = Get.find<SalesController>();
  final nameCtrl = TextEditingController();
  final billCtrl = TextEditingController();

  String _fmt(DateTime d) => DateFormat('dd‑MMM').format(d);
  DateTime picked = DateUtils.dateOnly(DateTime.now());

  bool asc = true;
  bool showCash = true;
  bool showCredit = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    billCtrl.dispose();
    super.dispose();
  }

  // ─── helpers ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _filtered() {
    final list = sc.filter(nameQ: nameCtrl.text, billQ: billCtrl.text, date: picked)
      ..sort((a, b) {
        final d1 = a['EntryDate'] as DateTime?;
        final d2 = b['EntryDate'] as DateTime?;
        if (d1 == null || d2 == null) return 0;
        return asc ? d1.compareTo(d2) : d2.compareTo(d1);
      });
    return list;
  }

  double _sum(List<Map<String, dynamic>> rows) =>
      rows.fold(0.0, (p, e) => p + (e['Amount'] ?? 0));

  // ─── build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: Text('Sales Report')),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => sc.fetchSales(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Obx(() {
                if (sc.isLoading.value) return const Center(child: DotsWaveLoadingText());
                if (sc.error.value != null) return Center(child: Text('❌ ${sc.error.value!}'));

                final data = _filtered();
                final cashRows = data
                    .where((m) => m['PaymentMode'].toString().toLowerCase() == 'cash')
                    .toList();
                final creRows = data
                    .where((m) => m['PaymentMode'].toString().toLowerCase() == 'credit')
                    .toList();

                final totCash = _sum(cashRows);
                final totCredit = _sum(creRows);

                return ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    _filters(context),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _totBtn('Cash Sale', totCash, showCash, () {
                            setState(() {
                              showCash = !showCash;
                              showCredit = false;
                            });
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _totBtn('Credit Sale', totCredit, showCredit, () {
                            setState(() {
                              showCredit = !showCredit;
                              showCash = false;
                            });
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (showCash) _paginatedTable(cashRows),
                    if (showCredit) _paginatedTable(creRows),
                  ],
                );
              }),
            ),
          ),

          // grand‑total overlay
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Obx(() {
              final totCash = _sum(
                sc.filter(nameQ: nameCtrl.text, billQ: billCtrl.text, date: picked)
                    .where((m) => m['PaymentMode'].toString().toLowerCase() == 'cash')
                    .toList(),
              );
              final totCredit = _sum(
                sc.filter(nameQ: nameCtrl.text, billQ: billCtrl.text, date: picked)
                    .where((m) => m['PaymentMode'].toString().toLowerCase() == 'credit')
                    .toList(),
              );
              final grandTotal = totCash + totCredit;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade200),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('₹${grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ────────────── UI helpers (filters / buttons) ───────────────
  Widget _filters(BuildContext ctx) => Row(
    children: [
      _searchBox(nameCtrl, 'Name'),
      const SizedBox(width: 8),
      _searchBox(billCtrl, 'Bill No'),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: DateFormat('dd‑MMM‑yyyy').format(picked),
            onPressed: () async {
              final d = await showDatePicker(
                context: ctx,
                initialDate: picked,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => picked = DateUtils.dateOnly(d));
            },
          ),
          Text(_fmt(picked), style: const TextStyle(fontSize: 11)),
        ],
      ),
      const SizedBox(width: 4),
      IconButton(
        tooltip: asc ? 'Sort Asc' : 'Sort Desc',
        icon: Icon(asc ? Icons.arrow_upward : Icons.arrow_downward),
        onPressed: () => setState(() => asc = !asc),
      ),
    ],
  );

  Widget _searchBox(TextEditingController c, String hint) => Expanded(
    child: TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: hint,
        filled: true,
        fillColor: Colors.green.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _totBtn(String label, double amt, bool active, VoidCallback tap) =>
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? Colors.green : Colors.grey.shade200,
          foregroundColor: active ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: tap,
        child: Text('$label: ₹${amt.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  // ───────────────────── paginated table ──────────────────────
  Widget _paginatedTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const Center(child: Text('No records.'));

    final totalRows = rows.length + 1;        // +1 summary row
    final rowsPer   = totalRows < 10 ? totalRows : 10;

    return PaginatedDataTable(
      headingRowColor: MaterialStateProperty.all(Colors.lightGreen[100]),
      columnSpacing: 28,
      rowsPerPage: rowsPer,
      availableRowsPerPage: totalRows < 10 ? [rowsPer] : const [10],
      showFirstLastButtons: true,
      columns: const [
        DataColumn(label: Text('Sr.')),
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Bill No')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Amount')),
      ],
      source: _SalesSource(rows),
    );
  }
}

// ───────────────────── DataTableSource ──────────────────────
class _SalesSource extends DataTableSource {
  _SalesSource(this.data) {
    grandTotal = data.fold<double>(0, (p, e) => p + (e['Amount'] ?? 0));
  }

  final List<Map<String, dynamic>> data;
  late final double grandTotal;

  @override
  DataRow? getRow(int index) {
    // summary row
    if (index == data.length) {
      return DataRow.byIndex(
        index: index,
        color: MaterialStateProperty.all(Colors.lightGreen[100]),
        cells: [
          const DataCell(Text('')),
          const DataCell(Text('Grand Total',
              style: TextStyle(fontWeight: FontWeight.bold))),
          const DataCell(Text('-')),
          const DataCell(Text('-')),
          DataCell(Text('₹${grandTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      );
    }

    // normal row with even/odd background
    final m = data[index];
    return DataRow.byIndex(
      index: index,
      color: MaterialStateProperty.all(
          index.isEven ? Colors.white : Colors.green[50]),
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(m['AccountName'] ?? '')),
        DataCell(Text(m['BillNo'].toString())),
        DataCell(Text(DateFormat('dd‑MMM‑yyyy').format(m['EntryDate']))),
        DataCell(Text('₹${(m['Amount'] ?? 0).toStringAsFixed(2)}')),
      ],
    );
  }

  @override
  int get rowCount => data.length + 1; // + summary row
  @override
  bool get isRowCountApproximate => false;
  @override
  int get selectedRowCount => 0;
}
