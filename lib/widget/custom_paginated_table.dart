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
        // Table
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
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(surfaceVariantColor),
                          columnSpacing: 24,
                          columns: columnHeaders.map((header) {
                            return DataColumn(
                              label: Text(
                                header,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
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
                                  ),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ),
        
        // Pagination Controls
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
              // Items per page selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    paginationInfo,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Row(
                    children: [
                      Text(
                        'Items per page: ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      DropdownButton<int>(
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
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Navigation controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // First page button
                  IconButton(
                    onPressed: currentPage > 0 ? () => onGoToPage(0) : null,
                    icon: const Icon(Icons.first_page),
                    tooltip: 'First page',
                  ),
                  
                  // Previous page button
                  IconButton(
                    onPressed: hasPreviousPage ? onPreviousPage : null,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous page',
                  ),
                  
                  // Page numbers
                  ..._buildPageNumbers(context, primaryColor),
                  
                  // Next page button
                  IconButton(
                    onPressed: hasNextPage ? onNextPage : null,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next page',
                  ),
                  
                  // Last page button
                  IconButton(
                    onPressed: currentPage < totalPages - 1 
                        ? () => onGoToPage(totalPages - 1) 
                        : null,
                    icon: const Icon(Icons.last_page),
                    tooltip: 'Last page',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPageNumbers(BuildContext context, Color primaryColor) {
    List<Widget> pageNumbers = [];
    
    // Calculate which page numbers to show
    int startPage = 0;
    int endPage = totalPages - 1;
    
    // Show max 5 page numbers at a time
    if (totalPages > 5) {
      if (currentPage <= 2) {
        startPage = 0;
        endPage = 4;
      } else if (currentPage >= totalPages - 3) {
        startPage = totalPages - 5;
        endPage = totalPages - 1;
      } else {
        startPage = currentPage - 2;
        endPage = currentPage + 2;
      }
    }
    
    // Add ellipsis at the beginning if needed
    if (startPage > 0) {
      pageNumbers.add(
        TextButton(
          onPressed: () => onGoToPage(0),
          child: const Text('1'),
        ),
      );
      if (startPage > 1) {
        pageNumbers.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...'),
          ),
        );
      }
    }
    
    // Add page number buttons
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
                  child: Text('${i + 1}'),
                ),
        ),
      );
    }
    
    // Add ellipsis at the end if needed
    if (endPage < totalPages - 1) {
      if (endPage < totalPages - 2) {
        pageNumbers.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...'),
          ),
        );
      }
      pageNumbers.add(
        TextButton(
          onPressed: () => onGoToPage(totalPages - 1),
          child: Text('$totalPages'),
        ),
      );
    }
    
    return pageNumbers;
  }
}