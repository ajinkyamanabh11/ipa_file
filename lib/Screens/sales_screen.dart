import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/sales_controller.dart';
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
    final l =
        sc.filter(nameQ: nameCtrl.text, billQ: billCtrl.text, date: picked)
          ..sort((a, b) {
            final d1 = a['EntryDate'] as DateTime?;
            final d2 = b['EntryDate'] as DateTime?;
            if (d1 == null || d2 == null) return 0;
            return asc ? d1.compareTo(d2) : d2.compareTo(d1);
          });
    return l;
  }

  double _sum(List<Map<String, dynamic>> rows) =>
      rows.fold(0.0, (p, e) => p + (e['Amount'] ?? 0));

  // ─── build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: Text('Sales Report')),
      floatingActionButton: FloatingActionButton(
        onPressed: sc.fetchSales,
        child: const Icon(Icons.refresh),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Obx(() {
          if (sc.isLoading.value)
            return const Center(child: CircularProgressIndicator());
          if (sc.error.value != null)
            return Center(child: Text('❌ ${sc.error.value!}'));

          final data = _filtered();
          final cashRows = data
              .where((m) => m['PaymentMode'].toString().toLowerCase() == 'cash')
              .toList();
          final creRows = data
              .where((m) => m['PaymentMode'].toLowerCase() == 'credit')
              .toList();

          final totCash = _sum(cashRows);
          final totCredit = _sum(creRows);

          return Column(
            children: [
              _filters(context),
              const SizedBox(height: 8),
              // Total buttons
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
              // Tables
              if (showCash)
                Expanded(
                  child: SingleChildScrollView(child: _lazyTable(cashRows)),
                ),
              if (showCredit)
                Expanded(
                  child: SingleChildScrollView(child: _lazyTable(creRows)),
                ),
              const Divider(height: 8),
              RichText(
                text: TextSpan(
                  text: 'Total - ',
                  style: const TextStyle(               // base style for “Total ₹”
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  children: [
                    TextSpan(
                      text: "₹${(totCash + totCredit).toStringAsFixed(2)}",
                      style: const TextStyle(           // green just for the number
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            ],
          );
        }),
      ),
    );
  }

  // ─── widgets ──────────────────────────────────────────────────
  // ─── helpers ──────────────────────────────────────────────
  // short label

  // ─── widgets ──────────────────────────────────────────────
  Widget _filters(BuildContext ctx) => Row(
    children: [
      _searchBox(nameCtrl, 'Name'),
      const SizedBox(width: 8),
      _searchBox(billCtrl, 'Bill No'),
      // Calendar icon + ALWAYS‑VISIBLE date label
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: DateFormat('dd‑MMM‑yyyy').format(picked),
            onPressed: () async {
              final d = await showDatePicker(
                context: ctx,
                initialDate: picked, // stays on today until user changes
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null)
                setState(
                  () => picked = DateUtils.dateOnly(d),
                ); // 2️⃣ keep date‑only
            },
          ),
          Text(
            _fmt(picked), // always shows a date (today by default)
            style: const TextStyle(fontSize: 11),
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: tap,
        child: Text(
          '$label: ₹${amt.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
  // one bordered header label
  Widget _h(String txt, {bool last = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      border: Border(
        right: last
            ? BorderSide.none
            : BorderSide(color: Colors.grey.shade300, width: .7),
      ),
    ),
    child: Text(txt, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

// one bordered data cell
  DataCell _c(String txt, {bool last = false}) => DataCell(
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          right: last
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade300, width: .7),
        ),
      ),
      child: Text(txt),
    ),
  );

  /// Builds a `PaginatedDataTable` backed by a lazy `DataTableSource`
  Widget _lazyTable(List<Map<String, dynamic>> rows) => PaginatedDataTable(
    //header: const Text(''),
    columns: const [
      DataColumn(label: Text('Name')),

      DataColumn(label: Text('Bill No')),
      DataColumn(label: Text('Date')),
      DataColumn(label: Text('Amount')),
    ],
    source: _SalesSource(rows),
    rowsPerPage: 10,
    availableRowsPerPage: const [5, 10, 20, 50],
    columnSpacing: 28,
    showFirstLastButtons: true,
  );
}

/// DataTableSource that builds only the required row widgets
class _SalesSource extends DataTableSource {
  final List<Map<String, dynamic>> data;
  _SalesSource(this.data);

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final m = data[index];
    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text(m['AccountName'] ?? '')),
        DataCell(Text(m['BillNo'].toString())),
        DataCell(Text(DateFormat('dd‑MMM‑yyyy').format(m['EntryDate']))),
        DataCell(Text('₹${(m['Amount'] ?? 0).toStringAsFixed(2)}')),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => data.length;
  @override
  int get selectedRowCount => 0;
}
