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
  final ctrl = Get.find<SalesController>();

  final nameCtrl = TextEditingController();
  final billCtrl = TextEditingController();
  DateTime? picked;
  bool asc = true;
  bool showCash = false;
  bool showCredit = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    billCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: const Text('Sales Report')),
      floatingActionButton: FloatingActionButton(
        onPressed: ctrl.fetchSales,
        child: const Icon(Icons.refresh),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Obx(() {
          if (ctrl.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ctrl.error.value != null) {
            return Center(child: Text('❌ ${ctrl.error.value}'));
          }

          // ---- filter + sort --------------------------------------------------
          final list = ctrl
              .filter(
            nameQ: nameCtrl.text,
            billQ: billCtrl.text,
            date: picked,
          )
            ..sort((a, b) {
              final d1 = a['EntryDate'] as DateTime?;
              final d2 = b['EntryDate'] as DateTime?;
              if (d1 == null || d2 == null) return 0;
              return asc ? d1.compareTo(d2) : d2.compareTo(d1);
            });

          final cash   = list.where((m) => m['PaymentMode'].toString().toLowerCase() == 'cash').toList();
          final credit = list.where((m) => m['PaymentMode'].toLowerCase() == 'credit').toList();

          double sum(List<Map<String, dynamic>> rows) =>
              rows.fold(0.0, (p, e) => p + (e['Amount'] ?? 0));

          final totCash   = sum(cash);
          final totCredit = sum(credit);

          // ---- ui -------------------------------------------------------------
          return Row(
            children: [
              _filters(context),
              const SizedBox(height: 8),
              _totButton('Cash Sale',   totCash,   showCash, () {
                setState(() { showCash = !showCash; showCredit = false; });
              }),
              if (showCash) Expanded(child: _table(cash)),
              _totButton('Credit Sale', totCredit, showCredit, () {
                setState(() { showCredit = !showCredit; showCash = false; });
              }),
              if (showCredit) Expanded(child: _table(credit)),
              const Divider(height: 24),
              Text(
                'Total  ₹${(totCash + totCredit).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── small widgets ──────────────────────────────────────────────
  Widget _filters(BuildContext ctx) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Name'),
          onChanged: (_) => setState(() {}),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: billCtrl,
          decoration: const InputDecoration(labelText: 'Bill No'),
          onChanged: (_) => setState(() {}),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.date_range),
        onPressed: () async {
          final d = await showDatePicker(
            context: ctx,
            initialDate: picked ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null) setState(() => picked = d);
        },
      ),
      IconButton(
        tooltip: asc ? 'Sort: Asc' : 'Sort: Desc',
        icon: Icon(asc ? Icons.arrow_upward : Icons.arrow_downward),
        onPressed: () => setState(() => asc = !asc),
      ),
    ],
  );

  Widget _totButton(
      String label, double amt, bool active, VoidCallback tap) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: active ? Colors.green : Colors.grey.shade200,
            foregroundColor: active ? Colors.white : Colors.black,
          ),
          onPressed: tap,
          child: Text('$label: ₹${amt.toStringAsFixed(2)}'),
        ),
      );

  Widget _table(List<Map<String, dynamic>> rows) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: const [
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Bill No')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Amount')),
      ],
      rows: rows
          .map((m) => DataRow(cells: [
        DataCell(Text(m['AccountName'].toString())),
        DataCell(Text(m['BillNo'].toString())),
        DataCell(Text(
            DateFormat('dd-MMM-yyyy').format(m['EntryDate']))),
        DataCell(
            Text('₹${(m['Amount'] ?? 0).toStringAsFixed(2)}')),
      ]))
          .toList(),
    ),
  );
}
