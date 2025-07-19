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

class _SalesScreenState extends State<SalesScreen> with SingleTickerProviderStateMixin {
  // ─── controllers & state ──────────────────────────────────────
  final sc = Get.find<SalesController>();
  final nameCtrl = TextEditingController();
  final billCtrl = TextEditingController();

  String _fmt(DateTime d) => DateFormat('dd‑MMM').format(d);
  DateTime picked = DateUtils.dateOnly(DateTime.now());

  bool asc = true;
  bool showCash = true; // Default to showing cash sales
  bool showCredit = false;

  // Animation controller for content fade/slide
  // Changed to nullable to defensively handle potential late initialization issues
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
        parent: _animationController!, // Assert non-null after initialization
        curve: Curves.easeIn,
      ),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController!, // Assert non-null after initialization
        curve: Curves.easeOutCubic,
      ),
    );

    // Trigger animation when data is loaded
    sc.isLoading.listen((isLoading) {
      if (_animationController != null) { // Add null check
        if (!isLoading && sc.error.value == null) {
          _animationController!.forward(from: 0.0);
        } else if (isLoading) {
          _animationController!.reset(); // Reset when loading starts
        }
      }
    });

    // Manually trigger animation once initially if data is already loaded (e.g., from cache)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_animationController != null) { // Add null check
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
    _animationController?.dispose(); // Use null-safe dispose
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
    // Get theme colors and text styles once
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color cardColor = Theme.of(context).cardColor;
    final Color borderColor = Theme.of(context).colorScheme.outline; // A general border color
    final Color shadowColor = Theme.of(context).shadowColor;
    final Color errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: const CustomAppBar(title: Text('Sales Report')),
      body: Stack(
        children: [
          RefreshIndicator(
            color: primaryColor, // Use theme primary color for refresh indicator
            onRefresh: () async {
              _animationController?.reset(); // Null-safe reset
              await sc.fetchSales();
              // Animation will be triggered by the isLoading listener
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Obx(() {
                if (sc.isLoading.value) {
                  // Use theme-aware color for loading text
                  return Center(child: DotsWaveLoadingText(color: onSurfaceColor));
                }
                if (sc.error.value != null) {
                  return Center(
                    child: Text(
                      '❌ ${sc.error.value!}',
                      style: TextStyle(color: errorColor), // Use theme error color
                    ),
                  );
                }

                // Add null check here before using animations
                if (_fadeAnimation == null || _slideAnimation == null) {
                  // Fallback: Return a SizedBox.shrink() or a simple loading indicator
                  // if animations are not yet initialized (should not happen with late, but for robustness)
                  return const Center(child: CircularProgressIndicator());
                }

                final data = _filtered();
                final cashRows = data
                    .where((m) => m['PaymentMode'].toString().toLowerCase() == 'cash')
                    .toList();
                final creRows = data
                    .where((m) => m['PaymentMode'].toString().toLowerCase() == 'credit')
                    .toList();

                final totCash = _sum(cashRows);
                final totCredit = _sum(creRows);

                return FadeTransition(
                  opacity: _fadeAnimation!, // Assert non-null
                  child: SlideTransition(
                    position: _slideAnimation!, // Assert non-null
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 100),
                      children: [
                        _filters(context),
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
                                    showCredit = false; // Ensure only one is active at a time
                                    _animationController?.forward(from: 0.0); // Animate table change
                                  });
                                },
                                context, // Pass context
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
                                    showCash = false; // Ensure only one is active at a time
                                    _animationController?.forward(from: 0.0); // Animate table change
                                  });
                                },
                                context, // Pass context
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Use AnimatedSwitcher for smooth transition between tables
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
                            key: const ValueKey('cashTable'), // Unique key for AnimatedSwitcher
                            child: _paginatedTable(cashRows, context),
                          )
                              : KeyedSubtree(
                            key: const ValueKey('creditTable'), // Unique key for AnimatedSwitcher
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
                currentFilteredData.where((m) => m['PaymentMode'].toString().toLowerCase() == 'cash').toList(),
              );
              final totCredit = _sum(
                currentFilteredData.where((m) => m['PaymentMode'].toString().toLowerCase() == 'credit').toList(),
              );
              final grandTotal = totCash + totCredit;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: cardColor, // Use theme card color for background
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor), // Use theme-aware border color
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor.withOpacity(0.2), // Use theme shadow color
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
                        color: onSurfaceColor, // Text color on card background
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
                            color: primaryColor, // Use theme primary color for highlight
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
      _searchBox(nameCtrl, 'Name', ctx), // Pass context
      const SizedBox(width: 8),
      _searchBox(billCtrl, 'Bill No', ctx), // Pass context
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.date_range, color: Theme.of(ctx).iconTheme.color), // Use theme icon color
            tooltip: DateFormat('dd‑MMM‑yyyy').format(picked),
            onPressed: () async {
              final d = await showDatePicker(
                context: ctx,
                initialDate: picked,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  // Ensure date picker itself respects theme
                  return Theme(
                    data: Theme.of(context).copyWith(
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
              if (d != null) {
                setState(() => picked = DateUtils.dateOnly(d));
                _animationController?.forward(from: 0.0); // Animate table change
              }
            },
          ),
          Text(
            _fmt(picked),
            style: TextStyle(fontSize: 11, color: Theme.of(ctx).textTheme.bodySmall?.color), // Theme-aware text color
          ),
        ],
      ),
      const SizedBox(width: 4),
      IconButton(
        tooltip: asc ? 'Sort Asc' : 'Sort Desc',
        icon: Icon(asc ? Icons.arrow_upward : Icons.arrow_downward, color: Theme.of(ctx).iconTheme.color), // Use theme icon color
        onPressed: () {
          setState(() => asc = !asc);
          _animationController?.forward(from: 0.0); // Animate table change
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
        // Use theme-aware fill color
        fillColor: Theme.of(ctx).inputDecorationTheme.fillColor ?? Theme.of(ctx).colorScheme.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(ctx).colorScheme.outline), // Theme-aware border
        ),
        // Ensure label text and input text colors are theme-aware
        labelStyle: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7)),
        floatingLabelStyle: TextStyle(color: Theme.of(ctx).primaryColor),
        hintStyle: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5)),
      ),
      style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface), // Input text color
      onChanged: (_) {
        setState(() {});
        _animationController?.forward(from: 0.0); // Animate table change
      },
    ),
  );

  Widget _totBtn(String label, double amt, bool active, VoidCallback tap, BuildContext ctx) =>
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          // Use theme-aware background colors
          backgroundColor: active ? Theme.of(ctx).primaryColor : Theme.of(ctx).colorScheme.surfaceVariant,
          // Use theme-aware foreground colors
          foregroundColor: active ? Theme.of(ctx).colorScheme.onPrimary : Theme.of(ctx).colorScheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          // Add a slight elevation animation
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
  // Modified to accept BuildContext
  Widget _paginatedTable(List<Map<String, dynamic>> rows, BuildContext ctx) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No records for selected filters.',
            style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7)), // Theme-aware text color
          ),
        ),
      );
    }

    final totalRows = rows.length + 1; // +1 summary row
    // Ensure rowsPerPage is at least 1 and not more than totalRows or a sensible max
    final rowsPer = totalRows < 10 ? (totalRows > 0 ? totalRows : 1) : 10;


    // Get theme colors for the table
    final Color onSurfaceColor = Theme.of(ctx).colorScheme.onSurface;
    final Color surfaceColor = Theme.of(ctx).colorScheme.surface;
    final Color surfaceVariantColor = Theme.of(ctx).colorScheme.surfaceVariant;

    return PaginatedDataTable(
      // Use theme-aware color for heading row
      headingRowColor: MaterialStateProperty.all(surfaceVariantColor),
      columnSpacing: 28,
      rowsPerPage: rowsPer,
      availableRowsPerPage: totalRows < 10 ? [rowsPer] : const [10, 25, 50], // Provide more options
      showFirstLastButtons: true,
      columns: [
        // Ensure column labels also respect text theme
        DataColumn(label: Text('Sr.', style: TextStyle(color: onSurfaceColor))),
        DataColumn(label: Text('Name', style: TextStyle(color: onSurfaceColor))),
        DataColumn(label: Text('Bill No', style: TextStyle(color: onSurfaceColor))),
        DataColumn(label: Text('Date', style: TextStyle(color: onSurfaceColor))),
        DataColumn(label: Text('Amount', style: TextStyle(color: onSurfaceColor))),
      ],
      // Pass context to _SalesSource
      source: _SalesSource(rows, ctx),
    );
  }
}

