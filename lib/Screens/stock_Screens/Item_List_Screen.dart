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
    final ModalRoute<void>? route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
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
    // Get theme colors here once
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary;
    final Color cardBackgroundColor = Theme.of(context).cardColor;
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color iconColor = Theme.of(context).iconTheme.color ?? onSurfaceColor; // Default icon color
    final Color shadowColor = Theme.of(context).shadowColor;


    return Scaffold(
      appBar: CustomAppBar(title: Text('🛒 $itemType Items')),
      floatingActionButton: _showFab
          ? FloatingActionButton(
        // Use theme's primary color
        backgroundColor: primaryColor,
        onPressed: () => _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        ),
        // Use theme's onPrimary color for icon
        child: Icon(Icons.arrow_upward, color: onPrimaryColor),
      )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            // RoundedSearchField should be theme-aware internally
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
              // Use theme's primary color for refresh indicator
              color: primaryColor,
              onRefresh: _handleRefresh,
              child: filteredItems.isEmpty
                  ? Center(
                child: Text(
                  'No items found for $itemType.',
                  style: TextStyle(color: onSurfaceColor), // Theme-aware text color
                ),
              )
                  : ListView.builder(
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
                          // Use theme's card background color
                          color: cardBackgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 2,
                              offset: const Offset(0, 4),
                              // Use theme's shadow color (or onSurface with opacity)
                              color: shadowColor.withOpacity(.12),
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
                                decoration: BoxDecoration(
                                  // Use theme's primary color for accent
                                  color: primaryColor,
                                  borderRadius: const BorderRadius.only(
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
                                      // Text color adapts automatically if parent container is theme-aware
                                      return Text(
                                        'Detail loading…',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      );
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
                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            // Explicitly set color for this specific text
                                            color: onSurfaceColor.withOpacity(0.7),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                              // right arrow
                              Padding(
                                padding: const EdgeInsets.only(right :30),
                                child: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 18,
                                  color: iconColor, // Use theme's icon color
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