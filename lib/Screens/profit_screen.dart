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
    prc.resetProfits(); // Assuming you have this method in your controller to clear totals/data
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access theme colors for consistency
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;

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
                return Center(child: DotsWaveLoadingText(
                  color: onSurfaceColor, // Use theme color for loading dots
                ));
              }

              final filteredRows = _getFilteredRows();

              if (filteredRows.isEmpty) {
                final range = fromDate == toDate
                    ? DateFormat.yMMMd().format(fromDate)
                    : '${DateFormat.yMMMd().format(fromDate)} to ${DateFormat.yMMMd().format(toDate)}';
                return Center(child: Text('No data available for $range', style: TextStyle(color: onSurfaceColor)));
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await prc.loadProfitReport(startDate: fromDate, endDate: toDate);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // Pass context to the table builder
                      _buildTableWithTotals(filteredRows, context),
                      const SizedBox(height: 20),
                      // Pass context to the chart builder
                      _buildProfitPieChart(filteredRows, context),
                      const SizedBox(height: 20), // Spacing after chart
                    ],
                  ),
                ),
              );
            }),
          ),

          Obx(() => prc.batchProfits.isNotEmpty ? _buildTotalsCard(context) : const SizedBox.shrink()),
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
            builder: (context, child) {
              // Ensure date picker itself respects theme for text/background
              return Theme(
                data: Theme.of(context).copyWith(
                  // Customize date picker theme if needed, e.g., for primary color
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: Theme.of(context).primaryColor, // Highlight color
                    onPrimary: Theme.of(context).colorScheme.onPrimary, // Text on highlight
                    surface: Theme.of(context).colorScheme.surface, // Background for calendar
                    onSurface: Theme.of(context).colorScheme.onSurface, // Text on background
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor, // OK/Cancel button text
                    ),
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) onPick(picked);
        },
      ),
    );
  }

  Widget _buildSearchField() {
    // The RoundedSearchField should also use theme colors internally if not already
    // If its text/border/fill colors are hardcoded, they need to be made theme-aware.
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

  // Modified to accept BuildContext
  Widget _buildTableWithTotals(List<Map<String, dynamic>> rows, BuildContext context) {
    final sortedRows = List<Map<String, dynamic>>.from(rows)
      ..sort((a, b) => a['billno'].toString().compareTo(b['billno'].toString()));

    final rowsPer = sortedRows.length < 10 ? sortedRows.length : 10;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: PaginatedDataTable(
        // Use theme-aware color for heading row
        headingRowColor: MaterialStateProperty.all(Theme.of(context).colorScheme.surfaceVariant),
        columnSpacing: 24,
        rowsPerPage: rowsPer,
        availableRowsPerPage: sortedRows.length < 10 ? [rowsPer] : const [10],
        showFirstLastButtons: true,
        columns: [
          // Ensure column labels also respect text theme
          DataColumn(label: Text('Sr.', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Item', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Bill No', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Batch', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Date', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Qty', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Packing', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Sales', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Purchase', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Profit', style: Theme.of(context).textTheme.titleSmall)),
        ],
        // Pass context to _ProfitSource
        source: _ProfitSource(sortedRows, context),
      ),
    );
  }

  // NEW: Build the Profit Pie Chart (Modified to accept BuildContext)
  Widget _buildProfitPieChart(List<Map<String, dynamic>> rows, BuildContext context) {
    final Map<String, double> itemProfits = {};
    double totalPositiveProfit = 0;

    for (var row in rows) {
      final itemName = (row['itemName'] ?? 'Unknown Item').toString();
      final profit = (row['profit'] ?? 0.0) as double;
      if (profit > 0) {
        itemProfits.update(itemName, (value) => value + profit,
            ifAbsent: () => profit);
        totalPositiveProfit += profit;
      }
    }

    if (totalPositiveProfit <= 0) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No positive profit data to display pie chart.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface), // Theme-aware text color
        ),
      );
    }

    final sortedItemProfits = itemProfits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<PieChartSectionData> sections = [];
    double otherProfit = 0;
    final int maxSlices = 5;
    // These colors are for the slices, and should generally be distinct.
    // They don't strictly need to be theme-aware in the same way as text/backgrounds,
    // as they represent distinct categories.
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
        final color = pieColors[i % pieColors.length];
        sections.add(
          PieChartSectionData(
            color: color,
            value: entry.value,
            title: '${(entry.value / totalPositiveProfit * 100).toStringAsFixed(1)}%',
            radius: 80,
            // Title text on slice - white usually contrasts well with darker slice colors
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: sortedItemProfits.length == 1
                ? null // If only one slice, do not show badge
                : _buildBadge(entry.key, color, context), // Pass context
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
          color: Colors.grey.shade400, // Fixed color for 'Other'
          value: otherProfit,
          title: '${(otherProfit / totalPositiveProfit * 100).toStringAsFixed(1)}%',
          radius: 80,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          badgeWidget: _buildBadge('Other', Colors.grey.shade400, context), // Pass context
          badgePositionPercentageOffset: 1.05,
        ),
      );
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // Card background color adapts via theme.cardColor set in AppThemes
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Profit Distribution by Item',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.headlineSmall?.color, // Use theme text color
              ),
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
                // Safely extract title from badgeWidget, handling null if badgeWidget is null
                final String title = section.badgeWidget is Column && (section.badgeWidget as Column).children.first is Text
                    ? ((section.badgeWidget as Column).children.first as Text).data ?? ''
                    : (section.title ?? '').replaceAll('%', ''); // Use section.title if badge is null
                return _buildLegendItem(title.replaceAll('%', ''), section.color!, context); // Pass context
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build the badge for PieChartSectionData (Modified to accept BuildContext)
  Widget _buildBadge(String text, Color color, BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink(); // Return an empty widget if no text
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            // Use theme's onSurface color for badge text to ensure visibility on card background
            color: Theme.of(context).colorScheme.onSurface,
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

  // Helper to build legend items (Modified to accept BuildContext)
  Widget _buildLegendItem(String text, Color color, BuildContext context) {
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
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface), // Use theme's onSurface color for legend text
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }


  // Modified to accept BuildContext
  Widget _buildTotalsCard(BuildContext context) {
    return Container(
      // Use theme's card color for the totals card background
      color: Theme.of(context).cardColor,
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
    // Colors for specific totals (blue, orange, green) are kept as they are semantic.
    // Their visibility will depend on the overall background provided by _buildTotalsCard.
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
  _ProfitSource(this.data, this.context); // Modified constructor to accept context

  final List<Map<String, dynamic>> data;
  final BuildContext context; // Store context

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final row = data[index];

    // Get theme colors to make rows visible in dark mode
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color surfaceColor = Theme.of(context).colorScheme.surface;
    final Color surfaceVariantColor = Theme.of(context).colorScheme.surfaceVariant;

    return DataRow.byIndex(
      index: index,
      // Use theme-aware colors for alternating row backgrounds
      color: MaterialStateProperty.all(index.isEven ? surfaceColor : surfaceVariantColor),
      cells: [
        DataCell(Text('${index + 1}', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text(row['itemName'] ?? '', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text('${row['billno'] ?? ''}', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text(row['batchno'] ?? '', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text(row['date'] ?? '', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text('${row['qty'] ?? ''}', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text(row['packing'] ?? '', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text('₹${(row['sales'] ?? 0).toStringAsFixed(2)}', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text('₹${(row['purchase'] ?? 0).toStringAsFixed(2)}', style: TextStyle(color: onSurfaceColor))),
        DataCell(
          Text(
            '₹${(row['profit'] ?? 0).toStringAsFixed(2)}',
            style: TextStyle(
              // These colors are semantic (red for loss, green for profit)
              // and are assumed to contrast well enough with the adaptive row backgrounds.
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