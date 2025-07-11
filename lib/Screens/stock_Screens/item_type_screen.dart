import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/item_type_controller.dart';
import '../../main.dart';
import '../../widget/custom_app_bar.dart';
import '../../widget/refresh_indicator.dart';
import '../../widget/rounded_search_field.dart';

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
    routeObserver.subscribe(this, ModalRoute.of(context)!);
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
    return Scaffold(
      appBar: const CustomAppBar(
          title: Text('🧾 Item Types'), showBackButton: true, centerTitle: true),
      body: Column(
        children: [
          // 🔹 search bar is NOT rebuilt every time
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                return const Center(child: CircularProgressIndicator());
              }

              // show error overlay but keep the rest intact
              if (controller.error.value != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('❌ ${controller.error.value}',
                          textAlign: TextAlign.center,
                          style:
                          const TextStyle(color: Colors.red, fontSize: 16)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () =>
                            controller.fetchItemTypes(silent: false),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              // main list with pull‑to‑refresh
              return AppRefreshIndicator(
                color: Colors.green,
                onRefresh: () => controller.fetchItemTypes(silent: true),
                child: controller.filteredItemTypes.isEmpty
                    ? const Center(child: Text('No item types found.'))
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
                        color: Colors.green.shade50,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: ListTile(
                          title: Text('$type ($count)'),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 16),
                          onTap: () {
                            searchController.clear();
                            _focusNode.unfocus();
                            controller.search('');
                            Get.toNamed('/itemlist',
                                arguments: type);
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

