import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/profit_report_controller.dart';
import '../model/profit_report_models/BatchProfitRow_model.dart';
import '../widget/custom_app_bar.dart';


class ProfitReportScreen extends StatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  State<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends State<ProfitReportScreen> {
  final ctrl = Get.put(BatchProfitReportController());

  final Rxn<DateTime> fromDate = Rxn<DateTime>();
  final Rxn<DateTime> toDate   = Rxn<DateTime>();
  final df = DateFormat('dd‑MM‑yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('Profit Report (Batch‑wise)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: ctrl.loadData)
        ],
      ),
      body: Column(
        children: [
          _dateBar(context),
          Expanded(child: _table()),
        ],
      ),
    );
  }

  /* date bar */
  Widget _dateBar(BuildContext ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
    child: Obx(() => Row(
      children: [
        _dateBtn('From', fromDate.value, () => _pick(ctx, true)),
        const SizedBox(width: 12),
        _dateBtn('To',   toDate.value,   () => _pick(ctx, false)),
        const Spacer(),
        TextButton(onPressed: () {
          fromDate.value = null; toDate.value = null;
        }, child: const Text('Clear')),
      ],
    )),
  );

  /* data table */
  Widget _table() => Obx(() {
    if (ctrl.isLoading.value)  { return const Center(child: CircularProgressIndicator()); }
    if (ctrl.error.value != null) { return Center(child: Text(ctrl.error.value!, style: const TextStyle(color: Colors.red))); }

    final rows = ctrl.rows.where((r) {
      final d = DateTime.parse(r.date);
      if (fromDate.value != null && d.isBefore(fromDate.value!)) return false;
      if (toDate.value   != null && d.isAfter(toDate.value!))   return false;
      return true;
    }).toList();

    if (rows.isEmpty) return const Center(child: Text('No data'));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowColor: MaterialStateProperty.all(Colors.grey.shade300),
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Invoice')),
          DataColumn(label: Text('Batch')),
          DataColumn(label: Text('Item')),
          DataColumn(label: Text('Pack')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Sales')),
          DataColumn(label: Text('Purchase')),
          DataColumn(label: Text('Profit ₹')),
        ],
        rows: rows.map(_buildRow).toList(),
      ),
    );
  });

  DataRow _buildRow(BatchProfitRow r) => DataRow(cells: [
    DataCell(Text(r.date)),
    DataCell(Text(r.invoiceNo)),
    DataCell(Text(r.batch)),
    DataCell(Text(r.itemName)),
    DataCell(Text(r.packing)),
    DataCell(Text(r.quantity.toStringAsFixed(2))),
    DataCell(Text('₹${r.salesAmount.toStringAsFixed(2)}')),
    DataCell(Text('₹${r.purchaseAmount.toStringAsFixed(2)}')),
    DataCell(Text(
      '₹${r.profit.toStringAsFixed(2)}',
      style: TextStyle(
          color: r.profit >= 0 ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold),
    )),
  ]);

  Widget _dateBtn(String lbl, DateTime? d, VoidCallback onTap) =>
      OutlinedButton.icon(
        icon: const Icon(Icons.calendar_today, size: 16),
        label: Text(d == null ? lbl : df.format(d), style: const TextStyle(fontSize: 13)),
        onPressed: onTap,
      );

  Future<void> _pick(BuildContext ctx, bool isFrom) async {
    final init = isFrom ? fromDate.value ?? DateTime.now() : toDate.value ?? DateTime.now();
    final p = await showDatePicker(
      context: ctx,
      initialDate: init,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (p == null) return;
    if (isFrom) {
      fromDate.value = p;
      if (toDate.value != null && p.isAfter(toDate.value!)) toDate.value = p;
    } else {
      toDate.value = p;
      if (fromDate.value != null && p.isBefore(fromDate.value!)) fromDate.value = p;
    }
  }
}
