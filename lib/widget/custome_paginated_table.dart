import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomPaginatedTable extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final List<String> columnHeaders;
  final List<String> columnKeys;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final List<int> availableItemsPerPage;
  final String paginationInfo;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final bool isLoading;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;
  final Function(int) onGoToPage;
  final Function(int) onItemsPerPageChanged;

  const CustomPaginatedTable({
    Key? key,
    required this.data,
    required this.columnHeaders,
    required this.columnKeys,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.availableItemsPerPage,
    required this.paginationInfo,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.isLoading,
    required this.onNextPage,
    required this.onPreviousPage,
    required this.onGoToPage,
    required this.onItemsPerPageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color surfaceColor = Theme.of(context).colorScheme.surface;
    final Color surfaceVariantColor = Theme.of(context).colorScheme.surfaceVariant;
    final Color primaryColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table Section
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : data.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey),
                SizedBox(height: 10),
                Text('No data available', style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
              :
          // The main change: Wrap DataTable in a vertical SingleChildScrollView
          SingleChildScrollView( // This enables vertical scrolling for the table body
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView( // This enables horizontal scrolling for the table body
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(surfaceVariantColor),
                columnSpacing: 24,
                columns: columnHeaders.map((header) {
                  return DataColumn(
                    label: Flexible(
                      child: Text(
                        header,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: onSurfaceColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }).toList(),
                rows: data.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;

                  return DataRow(
                    color: MaterialStateProperty.all(
                      index.isEven ? surfaceColor : surfaceVariantColor,
                    ),
                    cells: columnKeys.map((key) {
                      String value = '';
                      if (key == 'Current Stock') {
                        final stockValue = row[key] ?? 0;
                        final formatter = NumberFormat('#,##0.##');
                        value = formatter.format(stockValue);
                      } else {
                        value = row[key]?.toString() ?? '';
                      }

                      return DataCell(
                        Text(
                          value,
                          style: TextStyle(color: onSurfaceColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // Pagination Controls Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceVariantColor,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Column(
            children: [
              // Items per page selector (top row of pagination controls)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    flex: 2,
                    child: Text(
                      paginationInfo,
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    flex: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            'Items per page: ',
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: itemsPerPage,
                            items: availableItemsPerPage.map((value) {
                              return DropdownMenuItem<int>(
                                value: value,
                                child: Text(value.toString()),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                onItemsPerPageChanged(value);
                              }
                            },
                            dropdownColor: Theme.of(context).cardColor,
                            style: TextStyle(color: onSurfaceColor),
                            iconEnabledColor: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Navigation controls (bottom row of pagination controls)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: currentPage > 0 ? () => onGoToPage(0) : null,
                      icon: const Icon(Icons.first_page),
                      tooltip: 'First page',
                      color: primaryColor,
                      disabledColor: Colors.grey,
                    ),
                    IconButton(
                      onPressed: hasPreviousPage ? onPreviousPage : null,
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Previous page',
                      color: primaryColor,
                      disabledColor: Colors.grey,
                    ),
                    ..._buildPageNumbers(context, primaryColor),
                    IconButton(
                      onPressed: hasNextPage ? onNextPage : null,
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Next page',
                      color: primaryColor,
                      disabledColor: Colors.grey,
                    ),
                    IconButton(
                      onPressed: currentPage < totalPages - 1
                          ? () => onGoToPage(totalPages - 1)
                          : null,
                      icon: const Icon(Icons.last_page),
                      tooltip: 'Last page',
                      color: primaryColor,
                      disabledColor: Colors.grey,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPageNumbers(BuildContext context, Color primaryColor) {
    List<Widget> pageNumbers = [];
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    int startPage = 0;
    int endPage = totalPages - 1;

    const int maxVisiblePages = 5;

    if (totalPages > maxVisiblePages) {
      if (currentPage <= maxVisiblePages ~/ 2) {
        startPage = 0;
        endPage = maxVisiblePages - 1;
      } else if (currentPage >= totalPages - (maxVisiblePages ~/ 2) - 1) {
        startPage = totalPages - maxVisiblePages;
        endPage = totalPages - 1;
      } else {
        startPage = currentPage - (maxVisiblePages ~/ 2);
        endPage = currentPage + (maxVisiblePages ~/ 2);
      }
    }

    if (startPage > 0) {
      pageNumbers.add(
        TextButton(
          onPressed: () => onGoToPage(0),
          style: TextButton.styleFrom(
            minimumSize: const Size(36, 36),
            padding: EdgeInsets.zero,
            foregroundColor: onSurfaceColor,
          ),
          child: const Text('1'),
        ),
      );
      if (startPage > 1) {
        pageNumbers.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text('...'),
          ),
        );
      }
    }

    for (int i = startPage; i <= endPage; i++) {
      final isCurrentPage = i == currentPage;
      pageNumbers.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: isCurrentPage
              ? Container(
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextButton(
              onPressed: null,
              style: TextButton.styleFrom(
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
              : TextButton(
            onPressed: () => onGoToPage(i),
            style: TextButton.styleFrom(
              minimumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              foregroundColor: onSurfaceColor,
            ),
            child: Text('${i + 1}'),
          ),
        ),
      );
    }

    if (endPage < totalPages - 1) {
      if (endPage < totalPages - 2) {
        pageNumbers.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text('...'),
          ),
        );
      }
      pageNumbers.add(
        TextButton(
          onPressed: () => onGoToPage(totalPages - 1),
          style: TextButton.styleFrom(
            minimumSize: const Size(36, 36),
            padding: EdgeInsets.zero,
            foregroundColor: onSurfaceColor,
          ),
          child: Text('$totalPages'),
        ),
      );
    }

    return pageNumbers;
  }
}