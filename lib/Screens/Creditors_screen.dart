import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/customerLedger_Controller.dart';
import '../widget/animated_Dots_LoadingText.dart';
import '../widget/custom_app_bar.dart';

class CreditorsScreen extends StatefulWidget {
  const CreditorsScreen({super.key});

  @override
  State<CreditorsScreen> createState() => _CreditorsScreen();
}

class _CreditorsScreen extends State<CreditorsScreen> {
  final ctrl = Get.find<CustomerLedgerController>();

  final searchCtrl = TextEditingController();
  final RxString searchQ    = ''.obs;        // text filter
  final RxString filterType = 'All'.obs;     // All / Customer / Supplier

  final ScrollController listCtrl = ScrollController();
  final RxBool showFab = false.obs;

  @override
  void initState() {
    super.initState();
    listCtrl.addListener(() => showFab.value = listCtrl.offset > 300);
    
    // Ensure data is loaded when screen is accessed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctrl.ensureDataLoaded();
    });
  }

  @override
  void dispose() {
    listCtrl.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Get theme colors and text styles once
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary;
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color cardColor = Theme.of(context).cardColor;
    final Color shadowColor = Theme.of(context).shadowColor;
    final Color errorColor = Theme.of(context).colorScheme.error;
    final Color surfaceVariantColor = Theme.of(context).colorScheme.surfaceVariant;


    return Scaffold(
      appBar: CustomAppBar(title: Text('Creditors', style: Theme.of(context).appBarTheme.titleTextStyle)),
      floatingActionButton: Obx(() => showFab.value
          ? FloatingActionButton(
        heroTag: 'toTopBtn',
        backgroundColor: primaryColor, // Use theme primary color
        onPressed: () => listCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        ),
        child: Icon(Icons.arrow_upward, color: onPrimaryColor), // Use theme onPrimary color
      )
          : const SizedBox.shrink()),
      body: Column(
        children: [
          // ───── search bar ─────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name',
                prefixIcon: Icon(Icons.search, color: primaryColor), // Use theme primary color
                suffixIcon: searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                  icon: Icon(Icons.clear, color: Theme.of(context).iconTheme.color), // Use theme icon color
                  onPressed: () {
                    searchCtrl.clear();
                    searchQ.value = '';
                  },
                ),
                filled: true,
                // Use theme-aware fill color, fallback to surfaceVariant
                fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? surfaceVariantColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                hintStyle: TextStyle(color: onSurfaceColor.withOpacity(0.6)), // Hint text color
                labelStyle: TextStyle(color: onSurfaceColor), // Label text color
              ),
              style: TextStyle(color: onSurfaceColor), // Input text color
              onChanged: (v) => searchQ.value = v,
            ),
          ),

          // ───── type filter chips ─────
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            child: Obx(
                  () => Wrap(
                spacing: 8,
                children: [
                  _chip('All', context), // Pass context
                  _chip('Customer', context), // Pass context
                  _chip('Supplier', context), // Pass context
                ],
              ),
            ),
          ),

          // ───── list / loading / empty / pull‑to‑refresh ─────
          Expanded(
            child: Obx(() {
              // 1️⃣ full‑screen loader only on FIRST load
              if (ctrl.isLoading.value && ctrl.creditors.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DotsWaveLoadingText(color: onSurfaceColor),
                      const SizedBox(height: 16),
                      Text(
                        'Loading creditors data...',
                        style: TextStyle(color: onSurfaceColor.withOpacity(0.7)),
                      ),
                    ],
                  ),
                );
              }

              // 2️⃣ show error, but leave search & chips in place
              if (ctrl.error.value != null) {
                return Center(
                  child: Text(
                    '❌  ${ctrl.error.value!}',
                    style: TextStyle(color: errorColor), // Use theme error color
                  ),
                );
              }

              // 3️⃣ apply filters
              final creditors = [...ctrl.creditors]
                ..retainWhere((d) => d['name']
                    .toString()
                    .toLowerCase()
                    .contains(searchQ.value.toLowerCase()))
                ..retainWhere((d) {
                  if (filterType.value == 'All') return true;
                  return d['type']
                      .toString()
                      .toLowerCase() ==
                      filterType.value.toLowerCase();
                })
                ..sort((a, b) => a['name']
                    .toString()
                    .toLowerCase()
                    .compareTo(b['name'].toString().toLowerCase()));

              // 4️⃣ empty‑state placeholder
              if (creditors.isEmpty) {
                return Center(child: Text('No creditors found.', style: TextStyle(color: onSurfaceColor))); // Use theme-aware color
              }

              // 5️⃣ list with pull‑to‑refresh
              return RefreshIndicator(
                onRefresh: () => ctrl.refreshCreditors(),   // ← fixed to use creditors refresh
                color: primaryColor, // Use theme primary color for refresh indicator
                child: ListView.builder(
                  controller: listCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: creditors.length,
                  itemBuilder: (_, i) => _debtorTile(creditors[i], context), // Pass context
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ──────────────────── helpers ─────────────────────────────
  ChoiceChip _chip(String label, BuildContext context) {
    final bool isSelected = filterType.value == label;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary;
    final Color surfaceColor = Theme.of(context).colorScheme.surface;
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? onPrimaryColor : onSurfaceColor, // Text color for selected/unselected
        ),
      ),
      selected: isSelected,
      // Use theme's primary color for selected, and default surface for unselected
      selectedColor: primaryColor,
      backgroundColor: surfaceColor, // Background for unselected chips
      onSelected: (_) => filterType.value = label,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? primaryColor : onSurfaceColor.withOpacity(0.5), // Border for selected/unselected
        ),
      ),
    );
  }

  Widget _badge(String label, dynamic value, {TextAlign align = TextAlign.left}) {
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 14, color: onSurfaceColor), // Use theme-aware color
        children: [
          TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: value?.toString() ?? '-'),
        ],
      ),
      textAlign: align,
      softWrap: true,
    );
  }

  // single card (Name • Area • Mobile • Balance)
  Widget _debtorTile(Map<String, dynamic> d, BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color errorColor = Theme.of(context).colorScheme.error;
    final Color cardColor = Theme.of(context).cardColor;
    final Color shadowColor = Theme.of(context).shadowColor;
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    final bal = (d['closingBalance'] as double?) ?? 0.0;
    final area = d['area'] ?? '-';
    final mobile = d['mobile'] ?? '-';

    // Determine balance display and color
    final displayBal = bal.abs().toStringAsFixed(2);
    final balanceType = bal <= 0 ? 'Dr' : 'Cr'; // Assuming positive balance is Debit, negative is Credit
    // For creditors, if bal > 0, they owe us (good - primaryColor), if bal <= 0, we owe them (bad - errorColor)
    final balanceColor = bal <= 0 ? primaryColor : errorColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor, // Use theme card color
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: shadowColor.withOpacity(0.12), // Use theme shadow color
                  blurRadius: 2, offset: const Offset(0, 4)),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // accent bar
                Container(
                  width: 8,
                  decoration: BoxDecoration(
                    color: primaryColor, // Use theme primary color
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),

                // main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // name + balance
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                d['name'] ?? '',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: onSurfaceColor // Ensure text is visible
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              backgroundColor: primaryColor.withOpacity(0.1), // Theme-aware background
                              padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                              label: Text(
                                '₹$displayBal $balanceType',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: balanceColor), // Dynamic color based on balance
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        _badge('Area:', area),
                        _badge('Mobile:', mobile),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}