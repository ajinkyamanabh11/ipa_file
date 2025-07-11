import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/item_type_controller.dart';
import '../../main.dart';                   // routeObserver
import '../../routes/routes.dart';
import '../../widget/custom_app_bar.dart';
import '../../widget/rounded_search_field.dart';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> with RouteAware {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final controller = Get.find<ItemTypeController>();

  List<Map<String, dynamic>> filteredItems = [];
  late final String itemType;
  bool _showFab = false;

  // ─────────────────────── lifecycle ────────────────────────────
  @override
  void initState() {
    super.initState();
    itemType = Get.arguments;
    _applyInitialFilter();

    _scroll.addListener(() {
      if (_scroll.offset > 300 && !_showFab) {
        setState(() => _showFab = true);
      } else if (_scroll.offset <= 300 && _showFab) {
        setState(() => _showFab = false);
      }
    });

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    _searchController.clear();
    _focusNode.unfocus();
    _onSearchChanged();
  }

  @override
  void dispose() {
    _scroll.dispose();          // ← prevent memory leak
    _searchController.dispose();
    _focusNode.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // ─────────────────────── helpers ──────────────────────────────
  void _applyInitialFilter() {
    filteredItems =
        controller.allItems.where((e) => e['ItemType'] == itemType).toList();
  }

  void _onSearchChanged() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      filteredItems = controller.allItems
          .where((e) =>
      e['ItemType'] == itemType &&
          (e['ItemName'] ?? '').toString().toLowerCase().contains(q))
          .toList();
    });
  }

  Future<void> _handleRefresh() async {
    await controller.fetchItemTypes();
    _applyInitialFilter();
    _onSearchChanged();
  }

  String _formatDateShort(dynamic v) {
    if (v == null || v.toString().isEmpty) return '-';
    try {
      final d = DateTime.parse(v.toString().split(' ').first);
      const mon = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${d.day.toString().padLeft(2, '0')}/${mon[d.month]}/${d.year}';
    } catch (_) {
      return v.toString();
    }
  }

  // ─────────────────────── ui ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text('🛒 $itemType Items')),
      floatingActionButton: _showFab
          ? FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () => _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        ),
        child: const Icon(Icons.arrow_upward, color: Colors.white),
      )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: RoundedSearchField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: (_) => _onSearchChanged(),
              onClear: () {
                _searchController.clear();
                _onSearchChanged();
                _focusNode.unfocus();
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: Colors.green,
              onRefresh: _handleRefresh,
              child: ListView.builder(
                controller: _scroll,
                itemCount: filteredItems.length,
                itemBuilder: (_, index) {
                  final item = filteredItems[index];
                  final code = item['ItemCode'].toString();

                  return Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: InkWell(

                      borderRadius: BorderRadius.circular(16),
                      onTap: () {},
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 2,
                              offset: const Offset(0, 4),
                              color: Colors.black.withOpacity(.12),
                            ),
                          ],
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // green accent
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
                                  child: Obx(() {
                                    final d = controller.itemDetails[code];
                                    if (d == null) {
                                      return const Text('Detail loading…');
                                    }
                                    return Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['ItemName'] ?? 'Unnamed',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16),
                                                maxLines: 2,
                                                overflow:
                                                TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Chip(
                                              backgroundColor:
                                              Colors.green.shade100,
                                              padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 4),
                                              label: Text(
                                                'MRP ₹${d['MRP'] ?? '-'}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        _infoPair(
                                          leftLabel: 'Stock:',
                                          leftValue: d['Currentstock'],
                                          rightLabel: 'Batch No:',
                                          rightValue: d['BatchNo'],
                                        ),
                                        _infoPair(
                                          leftLabel: 'Cash Rate:',
                                          leftValue:
                                          '₹${d['CashTradindPrice']}',
                                          rightLabel: 'Expiry:',
                                          rightValue:
                                          _formatDateShort(d['ExpiryDate']),
                                        ),
                                        _infoPair(
                                          leftLabel: 'Credit Rate:',
                                          leftValue:
                                          '₹${d['CreditTradindPrice']}',
                                          rightLabel: 'Pur. Rate:',
                                          rightValue:
                                          '₹${d['PurchasePrice'] ?? '-'}',
                                        ),
                                        _infoPair(
                                          leftLabel: 'HSN:',
                                          leftValue: item['HSNCode'],
                                          rightLabel: 'Item Code:',
                                          rightValue: code,
                                        ),
                                      ],
                                    );
                                  }),
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
          ),
        ],
      ),
    );
  }

  // ─── small widgets ─────────────────────────────────────────────
  Widget _infoPair({
    required String leftLabel,
    required dynamic leftValue,
    required String rightLabel,
    required dynamic rightValue,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _rich(leftLabel, leftValue),
            _rich(rightLabel, rightValue),
          ],
        ),
      );

  Widget _rich(String label, dynamic value) => RichText(
    text: TextSpan(
      style: const TextStyle(color: Colors.black),
      children: [
        TextSpan(
          text: label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        TextSpan(text: ' ${value ?? '-'}'),
      ],
    ),
  );
}
