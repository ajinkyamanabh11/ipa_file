import 'package:demo/widget/rounded_search_field.dart';
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

  DateTime fromDate = DateUtils.dateOnly(DateTime.now());
  DateTime toDate = DateUtils.dateOnly(DateTime.now());
  late TextEditingController searchController;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prc.loadProfitReport(startDate: fromDate, endDate: toDate);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: Text('Profit Report')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _buildDateRangeRow(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildSearchField(),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Obx(() {
              if (prc.isLoading.value) {
                return const Center(child: DotsWaveLoadingText());
              }

              final filteredRows = _getFilteredRows();

              if (filteredRows.isEmpty) {
                final range = fromDate == toDate
                    ? DateFormat.yMMMd().format(fromDate)
                    : '${DateFormat.yMMMd().format(fromDate)} to ${DateFormat.yMMMd().format(toDate)}';
                return Center(child: Text('No data available for $range'));
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await prc.loadProfitReport(startDate: fromDate, endDate: toDate);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: _buildTableWithTotals(filteredRows),
                ),
              );
            }),
          ),

          Obx(() => prc.batchProfits.isNotEmpty ? _buildTotalsCard() : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildDateRangeRow() {
    return Row(
      children: [
        _dateButton(
          label: 'From',
          date: fromDate,
          onPick: (d) {
            setState(() => fromDate = d);
            prc.loadProfitReport(startDate: d, endDate: toDate);
          },
        ),
        const SizedBox(width: 8),
        _dateButton(
          label: 'To',
          date: toDate,
          onPick: (d) {
            setState(() => toDate = d);
            prc.loadProfitReport(startDate: fromDate, endDate: d);
          },
        ),
      ],
    );
  }

  Widget _dateButton({required String label, required DateTime date, required Function(DateTime) onPick}) {
    return Expanded(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.date_range),
        label: Text('$label: ${DateFormat.yMMMd().format(date)}'),
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) onPick(picked);
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return RoundedSearchField(
      controller: searchController,
      text: "Search By Item Name or Bill no..",

      onChanged: (_) => setState(() {}),
    );
  }

  List<Map<String, dynamic>> _getFilteredRows() {
    final search = searchController.text.toLowerCase();
    return prc.batchProfits.where((row) {
      final item = (row['itemName'] ?? '').toString().toLowerCase();
      final bill = (row['billno'] ?? '').toString().toLowerCase();
      return item.contains(search) || bill.contains(search);
    }).toList();
  }

  Widget _buildTableWithTotals(List<Map<String, dynamic>> rows) {
    final sortedRows = List<Map<String, dynamic>>.from(rows)
      ..sort((a, b) => a['billno'].toString().compareTo(b['billno'].toString()));

    final rowsPer = sortedRows.length < 10 ? sortedRows.length : 10;

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PaginatedDataTable(
              headingRowColor: MaterialStateProperty.all(Colors.lightGreen[100]),
              columnSpacing: 24,
              rowsPerPage: rowsPer,
              availableRowsPerPage: sortedRows.length < 10 ? [rowsPer] : const [10],
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard() {
    return Container(
      color: Colors.green.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _totalTile('Total Sales', prc.totalSales.value, Colors.blue),
          _totalTile('Total Purchase', prc.totalPurchase.value, Colors.orange),
          _totalTile('Total Profit', prc.totalProfit.value, Colors.green),
        ],
      ),
    );
  }

  Widget _totalTile(String label, double amount, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        Text('₹${amount.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ProfitSource extends DataTableSource {
  _ProfitSource(this.data);

  final List<Map<String, dynamic>> data;

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
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
        DataCell(
          Text(
            '₹${(row['profit'] ?? 0).toStringAsFixed(2)}',
            style: TextStyle(
              color: (row['profit'] ?? 0) < 0 ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  int get rowCount => data.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}
