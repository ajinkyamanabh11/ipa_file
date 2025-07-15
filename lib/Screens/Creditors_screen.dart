// lib/screens/creditors_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/customerLedger_Controller.dart';
import '../widget/custom_app_bar.dart';

class CreditorsScreen extends StatefulWidget {
  const CreditorsScreen({super.key});

  @override
  State<CreditorsScreen> createState() => _CreditorsScreenState();
}

class _CreditorsScreenState extends State<CreditorsScreen> {
  final ctrl       = Get.find<CustomerLedgerController>();

  final searchCtrl = TextEditingController();
  final RxString searchQ    = ''.obs;
  final RxString filterType = 'All'.obs;   // All / Customer / Supplier

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: const Text('Creditors')),
      body: Obx(() {
        if (ctrl.isLoading.value)   {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.error.value != null) {
          return Center(
            child: Text('❌  ${ctrl.error.value!}',
                style: const TextStyle(color: Colors.red)),
          );
        }

        // ---------- build working list ----------
        final creditors = [...ctrl.creditors]
          ..retainWhere((d) =>
              d['name'].toString().toLowerCase().contains(searchQ.value.toLowerCase()))
          ..retainWhere((d) {
            if (filterType.value == 'All') return true;
            return d['type'].toString().toLowerCase() ==
                filterType.value.toLowerCase();
          })
          ..sort((a, b) => a['name']
              .toString()
              .toLowerCase()
              .compareTo(b['name'].toString().toLowerCase()));

        if (creditors.isEmpty) {
          return const Center(child: Text('No creditors found.'));
        }

        // ---------- UI ----------
        return Column(
          children: [
            // search
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
            // chips
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

            Expanded(
              child: ListView.builder(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: creditors.length,
                itemBuilder: (_, i) {
                  final d    = creditors[i];
                  final bal  = (d['closingBalance'] as double?) ?? 0.0;
                  final open = (d['openingBalance'] as double?)
                      ?.toStringAsFixed(2) ??
                      '-';

                  return _creditorTile(
                    index: i,
                    name:  d['name'],
                    balance: bal,
                    type:  d['type'],
                    mobile:d['mobile'],
                    area:  d['area'],
                    openBal: open,
                    accNo: d['accountNumber'],
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  // ---------- reusable pieces ----------
  ChoiceChip _chip(String label) => ChoiceChip(
    label: Text(label),
    selected: filterType.value == label,
    selectedColor: Colors.green.shade300,
    onSelected: (_) => filterType.value = label,
  );

  Widget _creditorTile({
    required int    index,
    required String name,
    required double balance,
    required String type,
    required String mobile,
    required String area,
    required String openBal,
    required int    accNo,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                backgroundColor: Colors.green.shade100,
                                padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                                label: Text(
                                  '₹${balance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _infoPair(
                              'Type:', type, 'Dr/Cr:', 'Cr'), // always Cr
                          _infoPair('Opening Bal:', '₹$openBal',
                              'Mobile:', mobile),
                          _infoPair('Area:', area, 'Account #:', accNo),
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

  Widget _infoPair(String l1, dynamic v1, String l2, dynamic v2) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ 1st column
        Expanded(
          child: _badge(l1, v1),
        ),

        const SizedBox(width: 12),

        // ✅ 2nd column, right‑aligned
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _badge(l2, v2, TextAlign.right),
          ),
        ),
      ],
    ),
  );


  Widget _badge(String lbl, dynamic val, [TextAlign align = TextAlign.left]) =>
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
                text: '$lbl ',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.black)),
            TextSpan(text: val?.toString() ?? '-'),
          ],
        ),
        textAlign: align,
        style: const TextStyle(fontSize: 13),
      );
}
