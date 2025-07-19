import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/item_type_controller.dart';
import '../../main.dart'; // Ensure this is correctly imported for routeObserver
import '../../widget/animated_Dots_LoadingText.dart';
import '../../widget/custom_app_bar.dart';
import '../../widget/refresh_indicator.dart'; // Assuming AppRefreshIndicator is here
import '../../widget/rounded_search_field.dart'; // Assuming RoundedSearchField is here

class ItemTypeScreen extends StatefulWidget {
  const ItemTypeScreen({super.key});

  @override
  State<ItemTypeScreen> createState() => _ItemTypeScreenState();
}

class _ItemTypeScreenState extends State<ItemTypeScreen> with RouteAware {
  final TextEditingController searchController = TextEditingController();
  final controller = Get.find<ItemTypeController>();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 💡 CRITICAL CHANGE: Start fetching item types immediately
    // This ensures isLoading is set to true before the first build cycle completes,
    // preventing the "No item types found." flicker.
    controller.fetchItemTypes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure ModalRoute.of(context) is not null before subscribing
    final ModalRoute<void>? route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    _focusNode.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // When navigating back to this screen from another,
    // clear search, reset the filter, and unfocus the search field.
    searchController.clear();
    controller.search(''); // Reset filtered list to all types
    _focusNode.unfocus();
    super.didPopNext();
  }

  @override
  Widget build(BuildContext context) {
    // Get relevant theme colors
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color cardColor = Theme.of(context).cardColor;
    final Color iconColor = Theme.of(context).iconTheme.color ?? onSurfaceColor; // Default icon color

    return Scaffold(
      appBar: const CustomAppBar(
          title: Text('🧾 Item Types'), showBackButton: true, centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: RoundedSearchField(
              text: 'Search by Item type...',
              controller: searchController,
              focusNode: _focusNode,
              onChanged: controller.search,
              onClear: () {
                searchController.clear();
                controller.search('');
                _focusNode.unfocus();
              },
            ),
          ),

          Expanded(
            child: Obx(() {
              // Show loading spinner if controller is currently loading
              if (controller.isLoading.value) {
                return Center(
                  child: DotsWaveLoadingText(color: onSurfaceColor),
                );
              }

              // Show error overlay if there's an error
              if (controller.error.value != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '❌ ${controller.error.value}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => controller.fetchItemTypes(silent: false),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              // Only show "No item types found." if not loading AND the filtered list is empty
              if (controller.filteredItemTypes.isEmpty) {
                return Center(
                  child: Text(
                    'No item types found.Or yet fetching data.. ',
                    style: TextStyle(color: onSurfaceColor),
                  ),
                );
              }

              // Main list with pull-to-refresh
              return AppRefreshIndicator(
                color: primaryColor,
                onRefresh: () => controller.fetchItemTypes(silent: true),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: controller.filteredItemTypes.length,
                  itemBuilder: (_, index) {
                    final type = controller.filteredItemTypes[index];
                    final count = controller.typeCounts[type] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Card(
                        color: cardColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: ListTile(
                          title: Text(
                            '$type ($count)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: iconColor,
                          ),
                          onTap: () {
                            searchController.clear();
                            _focusNode.unfocus();
                            controller.search('');
                            Get.toNamed('/itemlist', arguments: type);
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}