// ... [existing imports]
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/item_type_controller.dart';
import '../../main.dart'; // routeObserver
import '../../routes/routes.dart';
import '../../widget/custom_app_bar.dart';
import '../../widget/rounded_search_field.dart';
import 'item_batch_screen.dart';

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
    _scroll.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

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
                      onTap: () {
                        Get.to(() => ItemBatchScreen(
                          itemCode: code,
                          itemname: '${item['ItemName']}',
                        ));
                      },
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
                                  padding:
                                  const EdgeInsets.fromLTRB(12, 12, 4, 12),
                                  child: Obx(() {
                                    final d =
                                    controller.latestDetailByCode[code];
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
                                                  fontSize: 16,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Item Code: $code',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                              // right arrow
                              const Padding(
                                padding: EdgeInsets.only(right :30),
                                child: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 18,
                                  color: Colors.grey,
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
}
