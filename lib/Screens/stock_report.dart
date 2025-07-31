import 'package:flutter/material.dart';

import 'package:get/get.dart';
import '../widget/cache_status_indicator.dart';

import 'package:intl/intl.dart';

import '../controllers/stock_report_controller.dart';

import '../widget/custome_paginated_table.dart';

import '../widget/rounded_search_field.dart';

import '../widget/animated_Dots_LoadingText.dart';

import '../widget/custom_app_bar.dart';

import 'dart:developer'; // Import for the log function

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final StockReportController stockReportController = Get.put(
    StockReportController(),
  );

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    searchController.addListener(() {
      stockReportController.searchQuery.value = searchController.text;
    });

    // Load data initially

    stockReportController.loadStockReport();
  }

  @override
  void dispose() {
    searchController.dispose();

    Get.delete<StockReportController>();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('Stock Report'),
        actions: [
          Obx(() => IconButton(
            icon: Icon(
              Icons.refresh,
              color: stockReportController.isLoading.value ? onSurfaceColor.withOpacity(0.5) : Colors.white,
            ),
            tooltip: 'Refresh Data',
            onPressed: stockReportController.isLoading.value ? null : () {
              stockReportController.loadStockReport(forceRefresh: true);
            },
          )),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

            child: _buildSearchField(),
          ),

          // New: Sort options
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 4.0,
            ),

            child: _buildSortOptions(context),
          ),
          const CacheStatusIndicator(),
          const SizedBox(height: 10),

          Expanded(
            // Expanded takes the remaining vertical space
            child: Obx(() {
              if (stockReportController.isLoading.value) {
                return Center(
                  child: DotsWaveLoadingText(color: onSurfaceColor),
                );
              }

              if (stockReportController.errorMessage.value != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),

                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 40,
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'Error: ${stockReportController.errorMessage.value}',

                          textAlign: TextAlign.center,

                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 20),

                        ElevatedButton(
                          onPressed: () => stockReportController
                              .loadStockReport(forceRefresh: false),

                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (stockReportController.totalItems.value == 0) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 50,
                        color: Colors.grey,
                      ),

                      SizedBox(height: 10),

                      Text(
                        'No items with stock found or matching search.',
                        style: TextStyle(color: Colors.grey),
                      ),

                      Text(
                        'Ensure ItemDetail.csv has data and "Currentstock" > 0.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () =>
                    stockReportController.loadStockReport(forceRefresh: true),

                child: Padding(
                  padding: const EdgeInsets.all(8.0),

                  child: CustomPaginatedTable(
                    data: stockReportController.currentPageData,

                    columnHeaders: const [
                      'Sr.',

                      'Item Code',

                      'Item Name',

                      'Batch No',

                      'Package',

                      'Current Stock',

                      'Type',
                    ],

                    columnKeys: const [
                      'Sr.No.',

                      'Item Code',

                      'Item Name',

                      'Batch No',

                      'Package',

                      'Current Stock',

                      'Type',
                    ],

                    currentPage: stockReportController.currentPage.value,

                    totalPages: stockReportController.totalPages.value,

                    totalItems: stockReportController.totalItems.value,

                    itemsPerPage: stockReportController.itemsPerPage.value,

                    availableItemsPerPage:
                        stockReportController.availableItemsPerPage,

                    paginationInfo: stockReportController.getPaginationInfo(),

                    hasNextPage: stockReportController.hasNextPage,

                    hasPreviousPage: stockReportController.hasPreviousPage,

                    isLoading: stockReportController.isLoadingPage.value,

                    onNextPage: stockReportController.nextPage,

                    onPreviousPage: stockReportController.previousPage,

                    onGoToPage: stockReportController.goToPage,

                    onItemsPerPageChanged:
                        stockReportController.setItemsPerPage,
                  ),
                ),
              );
            }),
          ),

          // New: Total Stock display at the bottom
          Obx(
            () => Visibility(
              visible:
                  !stockReportController.isLoading.value &&
                  stockReportController.errorMessage.value == null &&
                  stockReportController.totalItems.value > 0,

              child: _buildTotalStockCard(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return RoundedSearchField(
      controller: searchController,

      text: "Search By Item Code or Item Name...",

      onClear: () {
        searchController.clear();

        stockReportController.searchQuery.value = '';
      },

      onChanged: (value) {
        // searchController listener already updates stockReportController.searchQuery
      },
    );
  }

  // New: Widget to build sort options

  Widget _buildSortOptions(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    final Color surfaceVariantColor = Theme.of(
      context,
    ).colorScheme.surfaceVariant;

    return Obx(
      () => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,

        children: [
          // Sort by Item Name
          ChoiceChip(
            label: Text('Item Name'),

            selected: stockReportController.sortByColumn.value == 'Item Name',

            onSelected: (selected) {
              if (selected) {
                stockReportController.setSortColumn('Item Name');
              } else {
                // Optionally, handle deselection if you want a 'no sort' state

                // For simplicity, we'll just toggle if already selected

                stockReportController.toggleSortOrder();
              }
            },

            selectedColor: primaryColor,

            labelStyle: TextStyle(
              color: stockReportController.sortByColumn.value == 'Item Name'
                  ? Theme.of(context).colorScheme.onPrimary
                  : onSurfaceColor,
            ),

            backgroundColor: surfaceVariantColor,
          ),

          const SizedBox(width: 8),

          // Sort by Current Stock
          ChoiceChip(
            label: Text('Current Stock'),

            selected:
                stockReportController.sortByColumn.value == 'Current Stock',

            onSelected: (selected) {
              if (selected) {
                stockReportController.setSortColumn('Current Stock');
              } else {
                stockReportController.toggleSortOrder();
              }
            },

            selectedColor: primaryColor,

            labelStyle: TextStyle(
              color: stockReportController.sortByColumn.value == 'Current Stock'
                  ? Theme.of(context).colorScheme.onPrimary
                  : onSurfaceColor,
            ),

            backgroundColor: surfaceVariantColor,
          ),

          const SizedBox(width: 8),

          // Toggle sort order (Asc/Desc)
          IconButton(
            icon: Icon(
              stockReportController.sortAscending.value
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,

              color: primaryColor, // Highlight sort direction
            ),

            tooltip: stockReportController.sortAscending.value
                ? 'Sort Ascending'
                : 'Sort Descending',

            onPressed: () {
              stockReportController.toggleSortOrder();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTotalStockCard(BuildContext context) {
    final NumberFormat formatter = NumberFormat('#,##0.##');

    final Color primaryColor = Theme.of(context).primaryColor;

    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      decoration: BoxDecoration(
        color: primaryColor, // Use primary color for the background

        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),

          topRight: Radius.circular(12),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),

            blurRadius: 5,

            offset: const Offset(0, -3), // Shadow above
          ),
        ],
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          Text(
            'Total Current Stock:',

            style: TextStyle(
              fontSize: 18,

              fontWeight: FontWeight.bold,

              color: onPrimaryColor, // Text color on primary background
            ),
          ),

          Text(
            formatter.format(stockReportController.totalCurrentStock.value),

            style: TextStyle(
              fontSize: 20,

              fontWeight: FontWeight.bold,

              color: onPrimaryColor, // Text color on primary background
            ),
          ),
        ],
      ),
    );
  }
}
