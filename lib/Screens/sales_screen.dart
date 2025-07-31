

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/sales_controller.dart'; // Ensure SalesController is updated with SalesEntry model
import '../services/CsvDataServices.dart';

import '../widget/animated_Dots_LoadingText.dart';
import '../widget/custom_app_bar.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> with SingleTickerProviderStateMixin {
  // ─── controllers & state ──────────────────────────────────────
  final sc = Get.find<SalesController>();
  final csvDataService = Get.find<CsvDataService>();
  final nameCtrl = TextEditingController();
  final billCtrl = TextEditingController();

  String _fmt(DateTime d) => DateFormat('dd‑MMM').format(d);
  DateTime picked = DateUtils.dateOnly(DateTime.now());

  bool asc = true;
  bool showCash = true; // Default to showing cash sales
  bool showCredit = false;

  // Animation controller for content fade/slide
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeIn,
      ),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeOutCubic,
      ),
    );

    // Trigger animation when data is loaded
    sc.isLoading.listen((isLoading) {
      if (_animationController != null) {
        if (!isLoading && sc.error.value == null) {
          _animationController!.forward(from: 0.0);
        } else if (isLoading) {
          _animationController!.reset(); // Reset when loading starts
        }
      }
    });

    // Manually trigger animation once initially if data is already loaded (e.g., from cache)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_animationController != null) {
        if (!sc.isLoading.value && sc.error.value == null) {
          _animationController!.forward(from: 0.0);
        }
      }
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    billCtrl.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  // ─── helpers ──────────────────────────────────────────────────
  // Filter method now returns List<SalesEntry>
  List<SalesEntry> _filtered() {
    final list = sc.filter(nameQ: nameCtrl.text, billQ: billCtrl.text, date: picked)
      ..sort((a, b) {
        final d1 = a.entryDate; // Access entryDate directly from SalesEntry
        final d2 = b.entryDate; // Access entryDate directly from SalesEntry
        if (d1 == null || d2 == null) return 0;
        return asc ? d1.compareTo(d2) : d2.compareTo(d1);
      });
    return list;
  }

  // Sum method now takes List<SalesEntry>
  double _sum(List<SalesEntry> rows) =>
      rows.fold(0.0, (p, e) => p + e.amount); // Access amount directly from SalesEntry

  // ─── build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Get theme colors and text styles once
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color cardColor = Theme.of(context).cardColor;
    final Color borderColor = Theme.of(context).colorScheme.outline;
    final Color shadowColor = Theme.of(context).shadowColor;
    final Color errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('Sales Report'),
        actions: [
          Obx(() => IconButton(
            icon: Icon(
              Icons.refresh, 
              color: sc.isLoading.value ? onSurfaceColor.withOpacity(0.5) : primaryColor,
            ),
            tooltip: 'Refresh Data',
            onPressed: sc.isLoading.value ? null : () async {
              _animationController?.reset();
              await sc.fetchSales(forceRefresh: true);
            },
          )),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: primaryColor,
            onRefresh: () async {
              _animationController?.reset();
              await sc.fetchSales(forceRefresh: false); // Load from cache, don't force download
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Obx(() {
                if (sc.isLoading.value) {
                  return Center(child: DotsWaveLoadingText(color: onSurfaceColor));
                }
                if (sc.error.value != null) {
                  return Center(
                    child: Text(
                      '❌ ${sc.error.value!}',
                      style: TextStyle(color: errorColor),
                    ),
                  );
                }

                if (_fadeAnimation == null || _slideAnimation == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = _filtered();
                final cashRows = data
                    .where((s) => s.paymentMode.toLowerCase() == 'cash') // Access paymentMode directly
                    .toList();
                final creRows = data
                    .where((s) => s.paymentMode.toLowerCase() == 'credit') // Access paymentMode directly
                    .toList();

                final totCash = _sum(cashRows);
                final totCredit = _sum(creRows);

                return FadeTransition(
                  opacity: _fadeAnimation!,
                  child: SlideTransition(
                    position: _slideAnimation!,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 100),
                      children: [
                        _filters(context),
                        const SizedBox(height: 8),
                        _cacheStatusIndicator(context),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _totBtn(
                                'Cash Sale',
                                totCash,
                                showCash,
                                    () {
                                  setState(() {
                                    showCash = !showCash;
                                    showCredit = false;
                                    _animationController?.forward(from: 0.0);
                                  });
                                },
                                context,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _totBtn(
                                'Credit Sale',
                                totCredit,
                                showCredit,
                                    () {
                                  setState(() {
                                    showCredit = !showCredit;
                                    showCash = false;
                                    _animationController?.forward(from: 0.0);
                                  });
                                },
                                context,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.05),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: showCash
                              ? KeyedSubtree(
                            key: const ValueKey('cashTable'),
                            child: _paginatedTable(cashRows, context),
                          )
                              : KeyedSubtree(
                            key: const ValueKey('creditTable'),
                            child: _paginatedTable(creRows, context),
                          ),
                        ),
                      ],
                    ),
                  ),
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
              final currentFilteredData = sc.filter(nameQ: nameCtrl.text, billQ: billCtrl.text, date: picked);

              final totCash = _sum(
                currentFilteredData.where((s) => s.paymentMode.toLowerCase() == 'cash').toList(),
              );
              final totCredit = _sum(
                currentFilteredData.where((s) => s.paymentMode.toLowerCase() == 'credit').toList(),
              );
              final grandTotal = totCash + totCredit;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: onSurfaceColor,
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: grandTotal),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, value, child) {
                        return Text(
                          '₹${value.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        );
                      },
                    ),
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
      _searchBox(nameCtrl, 'Name', ctx),
      const SizedBox(width: 8),
      _searchBox(billCtrl, 'Bill No', ctx),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.date_range, color: Theme.of(ctx).iconTheme.color),
            tooltip: DateFormat('dd‑MMM‑yyyy').format(picked),
            onPressed: () async {
              final d = await showDatePicker(
                context: ctx,
                initialDate: picked,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: Theme.of(context).primaryColor,
                        onPrimary: Theme.of(context).colorScheme.onPrimary,
                        surface: Theme.of(context).colorScheme.surface,
                        onSurface: Theme.of(context).colorScheme.onSurface,
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (d != null) {
                setState(() => picked = DateUtils.dateOnly(d));
                _animationController?.forward(from: 0.0);
              }
            },
          ),
          Text(
            _fmt(picked),
            style: TextStyle(fontSize: 11, color: Theme.of(ctx).textTheme.bodySmall?.color),
          ),
        ],
      ),
      const SizedBox(width: 4),
      IconButton(
        tooltip: asc ? 'Sort Asc' : 'Sort Desc',
        icon: Icon(asc ? Icons.arrow_upward : Icons.arrow_downward, color: Theme.of(ctx).iconTheme.color),
        onPressed: () {
          setState(() => asc = !asc);
          _animationController?.forward(from: 0.0);
        },
      ),
    ],
  );

  Widget _searchBox(TextEditingController c, String hint, BuildContext ctx) => Expanded(
    child: TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: hint,
        filled: true,
        fillColor: Theme.of(ctx).inputDecorationTheme.fillColor ?? Theme.of(ctx).colorScheme.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(ctx).colorScheme.outline),
        ),
        labelStyle: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7)),
        floatingLabelStyle: TextStyle(color: Theme.of(ctx).primaryColor),
        hintStyle: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5)),
      ),
      style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
      onChanged: (_) {
        setState(() {});
        _animationController?.forward(from: 0.0);
      },
    ),
  );

  Widget _totBtn(String label, double amt, bool active, VoidCallback tap, BuildContext ctx) =>
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? Theme.of(ctx).primaryColor : Theme.of(ctx).colorScheme.surfaceVariant,
          foregroundColor: active ? Theme.of(ctx).colorScheme.onPrimary : Theme.of(ctx).colorScheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: active ? 8.0 : 2.0,
          animationDuration: const Duration(milliseconds: 200),
        ),
        onPressed: tap,
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: amt),
              duration: const Duration(milliseconds: 400),
              builder: (context, value, child) {
                return Text(
                  '₹${value.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                );
              },
            ),
          ],
        ),
      );

  // ───────────────────── paginated table ──────────────────────
  // Modified to accept BuildContext and list of SalesEntry
  Widget _paginatedTable(List<SalesEntry> rows, BuildContext ctx) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No records for selected filters.',
            style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7)),
          ),
        ),
      );
    }

    final totalRows = rows.length + 1; // +1 for summary row
    final rowsPer = totalRows < 10 ? (totalRows > 0 ? totalRows : 1) : 10;

    final Color onSurfaceColor = Theme.of(ctx).colorScheme.onSurface;
    final Color surfaceColor = Theme.of(ctx).colorScheme.surface;
    final Color surfaceVariantColor = Theme.of(ctx).colorScheme.surfaceVariant;

    return PaginatedDataTable(
      headingRowColor: MaterialStateProperty.all(surfaceVariantColor),
      columnSpacing: 28,
      rowsPerPage: rowsPer,
      availableRowsPerPage: totalRows < 10 ? [rowsPer] : const [10, 25, 50],
      showFirstLastButtons: true,
      columns: [
        DataColumn(label: Text('Sr.', style: TextStyle(color: onSurfaceColor))),
        DataColumn(label: Text('Name', style: TextStyle(color: onSurfaceColor))),
        DataColumn(label: Text('Bill No', style: TextStyle(color: onSurfaceColor))),
        DataColumn(label: Text('Date', style: TextStyle(color: onSurfaceColor))),
        DataColumn(label: Text('Amount', style: TextStyle(color: onSurfaceColor))),
        // New DataColumn for details
        DataColumn(label: Text('Details', style: TextStyle(color: onSurfaceColor))),
      ],
      source: _SalesSource(rows, ctx, _showSalesItemDetailsDialog), // Pass the dialog function
    );
  }

  // ───────────────────── Dialog for Sales Item Details ──────────────────────
  void _showSalesItemDetailsDialog(BuildContext context, SalesEntry salesEntry) {
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color surfaceColor = Theme.of(context).colorScheme.surface;
    final Color surfaceVariantColor = Theme.of(context).colorScheme.surfaceVariant;
    final Color primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Details for Bill No: ${salesEntry.billNo}',
            style: TextStyle(color: onSurfaceColor, fontWeight: FontWeight.bold),
          ),
          content: salesEntry.items.isEmpty
              ? Text(
            'No item details found for this bill.',
            style: TextStyle(color: onSurfaceColor.withOpacity(0.7)),
          )
              : SizedBox(
            width: double.maxFinite, // Allow dialog to take max width
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, // Allow horizontal scrolling for table
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(surfaceVariantColor),
                dataRowColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                  if (states.contains(MaterialState.selected)) {
                    return Theme.of(context).colorScheme.primary.withOpacity(0.08);
                  }
                  return null; // Use default color for other states
                }),
                columns: [
                  DataColumn(label: Text('Item Name', style: TextStyle(color: onSurfaceColor))),
                  DataColumn(label: Text('Item Code', style: TextStyle(color: onSurfaceColor))),
                  DataColumn(label: Text('Batch No', style: TextStyle(color: onSurfaceColor))),
                  DataColumn(label: Text('Packing', style: TextStyle(color: onSurfaceColor))),
                  DataColumn(label: Text('Qty', style: TextStyle(color: onSurfaceColor))),
                  DataColumn(label: Text('Rate/qty', style: TextStyle(color: onSurfaceColor))),
                  DataColumn(label: Text('Amt', style: TextStyle(color: onSurfaceColor))),
                ],
                rows: salesEntry.items.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(Text(item.itemName, style: TextStyle(color: onSurfaceColor))),
                      DataCell(Text(item.itemCode, style: TextStyle(color: onSurfaceColor))),
                      DataCell(Text(item.batchNo, style: TextStyle(color: onSurfaceColor))),
                      DataCell(Text(item.packing, style: TextStyle(color: onSurfaceColor))),
                      DataCell(Text(item.quantity.toStringAsFixed(2), style: TextStyle(color: onSurfaceColor))),
                      DataCell(Text(item.rate.toStringAsFixed(2), style: TextStyle(color: onSurfaceColor))),
                      DataCell(Text(item.amount.toStringAsFixed(2), style: TextStyle(color: onSurfaceColor))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close', style: TextStyle(color: primaryColor)),
            ),
          ],
        );
      },
    );
  }

  // ─── Cache Status Indicator ──────────────────────────────────
  Widget _cacheStatusIndicator(BuildContext ctx) {
    final Color surfaceVariantColor = Theme.of(ctx).colorScheme.surfaceVariant;
    final Color onSurfaceColor = Theme.of(ctx).colorScheme.onSurface;
    final Color primaryColor = Theme.of(ctx).primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceVariantColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(ctx).colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            size: 16,
            color: onSurfaceColor.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              csvDataService.getCacheStatus(),
              style: TextStyle(
                fontSize: 12,
                color: onSurfaceColor.withOpacity(0.8),
              ),
            ),
          ),
          if (!csvDataService.isCacheValid())
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Expired',
                style: TextStyle(
                  fontSize: 10,
                  color: primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────── DataTableSource ──────────────────────
// Modified to accept List<SalesEntry> and the dialog function
class _SalesSource extends DataTableSource {
  _SalesSource(this.data, this.context, this.showDetailsDialog) {
    grandTotal = data.fold<double>(0, (p, e) => p + e.amount); // Access amount directly
  }

  final List<SalesEntry> data;
  final BuildContext context;
  final Function(BuildContext, SalesEntry) showDetailsDialog; // Function to show details dialog
  late final double grandTotal;

  @override
  DataRow? getRow(int index) {
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color surfaceColor = Theme.of(context).colorScheme.surface;
    final Color surfaceVariantColor = Theme.of(context).colorScheme.surfaceVariant;
    final Color primaryColor = Theme.of(context).primaryColor;

    // summary row
    if (index == data.length) {
      return DataRow.byIndex(
        index: index,
        color: MaterialStateProperty.all(surfaceVariantColor),
        cells: [
          const DataCell(Text('')),
          DataCell(Text('Grand Total',
              style: TextStyle(fontWeight: FontWeight.bold, color: onSurfaceColor))),
          const DataCell(Text('-')),
          const DataCell(Text('-')),
          DataCell(Text('₹${grandTotal.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
          const DataCell(Text('')), // Empty cell for the 'Details' column in summary row
        ],
      );
    }

    // normal row with even/odd background
    final salesEntry = data[index]; // Now using SalesEntry object
    return DataRow.byIndex(
      index: index,
      color: MaterialStateProperty.all(
          index.isEven ? surfaceColor : surfaceVariantColor.withOpacity(0.7)),
      cells: [
        DataCell(Text('${index+1}', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text(salesEntry.accountName, style: TextStyle(color: onSurfaceColor))), // Access directly
        DataCell(Text(salesEntry.billNo, style: TextStyle(color: onSurfaceColor))), // Access directly
        DataCell(Text(
            salesEntry.entryDate != null
                ? DateFormat('dd‑MMM‑yyyy').format(salesEntry.entryDate!)
                : '-',
            style: TextStyle(color: onSurfaceColor))),
        DataCell(Text('₹${salesEntry.amount.toStringAsFixed(2)}', style: TextStyle(color: onSurfaceColor))), // Access directly
        // New DataCell with an IconButton to show details
        DataCell(
          IconButton(
            icon: Icon(Icons.info_outline, color: primaryColor), // Use primary color for icon
            tooltip: 'View Item Details',
            onPressed: () {
              showDetailsDialog(context, salesEntry); // Call the dialog function
            },
          ),
        ),
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