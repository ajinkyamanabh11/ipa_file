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
  final ctrl       = Get.find<CustomerLedgerController>();

  final searchCtrl = TextEditingController();
  final RxString searchQ     = ''.obs;          // text filter
  final RxString filterType  = 'All'.obs;       // All / Customer / Supplier

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: const Text('Debtors')),
      body: Obx(() {
        // ── 1. loading / error ──────────────────────────────────────────────
        if (ctrl.isLoading.value) {
          return const Center(child: DotsWaveLoadingText());
        }
        if (ctrl.error.value != null) {
          return Center(
            child: Text('❌  ${ctrl.error.value!}',
                style: const TextStyle(color: Colors.red)),
          );
        }

        // ── 2. build working list ───────────────────────────────────────────
        final debtors = [...ctrl.debtors]
        // filter by name
          ..retainWhere((d) => d['name']
              .toString()
              .toLowerCase()
              .contains(searchQ.value.toLowerCase()))
        // filter by type
          ..retainWhere((d) {
            if (filterType.value == 'All') return true;
            return d['type'].toString().toLowerCase() ==
                filterType.value.toLowerCase();
          })
        // sort by name
          ..sort((a, b) => a['name']
              .toString()
              .toLowerCase()
              .compareTo(b['name'].toString().toLowerCase()));

        if (debtors.isEmpty) {
          return const Center(child: Text('No debtors found.'));
        }

        // ── 3. UI ───────────────────────────────────────────────────────────
        return Column(
          children: [
            // search bar -----------------------------------------------------
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

            // filter chips ---------------------------------------------------
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Obx(() => Wrap(
                spacing: 8,
                children: [
                  _chip('All'),
                  _chip('Customer'),
                  _chip('Supplier'),
                ],
              )),
            ),

            // list -----------------------------------------------------------
            Expanded(
              child: ListView.builder(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: debtors.length,
                itemBuilder: (_, i) {
                  final d    = debtors[i];
                  final bal  = (d['closingBalance'] as double?) ?? 0.0;
                  final open = (d['openingBalance'] as double?)
                      ?.toStringAsFixed(2) ??
                      '-';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {},      // optional action
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 2,
                                offset: Offset(0, 4)),
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
                                  padding: const EdgeInsets.fromLTRB(
                                      12, 12, 16, 12),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(d['name'] ?? '',
                                                style: const TextStyle(
                                                    fontWeight:
                                                    FontWeight.w600,
                                                    fontSize: 16),
                                                maxLines: 2,
                                                overflow:
                                                TextOverflow.ellipsis),
                                          ),
                                          const SizedBox(width: 8),
                                          Chip(
                                            backgroundColor:
                                            Colors.green.shade100,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            label: Text(
                                              '₹${bal.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      _infoPair(
                                        leftLabel: 'Type:',
                                        leftValue: d['type'],
                                        rightLabel: 'Dr/Cr:',
                                        rightValue: d['drCr'],
                                      ),
                                      _infoPair(
                                        leftLabel: 'Opening Bal:',
                                        leftValue: '₹$open',
                                        rightLabel: 'Mobile:',
                                        rightValue: d['mobile'],
                                      ),
                                      _infoPair(
                                        leftLabel: 'Area:',
                                        leftValue: d['area'],
                                        rightLabel: 'Account #:',
                                        rightValue: d['accountNumber'],
                                      ),
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
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  // ---------- filter chip ----------
  Widget _chip(String label) => ChoiceChip(
    label: Text(label),
    selected: filterType.value == label,
    selectedColor: Colors.green.shade300,
    onSelected: (_) => filterType.value = label,
  );

  // ---------- badge helpers ----------
  Widget _badge(String label, dynamic value,
      {TextAlign align = TextAlign.left}) =>
      Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black),
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

  Widget _infoPair({
    required String leftLabel,
    required dynamic leftValue,
    required String rightLabel,
    required dynamic rightValue,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _badge(leftLabel, leftValue)),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _badge(rightLabel, rightValue,
                    align: TextAlign.right),
              ),
            ),
          ],
        ),
      );
}
