import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/customerLedger_Controller.dart';
import '../widget/animated_Dots_LoadingText.dart';
import '../widget/cache_status_indicator.dart';
import '../widget/custom_app_bar.dart';

class DebtorsScreen extends StatefulWidget {
  const DebtorsScreen({super.key});

  @override
  State<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends State<DebtorsScreen> {
  final ctrl = Get.find<CustomerLedgerController>();

  final searchCtrl = TextEditingController();
  final RxString searchQ    = ''.obs;        // text filter
  final RxString filterType = 'All'.obs;     // All / Customer / Supplier

  final ScrollController listCtrl = ScrollController();
  final RxBool showFab = false.obs;
  final RxBool isLoadingMore = false.obs;

  @override
  void initState() {
    super.initState();
    listCtrl.addListener(_onScroll);

    // Ensure data is loaded
    if (ctrl.debtors.isEmpty && !ctrl.isLoading.value) {
      ctrl.loadData();
    }
  }

  void _onScroll() {
    showFab.value = listCtrl.offset > 300;

    // Load more data when near the bottom
    if (listCtrl.position.pixels >= listCtrl.position.maxScrollExtent - 200) {
      _loadMoreIfNeeded();
    }
  }

  void _loadMoreIfNeeded() async {
    if (isLoadingMore.value || !ctrl.hasMoreDebtors.value) return;

    isLoadingMore.value = true;
    try {
      await Future.delayed(Duration(milliseconds: 100)); // Small delay to show loading
      ctrl.loadMoreDebtors();
    } finally {
      isLoadingMore.value = false;
    }
  }

  @override
  void dispose() {
    listCtrl.removeListener(_onScroll);
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
      appBar: CustomAppBar(title: Text('Debtors', style: Theme.of(context).appBarTheme.titleTextStyle)),
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
          const CacheStatusIndicator(),

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

          // ───── Progress indicator for data processing ─────
          Obx(() {
            if (ctrl.isProcessingData.value) {
              return Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: ctrl.dataProcessingProgress.value,
                      backgroundColor: surfaceVariantColor,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Processing data... ${(ctrl.dataProcessingProgress.value * 100).toInt()}%',
                      style: TextStyle(color: onSurfaceColor),
                    ),
                  ],
                ),
              );
            }
            return SizedBox.shrink();
          }),

          // ───── list / loading / empty / pull‑to‑refresh ─────
          Expanded(
            child: Obx(() {
              // 1️⃣ full‑screen loader only on FIRST load
              if (ctrl.isLoading.value && ctrl.debtors.isEmpty) {
                return Center(child: DotsWaveLoadingText(color: onSurfaceColor)); // Use theme-aware color
              }

              // 2️⃣ show error, but leave search & chips in place
              if (ctrl.error.value != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '❌  ${ctrl.error.value!}',
                        style: TextStyle(color: errorColor), // Use theme error color
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ctrl.loadData(),
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              // 3️⃣ apply filters with improved performance
              final filteredDebtors = _getFilteredDebtors();

              // 4️⃣ empty‑state placeholder
              if (filteredDebtors.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: onSurfaceColor.withOpacity(0.5)),
                      SizedBox(height: 16),
                      Text('No debtors found.', style: TextStyle(color: onSurfaceColor)), // Use theme-aware color
                      if (searchQ.value.isNotEmpty || filterType.value != 'All') ...[
                        SizedBox(height: 8),
                        Text('Try adjusting your filters.', style: TextStyle(color: onSurfaceColor.withOpacity(0.7))),
                      ]
                    ],
                  ),
                );
              }

              // 5️⃣ optimized list with pull‑to‑refresh and pagination
              return RefreshIndicator(
                onRefresh: () => ctrl.refreshDebtors(),   // ← single call
                color: primaryColor, // Use theme primary color for refresh indicator
                child: ListView.builder(
                  controller: listCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filteredDebtors.length + (ctrl.hasMoreDebtors.value ? 1 : 0),
                  itemBuilder: (_, i) {
                    // Show loading indicator at the bottom
                    if (i == filteredDebtors.length) {
                      return Obx(() => Container(
                        padding: EdgeInsets.all(16),
                        child: isLoadingMore.value
                            ? Center(
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          ),
                        )
                            : SizedBox.shrink(),
                      ));
                    }

                    return _debtorTile(filteredDebtors[i], context); // Pass context
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Optimized filtering with memoization
  List<Map<String, dynamic>> _getFilteredDebtors() {
    return ctrl.debtors.where((d) {
      // Filter by search query
      if (searchQ.value.isNotEmpty) {
        final name = d['name']?.toString().toLowerCase() ?? '';
        if (!name.contains(searchQ.value.toLowerCase())) {
          return false;
        }
      }

      // Filter by type
      if (filterType.value != 'All') {
        final type = d['type']?.toString().toLowerCase() ?? '';
        if (type != filterType.value.toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();
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

  // Optimized debtor tile with better performance
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
    final displayBal = bal.toStringAsFixed(2);
    final balanceType = bal >= 0 ? 'Dr' : 'Cr'; // Assuming positive balance is Debit, negative is Credit
    // For debtors, if bal > 0, they owe us (good - primaryColor), if bal <= 0, we owe them (bad - errorColor)
    final balanceColor = bal >= 0 ? primaryColor : errorColor;


    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: shadowColor.withOpacity(0.12),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Add tap functionality if needed
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
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
      ),
    );
  }
}