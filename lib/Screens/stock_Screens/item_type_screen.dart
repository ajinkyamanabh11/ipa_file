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
    searchController.clear();
    controller.search('');
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
      // CustomAppBar should be theme-aware internally; its title text will follow AppBarTheme from main.dart
      appBar: const CustomAppBar(
          title: Text('🧾 Item Types'), showBackButton: true, centerTitle: true),
      body: Column(
        children: [
          // 🔹 search bar is NOT rebuilt every time
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            // RoundedSearchField needs to be theme-aware internally for its colors
            child: RoundedSearchField(
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

          // 🔹 only this Expanded is reactive
          Expanded(
            child: Obx(() {
              // show a full‑screen spinner ONLY when we have nothing yet
              if (controller.isLoading.value &&
                  controller.allItemTypes.isEmpty) {
                return Center(
                  // Pass the theme-aware color to DotsWaveLoadingText
                  child: DotsWaveLoadingText(color: onSurfaceColor),
                );
              }

              // show error overlay but keep the rest intact
              if (controller.error.value != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '❌ ${controller.error.value}',
                        textAlign: TextAlign.center,
                        // Error text color (red is usually fine for errors in both themes)
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () =>
                            controller.fetchItemTypes(silent: false),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        // ElevatedButton colors will adapt based on theme
                      ),
                    ],
                  ),
                );
              }

              // main list with pull‑to‑refresh
              return AppRefreshIndicator(
                // Use theme's primary color for the refresh indicator
                color: primaryColor,
                onRefresh: () => controller.fetchItemTypes(silent: true),
                child: controller.filteredItemTypes.isEmpty
                    ? Center(
                  child: Text(
                    'No item types found.',
                    // Use theme's onSurface color for visibility
                    style: TextStyle(color: onSurfaceColor),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: controller.filteredItemTypes.length,
                  itemBuilder: (_, index) {
                    final type = controller.filteredItemTypes[index];
                    final count = controller.typeCounts[type] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Card(
                        // Use theme's card color
                        color: cardColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: ListTile(
                          // Text color will adapt automatically from theme.textTheme
                          title: Text(
                            '$type ($count)',
                            style: Theme.of(context).textTheme.titleMedium, // Or bodyLarge
                          ),
                          // Use theme's icon color for the trailing icon
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