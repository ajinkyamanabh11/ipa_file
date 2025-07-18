import 'package:demo/widget/rounded_search_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/profit_report_controller.dart';
import '../widget/animated_Dots_LoadingText.dart';
import '../widget/custom_app_bar.dart';
import 'package:fl_chart/fl_chart.dart'; // Import fl_chart
import 'dart:math'; // For random colors

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
    fromDate = DateUtils.dateOnly(DateTime.now());
    toDate = DateUtils.dateOnly(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prc.loadProfitReport(startDate: fromDate, endDate: toDate);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    fromDate = DateUtils.dateOnly(DateTime.now());
    toDate = DateUtils.dateOnly(DateTime.now());
    super.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prc.loadProfitReport(startDate: fromDate, endDate: toDate);
    });
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
                  child: Column( // Use a Column to place table and chart
                    children: [
                      _buildTableWithTotals(filteredRows),
                      const SizedBox(height: 20),
                      // Add the Pie Chart below the table
                      _buildProfitPieChart(filteredRows),
                      const SizedBox(height: 20), // Spacing after chart
                    ],
                  ),
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
      onClear: searchController.clear,

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

    return Padding(
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
    );
  }

  // NEW: Build the Profit Pie Chart
  Widget _buildProfitPieChart(List<Map<String, dynamic>> rows) {
    // Group profits by item name
    final Map<String, double> itemProfits = {};
    double totalPositiveProfit = 0;

    for (var row in rows) {
      final itemName = (row['itemName'] ?? 'Unknown Item').toString();
      final profit = (row['profit'] ?? 0.0) as double;
      if (profit > 0) { // Only consider positive profits for pie chart
        itemProfits.update(itemName, (value) => value + profit,
            ifAbsent: () => profit);
        totalPositiveProfit += profit;
      }
    }

    if (totalPositiveProfit <= 0) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No positive profit data to display pie chart.'),
      );
    }

    // Sort items by profit descending
    final sortedItemProfits = itemProfits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Determine how many slices for major items, and aggregate the rest into "Other"
    List<PieChartSectionData> sections = [];
    double otherProfit = 0;
    final int maxSlices = 5; // Max number of individual slices before grouping into 'Other'
    final List<Color> pieColors = [
      Colors.green.shade600,
      Colors.blue.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.red.shade600,
      Colors.teal.shade600,
      Colors.indigo.shade600,
      Colors.brown.shade600,
    ];
    final Random random = Random();

    for (int i = 0; i < sortedItemProfits.length; i++) {
      final entry = sortedItemProfits[i];
      if (i < maxSlices) {
        // Assign distinct colors, cycle through if more items than colors
        final color = pieColors[i % pieColors.length];
        sections.add(
          PieChartSectionData(
            color: color,
            value: entry.value,
            title: '${(entry.value / totalPositiveProfit * 100).toStringAsFixed(1)}%',
            radius: 80,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: _buildBadge(entry.key, color), // Add a badge for item name
            badgePositionPercentageOffset: 1.05,
          ),
        );
      } else {
        otherProfit += entry.value;
      }
    }

    if (otherProfit > 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.grey.shade400, // Color for "Other"
          value: otherProfit,
          title: '${(otherProfit / totalPositiveProfit * 100).toStringAsFixed(1)}%',
          radius: 80,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          badgeWidget: _buildBadge('Other', Colors.grey.shade400),
          badgePositionPercentageOffset: 1.05,
        ),
      );
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Profit Distribution by Item',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250, // Adjust height as needed
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        // Reset touched index if no interaction
                      } else {
                        // Handle touch if needed
                      }
                    });
                  }),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2, // Space between sections
                  centerSpaceRadius: 40, // Size of the hole in the middle
                  sections: sections,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Legend for the pie chart
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8.0, // horizontal spacing
              runSpacing: 4.0, // vertical spacing
              children: sections.map((section) {
                final String title = section.badgeWidget is Column && (section.badgeWidget as Column).children.first is Text
                    ? ((section.badgeWidget as Column).children.first as Text).data ?? ''
                    : '';
                return _buildLegendItem(title.replaceAll('%', ''), section.color!); // Remove percentage from legend
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build the badge for PieChartSectionData
  Widget _buildBadge(String text, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 10, // Smaller font for badge text
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Helper to build legend items
  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
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