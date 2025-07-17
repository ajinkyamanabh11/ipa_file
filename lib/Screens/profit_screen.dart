// profit_report_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/profit_report_controller.dart';
import '../widget/animated_Dots_LoadingText.dart';
import '../widget/custom_app_bar.dart';

class ProfitReportScreen extends StatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  State<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends State<ProfitReportScreen> {
  final prc = Get.find<ProfitReportController>();
  DateTime fromDate = DateUtils.dateOnly(DateTime.now().subtract(const Duration(days: 7)));
  DateTime toDate = DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prc.loadProfitReport(startDate: fromDate, endDate: toDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: Text('Profit Report')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text('From: ${DateFormat.yMMMd().format(fromDate)}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: fromDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => fromDate = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text('To: ${DateFormat.yMMMd().format(toDate)}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: toDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => toDate = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        prc.loadProfitReport(startDate: fromDate, endDate: toDate);
                      },
                      child: const Text('Load Report'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Obx(() {
                    if (prc.batchProfits.isEmpty) {
                      return const Center(child: DotsWaveLoadingText());
                    }
                    return _paginatedTable(prc.batchProfits);
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginatedTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const Center(child: Text('No records.'));

    // ✅ Sort by billno ascending
    final sortedRows = List<Map<String, dynamic>>.from(rows);
    sortedRows.sort((a, b) => a['billno'].toString().compareTo(b['billno'].toString()));

    final totalRows = sortedRows.length + 1;
    final rowsPer = totalRows < 10 ? totalRows : 10;

    return PaginatedDataTable(
      headingRowColor: MaterialStateProperty.all(Colors.lightGreen[100]),
      columnSpacing: 24,
      rowsPerPage: rowsPer,
      availableRowsPerPage: totalRows < 10 ? [rowsPer] : const [10],
      showFirstLastButtons: true,
      columns: const [
        DataColumn(label: Text('Sr.')),
        DataColumn(label: Text('Item')),
        DataColumn(label: Text('Bill No')),
        DataColumn(label: Text('Batch')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Qty')),
        DataColumn(label: Text('Packing')),
        DataColumn(label: Text('Sales')),
        DataColumn(label: Text('Purchase')),
        DataColumn(label: Text('Profit')),
      ],
      source: _ProfitSource(sortedRows),
    );
  }
}

class _ProfitSource extends DataTableSource {
  _ProfitSource(this.data) {
    totalProfit = data.fold<double>(0, (p, e) => p + (e['profit'] ?? 0));
  }

  final List<Map<String, dynamic>> data;
  late final double totalProfit;

  @override
  DataRow? getRow(int index) {
    if (index == data.length) {
      return DataRow.byIndex(
        index: index,
        color: MaterialStateProperty.all(Colors.lightGreen[100]),
        cells: [
          const DataCell(Text('')),
          const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
          const DataCell(Text('-')),
          const DataCell(Text('-')),
          const DataCell(Text('-')),
          const DataCell(Text('-')),
          const DataCell(Text('-')),
          const DataCell(Text('-')),
          const DataCell(Text('-')),
          DataCell(Text('₹${totalProfit.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      );
    }

    final row = data[index];
    return DataRow.byIndex(
      index: index,
      color: MaterialStateProperty.all(index.isEven ? Colors.white : Colors.green[50]),
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(row['itemName'] ?? '')),
        DataCell(Text('${row['billno'] ?? ''}')),
        DataCell(Text(row['batchno'] ?? '')),
        DataCell(Text(row['date'] ?? '')),
        DataCell(Text('${row['qty'] ?? ''}')),
        DataCell(Text(row['packing'] ?? '')),
        DataCell(Text('₹${(row['sales'] ?? 0).toStringAsFixed(2)}')),
        DataCell(Text('₹${(row['purchase'] ?? 0).toStringAsFixed(2)}')),
        DataCell(Text('₹${(row['profit'] ?? 0).toStringAsFixed(2)}')),
      ],
    );
  }

  @override
  int get rowCount => data.length + 1;
  @override
  bool get isRowCountApproximate => false;
  @override
  int get selectedRowCount => 0;
}
