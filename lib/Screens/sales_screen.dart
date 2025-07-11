// lib/screens/sales_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';                     // ← NEW
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

  // ───────────────────────────────────────────────────────── UI
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
          if (ctrl.isLoading.value)     return const Center(child: CircularProgressIndicator());
          if (ctrl.error.value != null) return Center(child: Text('❌ ${ctrl.error.value}'));

          // ── filter + sort ─────────────────────────────────────
          final list = ctrl.filter(
            nameQ: nameCtrl.text,
            billQ: billCtrl.text,
            date:   picked,
          )..sort((a, b) {
            final d1 = a['EntryDate'] as DateTime?;
            final d2 = b['EntryDate'] as DateTime?;
            if (d1 == null || d2 == null) return 0;
            return asc ? d1.compareTo(d2) : d2.compareTo(d1);
          });

          final cash   = list.where((m) => m['PaymentMode']?.toString().toLowerCase() == 'cash'  ).toList();
          final credit = list.where((m) => m['PaymentMode']?.toString().toLowerCase() == 'credit').toList();

          double sum(List<Map<String, dynamic>> rows) =>
              rows.fold(0.0, (p, e) => p + (e['Amount'] ?? 0));

          final totCash   = sum(cash);
          final totCredit = sum(credit);

          // build once → reuse for cards + charts
          final pieSections = [
            PieChartSectionData(
              title: 'Cash\n₹${totCash.toStringAsFixed(0)}',
              value: totCash,
              color: Colors.green,
              radius: 70,
            ),
            PieChartSectionData(
              title: 'Credit\n₹${totCredit.toStringAsFixed(0)}',
              value: totCredit,
              color: Colors.orange,
              radius: 70,
            ),
          ];

          final barGroups = _buildBarGroups(list);

          // ── screen ────────────────────────────────────────────
          return Column(
            children: [
              _filters(context),
              const SizedBox(height: 10),

              // ─ Pie + Bars (analytics) ─────────────────────────
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 30,
                          sections: pieSections,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: BarChart(
                        BarChartData(
                          barGroups: barGroups,
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 18,
                                getTitlesWidget: (v, _) => Text(DateFormat('d').format(DateTime.fromMillisecondsSinceEpoch(v.toInt()))),
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: FlGridData(show: false),
                          alignment: BarChartAlignment.spaceBetween,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ─ Two summary buttons ────────────────────────────
              Row(
                children: [
                  Expanded(child: _totButton('Cash Sale',   totCash,   showCash,   () => setState(() { showCash = !showCash; showCredit = false; }))),
                  const SizedBox(width: 8),
                  Expanded(child: _totButton('Credit Sale', totCredit, showCredit, () => setState(() { showCredit = !showCredit; showCash = false; }))),
                ],
              ),

              if (showCash)   Expanded(child: _saleList(cash)),
              if (showCredit) Expanded(child: _saleList(credit)),

              const Divider(height: 24),
              Text('Total  ₹${(totCash + totCredit).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          );
        }),
      ),
    );
  }

  // ───────────────────────────────────────── Filters & helpers
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

  Widget _totButton(String label, double amt, bool active, VoidCallback tap) =>
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

  Widget _saleList(List<Map<String, dynamic>> rows) => ListView.builder(
    itemCount: rows.length,
    itemBuilder: (_, i) {
      final m = rows[i];
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          title: Text(m['AccountName'] ?? ''),
          subtitle: Text(
              'Bill No: ${m['BillNo']} • ${DateFormat('dd‑MMM‑yyyy').format(m['EntryDate'])}'),
          trailing: Text('₹${(m['Amount'] ?? 0).toStringAsFixed(2)}'),
        ),
      );
    },
  );

  // build bar‑chart groups (date → total)
  List<BarChartGroupData> _buildBarGroups(List<Map<String, dynamic>> rows) {
    final map = <DateTime, double>{};
    for (final m in rows) {
      final d = m['EntryDate'] as DateTime?;
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      map.update(day, (v) => v + (m['Amount'] ?? 0), ifAbsent: () => (m['Amount'] ?? 0));
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // limit to last 10 days to keep chart light
    final recent = sorted.takeLast(10).toList();
    return [
      for (var i = 0; i < recent.length; i++)
        BarChartGroupData(
          x: recent[i].key.millisecondsSinceEpoch,
          barRods: [
            BarChartRodData(
              toY: recent[i].value,
              width: 10,
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
    ];
  }
}

// helper extension
extension<T> on List<T> {
  Iterable<T> takeLast(int n) => skip(length > n ? length - n : 0);
}
