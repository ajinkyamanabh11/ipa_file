// lib/screens/debtors_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/customerLedger_Controller.dart';
import '../widget/animated_Dots_LoadingText.dart';
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

  @override
  void initState() {
    super.initState();
    listCtrl.addListener(() => showFab.value = listCtrl.offset > 300);
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
    return Scaffold(
      appBar: CustomAppBar(title: const Text('Debtors')),
      floatingActionButton: Obx(() => showFab.value
          ? FloatingActionButton(
        heroTag: 'toTopBtn',
        backgroundColor: Colors.green,
        onPressed: () => listCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        ),
        child: const Icon(Icons.arrow_upward, color: Colors.white),
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
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                suffixIcon: searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    searchCtrl.clear();
                    searchQ.value = '';
                  },
                ),
                filled: true,
                fillColor: Colors.green.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
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
                  _chip('All'),
                  _chip('Customer'),
                  _chip('Supplier'),
                ],
              ),
            ),
          ),

          // ───── list / loading / empty / pull‑to‑refresh ─────
          Expanded(
            child: Obx(() {
              // 1️⃣ full‑screen loader only on FIRST load
              if (ctrl.isLoading.value && ctrl.debtors.isEmpty) {
                return const Center(child: DotsWaveLoadingText());
              }

              // 2️⃣ show error, but leave search & chips in place
              if (ctrl.error.value != null) {
                return Center(
                  child: Text(
                    '❌  ${ctrl.error.value!}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              // 3️⃣ apply filters
              final debtors = [...ctrl.debtors]
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
              if (debtors.isEmpty) {
                return const Center(child: Text('No debtors found.'));
              }

              // 5️⃣ list with pull‑to‑refresh
              return RefreshIndicator(
                onRefresh: () => ctrl.refreshDebtors(),   // ← single call
                child: ListView.builder(
                  controller: listCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: debtors.length,
                  itemBuilder: (_, i) => _debtorTile(debtors[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ──────────────────── helpers ─────────────────────────────
  ChoiceChip _chip(String label) => ChoiceChip(
    label: Text(label),
    selected: filterType.value == label,
    selectedColor: Colors.green.shade300,
    onSelected: (_) => filterType.value = label,
  );

  Widget _badge(String label, dynamic value,
      {TextAlign align = TextAlign.left}) =>
      Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.black),
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

  // single card (Name • Area • Mobile • Balance)
  Widget _debtorTile(Map<String, dynamic> d) {
    final bal = (d['closingBalance'] as double?) ?? 0.0;
    final area = d['area'] ?? '-';
    final mobile = d['mobile'] ?? '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 2, offset: Offset(0, 4)),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // accent bar
                Container(
                  width: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.only(
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              backgroundColor: Colors.green.shade100,
                              padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                              label: Text(
                                '₹${bal.toStringAsFixed(2)} Dr',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.green),
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