// ───────────────────── DataTableSource ──────────────────────
// Modified to accept BuildContext
class _SalesSource extends DataTableSource {
  _SalesSource(this.data, this.context) {
    grandTotal = data.fold<double>(0, (p, e) => p + (e['Amount'] ?? 0));
  }

  final List<Map<String, dynamic>> data;
  final BuildContext context; // Store context
  late final double grandTotal;

  @override
  DataRow? getRow(int index) {
    // Get theme colors
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color surfaceColor = Theme.of(context).colorScheme.surface;
    final Color surfaceVariantColor = Theme.of(context).colorScheme.surfaceVariant;
    final Color primaryColor = Theme.of(context).primaryColor;

    // summary row
    if (index == data.length) {
      return DataRow.byIndex(
        index: index,
        // Use theme-aware color for summary row
        color: MaterialStateProperty.all(surfaceVariantColor),
        cells: [
          const DataCell(Text('')),
          DataCell(Text('Grand Total',
              style: TextStyle(fontWeight: FontWeight.bold, color: onSurfaceColor))), // Theme-aware text color
          const DataCell(Text('-')),
          const DataCell(Text('-')),
          DataCell(Text('₹${grandTotal.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))), // Theme-aware text color (e.g., primary for total)
        ],
      );
    }

    // normal row with even/odd background
    final m = data[index];
    return DataRow.byIndex(
      index: index,
      // Use theme-aware colors for alternating row backgrounds
      color: MaterialStateProperty.all(
          index.isEven ? surfaceColor : surfaceVariantColor.withOpacity(0.7)), // Slightly less opaque for odd rows
      cells: [
        DataCell(Text('${index + 1}', style: TextStyle(color: onSurfaceColor))), // Theme-aware text color
        DataCell(Text(m['AccountName'] ?? '', style: TextStyle(color: onSurfaceColor))), // Theme-aware text color
        DataCell(Text(m['BillNo'].toString(), style: TextStyle(color: onSurfaceColor))), // Theme-aware text color
        DataCell(Text(DateFormat('dd‑MMM‑yyyy').format(m['EntryDate']), style: TextStyle(color: onSurfaceColor))), // Theme-aware text color
        DataCell(Text('₹${(m['Amount'] ?? 0).toStringAsFixed(2)}', style: TextStyle(color: onSurfaceColor))), // Theme-aware text color
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