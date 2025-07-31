// // lib/Screens/lazy_sales_screen.dart
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
//
// import '../controllers/lazy_sales_controller.dart';
// import '../controllers/lazy_sales_controller.dart' ;
// import '../services/lazy_csv_service.dart';
// import '../widget/csv_loading_widget.dart';
// import '../widget/animated_Dots_LoadingText.dart';
//
// class LazySalesScreen extends StatefulWidget {
//   const LazySalesScreen({super.key});
//
//   @override
//   State<LazySalesScreen> createState() => _LazySalesScreenState();
// }
//
// class _LazySalesScreenState extends State<LazySalesScreen> with TickerProviderStateMixin {
//   late LazySalesController controller;
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//
//     // Get or create the controller
//     controller = Get.put(LazySalesController(), permanent: false);
//
//     // Animation setup
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 500),
//       vsync: this,
//     );
//
//     _fadeAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.easeIn,
//     ));
//
//     _animationController.forward();
//   }
//
//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final primaryColor = theme.primaryColor;
//     final onSurfaceColor = theme.colorScheme.onSurface;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Sales Report'),
//         backgroundColor: theme.appBarTheme.backgroundColor,
//         elevation: 0,
//         actions: [
//           // CSV loading indicator in app bar
//           Obx(() {
//             if (controller.isAnyFileLoading) {
//               return Padding(
//                 padding: const EdgeInsets.only(right: 16),
//                 child: CsvLoadingIndicator(
//                   csvTypes: const [CsvType.salesMaster, CsvType.salesDetails, CsvType.itemMaster],
//                   size: 24,
//                   color: theme.appBarTheme.foregroundColor,
//                 ),
//               );
//             }
//             return const SizedBox.shrink();
//           }),
//
//           // Refresh button
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: () => controller.refreshSalesData(),
//             tooltip: 'Refresh Data',
//           ),
//
//           // Clear cache button
//           PopupMenuButton<String>(
//             onSelected: (value) async {
//               switch (value) {
//                 case 'clear_cache':
//                   await controller.clearSalesCache();
//                   Get.snackbar(
//                     'Cache Cleared',
//                     'Sales data cache has been cleared',
//                     snackPosition: SnackPosition.BOTTOM,
//                   );
//                   break;
//                 case 'memory_info':
//                   _showMemoryInfo();
//                   break;
//               }
//             },
//             itemBuilder: (context) => [
//               const PopupMenuItem(
//                 value: 'clear_cache',
//                 child: ListTile(
//                   leading: Icon(Icons.clear_all),
//                   title: Text('Clear Cache'),
//                   contentPadding: EdgeInsets.zero,
//                 ),
//               ),
//               const PopupMenuItem(
//                 value: 'memory_info',
//                 child: ListTile(
//                   leading: Icon(Icons.info_outline),
//                   title: Text('Memory Info'),
//                   contentPadding: EdgeInsets.zero,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//       body: FadeTransition(
//         opacity: _fadeAnimation,
//         child: Obx(() => _buildBody(theme, primaryColor, onSurfaceColor)),
//       ),
//     );
//   }
//
//   Widget _buildBody(ThemeData theme, Color primaryColor, Color onSurfaceColor) {
//     // Show initial state with load button
//     if (controller.sales.isEmpty && !controller.isLoadingCsvData.value && controller.error.value == null) {
//       return _buildInitialState(theme, primaryColor);
//     }
//
//     // Show CSV loading state
//     if (controller.isLoadingCsvData.value) {
//       return _buildLoadingState(theme, primaryColor);
//     }
//
//     // Show error state
//     if (controller.error.value != null) {
//       return _buildErrorState(theme, primaryColor);
//     }
//
//     // Show sales data
//     return _buildSalesData(theme, onSurfaceColor);
//   }
//
//   Widget _buildInitialState(ThemeData theme, Color primaryColor) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.point_of_sale_rounded,
//               size: 80,
//               color: primaryColor.withOpacity(0.5),
//             ),
//             const SizedBox(height: 24),
//             Text(
//               'Sales Data',
//               style: theme.textTheme.headlineSmall?.copyWith(
//                 fontWeight: FontWeight.bold,
//                 color: primaryColor,
//               ),
//             ),
//             const SizedBox(height: 12),
//             Text(
//               'Load sales data from CSV files on-demand.\nData will be cached for faster subsequent access.',
//               textAlign: TextAlign.center,
//               style: theme.textTheme.bodyMedium?.copyWith(
//                 color: theme.colorScheme.onSurface.withOpacity(0.7),
//               ),
//             ),
//             const SizedBox(height: 32),
//             ElevatedButton.icon(
//               onPressed: () => controller.loadSalesData(),
//               icon: const Icon(Icons.download_rounded),
//               label: const Text('Load Sales Data'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: primaryColor,
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//             TextButton(
//               onPressed: () => controller.loadSalesData(forceRefresh: true),
//               child: const Text('Force Refresh'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLoadingState(ThemeData theme, Color primaryColor) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24.0),
//         child: CsvLoadingWidget(
//           csvTypes: const [CsvType.salesMaster, CsvType.salesDetails, CsvType.itemMaster],
//           title: 'Loading Sales Data',
//           primaryColor: primaryColor,
//           size: 250,
//           onCancel: () {
//             // Note: In a real implementation, you might want to add cancellation support
//             Get.snackbar(
//               'Info',
//               'Loading cannot be cancelled once started',
//               snackPosition: SnackPosition.BOTTOM,
//             );
//           },
//         ),
//       ),
//     );
//   }
//
//   Widget _buildErrorState(ThemeData theme, Color primaryColor) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(24.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.error_outline,
//               size: 80,
//               color: Colors.red.withOpacity(0.7),
//             ),
//             const SizedBox(height: 24),
//             Text(
//               'Error Loading Data',
//               style: theme.textTheme.headlineSmall?.copyWith(
//                 fontWeight: FontWeight.bold,
//                 color: Colors.red,
//               ),
//             ),
//             const SizedBox(height: 12),
//             Text(
//               controller.error.value!,
//               textAlign: TextAlign.center,
//               style: theme.textTheme.bodyMedium?.copyWith(
//                 color: theme.colorScheme.onSurface.withOpacity(0.7),
//               ),
//             ),
//             const SizedBox(height: 32),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: () => controller.loadSalesData(),
//                   icon: const Icon(Icons.downloading),
//                   label: const Text('Retry'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: primaryColor,
//                     foregroundColor: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 TextButton(
//                   onPressed: () => controller.loadSalesData(forceRefresh: true),
//                   child: const Text('Force Refresh'),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSalesData(ThemeData theme, Color onSurfaceColor) {
//     return RefreshIndicator(
//       onRefresh: () => controller.refreshSalesData(),
//       child: CustomScrollView(
//         slivers: [
//           // Stats header
//           SliverToBoxAdapter(
//             child: Container(
//               margin: const EdgeInsets.all(16),
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: theme.cardColor,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   _buildStatItem(
//                     'Total Sales',
//                     controller.sales.length.toString(),
//                     Icons.receipt_long,
//                     theme,
//                   ),
//                   _buildStatItem(
//                     'Total Amount',
//                     '₹${_getTotalAmount().toStringAsFixed(2)}',
//                     Icons.currency_rupee,
//                     theme,
//                   ),
//                   _buildStatItem(
//                     'Avg. Amount',
//                     '₹${_getAverageAmount().toStringAsFixed(2)}',
//                     Icons.trending_up,
//                     theme,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//
//           // Sales list
//           SliverList(
//             delegate: SliverChildBuilderDelegate(
//                   (context, index) {
//                 final sale = controller.sales[index];
//                 return Card(
//                   margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//                   child: ListTile(
//                     leading: CircleAvatar(
//                       backgroundColor: theme.primaryColor.withOpacity(0.1),
//                       child: Icon(
//                         Icons.receipt,
//                         color: theme.primaryColor,
//                         size: 20,
//                       ),
//                     ),
//                     title: Text(
//                       sale.partyName.isNotEmpty ? sale.partyName : 'Unknown Party',
//                       style: const TextStyle(fontWeight: FontWeight.w600),
//                     ),
//                     subtitle: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text('Bill No: ${sale.billNo}'),
//                         Text('Date: ${sale.entryDate}'),
//                         if (sale.items.isNotEmpty)
//                           Text(
//                             '${sale.items.length} item${sale.items.length != 1 ? 's' : ''}',
//                             style: TextStyle(
//                               color: theme.primaryColor,
//                               fontSize: 12,
//                             ),
//                           ),
//                       ],
//                     ),
//                     trailing: Text(
//                       '₹${sale.totalAmount.toStringAsFixed(2)}',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: theme.primaryColor,
//                         fontSize: 16,
//                       ),
//                     ),
//                     onTap: () => _showSaleDetails(sale, theme),
//                   ),
//                 );
//               },
//               childCount: controller.sales.length,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildStatItem(String title, String value, IconData icon, ThemeData theme) {
//     return Column(
//       children: [
//         Icon(icon, color: theme.primaryColor, size: 24),
//         const SizedBox(height: 8),
//         Text(
//           value,
//           style: theme.textTheme.titleMedium?.copyWith(
//             fontWeight: FontWeight.bold,
//             color: theme.primaryColor,
//           ),
//         ),
//         Text(
//           title,
//           style: theme.textTheme.bodySmall?.copyWith(
//             color: theme.colorScheme.onSurface.withOpacity(0.7),
//           ),
//         ),
//       ],
//     );
//   }
//
//   double _getTotalAmount() {
//     return controller.sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
//   }
//
//   double _getAverageAmount() {
//     if (controller.sales.isEmpty) return 0.0;
//     return _getTotalAmount() / controller.sales.length;
//   }
//
//   void _showSaleDetails(SalesEntry sale, ThemeData theme) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => DraggableScrollableSheet(
//         initialChildSize: 0.7,
//         maxChildSize: 0.9,
//         minChildSize: 0.5,
//         builder: (context, scrollController) => Container(
//           decoration: BoxDecoration(
//             color: theme.scaffoldBackgroundColor,
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
//           ),
//           child: Column(
//             children: [
//               // Handle
//               Container(
//                 margin: const EdgeInsets.symmetric(vertical: 8),
//                 width: 40,
//                 height: 4,
//                 decoration: BoxDecoration(
//                   color: Colors.grey,
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//
//               // Header
//               Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         'Sale Details',
//                         style: theme.textTheme.titleLarge?.copyWith(
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                     IconButton(
//                       onPressed: () => Navigator.pop(context),
//                       icon: const Icon(Icons.close),
//                     ),
//                   ],
//                 ),
//               ),
//
//               // Sale info
//               Container(
//                 margin: const EdgeInsets.symmetric(horizontal: 16),
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: theme.cardColor,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildDetailRow('Bill No', sale.billNo, theme),
//                     _buildDetailRow('Party', sale.partyName, theme),
//                     _buildDetailRow('Date', sale.entryDate, theme),
//                     _buildDetailRow('Total Amount', '₹${sale.totalAmount.toStringAsFixed(2)}', theme),
//                   ],
//                 ),
//               ),
//
//               // Items list
//               if (sale.items.isNotEmpty) ...[
//                 Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Align(
//                     alignment: Alignment.centerLeft,
//                     child: Text(
//                       'Items (${sale.items.length})',
//                       style: theme.textTheme.titleMedium?.copyWith(
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//                 Expanded(
//                   child: ListView.builder(
//                     controller: scrollController,
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     itemCount: sale.items.length,
//                     itemBuilder: (context, index) {
//                       final item = sale.items[index];
//                       return Card(
//                         margin: const EdgeInsets.only(bottom: 8),
//                         child: Padding(
//                           padding: const EdgeInsets.all(12),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 item.itemName,
//                                 style: const TextStyle(fontWeight: FontWeight.w600),
//                               ),
//                               const SizedBox(height: 4),
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   Text('Qty: ${item.quantity}'),
//                                   Text('Rate: ₹${item.rate.toStringAsFixed(2)}'),
//                                   Text(
//                                     'Amount: ₹${item.amount.toStringAsFixed(2)}',
//                                     style: TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       color: theme.primaryColor,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               if (item.batchNo.isNotEmpty)
//                                 Text(
//                                   'Batch: ${item.batchNo}',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: theme.colorScheme.onSurface.withOpacity(0.7),
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//               ] else
//                 Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Text(
//                     'No item details available',
//                     style: TextStyle(
//                       color: theme.colorScheme.onSurface.withOpacity(0.7),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDetailRow(String label, String value, ThemeData theme) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 80,
//             child: Text(
//               '$label:',
//               style: TextStyle(
//                 fontWeight: FontWeight.w500,
//                 color: theme.colorScheme.onSurface.withOpacity(0.7),
//               ),
//             ),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: const TextStyle(fontWeight: FontWeight.w600),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showMemoryInfo() {
//     final memoryInfo = controller.getMemoryInfo();
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Memory Information'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text('Sales Entries: ${memoryInfo['salesEntries']}'),
//               Text('CSV Memory Usage: ${memoryInfo['csvMemoryUsage']}'),
//               Text('Memory Warning: ${memoryInfo['isMemoryWarning']}'),
//               const SizedBox(height: 16),
//               const Text('Cache Info:', style: TextStyle(fontWeight: FontWeight.bold)),
//               const SizedBox(height: 8),
//               ...memoryInfo['cacheInfo'].entries.map<Widget>((entry) {
//                 final fileInfo = entry.value as Map<String, dynamic>;
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 2),
//                   child: Text(
//                     '${entry.key}: ${fileInfo['cached'] ? 'Cached' : 'Not cached'} '
//                         '${fileInfo['valid'] ? '(Valid)' : '(Expired)'} '
//                         '${fileInfo['inMemory'] ? '(In memory)' : ''}',
//                     style: const TextStyle(fontSize: 12),
//                   ),
//                 );
//               }).toList(),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // Re-export the data models for convenience
// // typedef SalesEntry = LazySalesController.SalesEntry;
// // typedef SalesItemDetail = LazySalesController.SalesItemDetail;