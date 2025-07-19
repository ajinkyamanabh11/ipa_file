import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/item_type_controller.dart';
import '../../widget/custom_app_bar.dart';

class ItemBatchScreen extends StatelessWidget {
  final String itemname;
  final String itemCode;
  final ItemTypeController controller = Get.find();

  ItemBatchScreen({super.key, required this.itemCode, required this.itemname});

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

  // Expiry highlight color logic - These are semantic and should remain as is
  Color _getExpiryColor(String? expiryDate) {
    if (expiryDate == null || expiryDate.isEmpty) return Colors.green;
    try {
      final expiry = DateTime.parse(expiryDate.split(' ').first);
      final now = DateTime.now();

      if (expiry.isBefore(now)) {
        return Colors.red; // expired
      } else if (expiry.difference(now).inDays <= 30) {
        return Colors.orange; // expiring soon
      } else {
        return Colors.green; // good
      }
    } catch (_) {
      return Colors.green;
    }
  }

  Widget _infoPair({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
    required BuildContext context, // Pass context to access theme
  }) {
    // Get theme-aware text color
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                // Use theme-aware color for RichText default style
                style: TextStyle(color: onSurfaceColor, fontSize: 14), // Default size for info pair
                children: [
                  TextSpan(
                    text: leftLabel,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(text: ' $leftValue'),
                ],
              ),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                // Use theme-aware color for RichText default style
                style: TextStyle(color: onSurfaceColor, fontSize: 14),
                children: [
                  TextSpan(
                    text: rightLabel,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(text: ' $rightValue'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final RxString sortBy = 'BatchNo'.obs; // This is not used in the build method
    // Get theme colors here once
    final Color cardBackgroundColor = Theme.of(context).cardColor;
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color shadowColor = Theme.of(context).shadowColor;

    return Scaffold(
      appBar: CustomAppBar(
        title: Text('Batches for ItemCode $itemCode'),
      ),
      body: Obx(() {
        final batches = controller.itemDetailsByCode[itemCode] ?? [];

        if (batches.isEmpty) {
          return Center(
            child: Text(
              'No batches found.',
              style: TextStyle(color: onSurfaceColor), // Theme-aware text color
            ),
          );
        }

        return ListView.builder(
          itemCount: batches.length,
          itemBuilder: (_, index) {
            final d = batches[index];
            final expiryColor =
            _getExpiryColor(d['ExpiryDate']?.toString() ?? '');

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      // colored accent bar based on expiry
                      Container(
                        width: 8,
                        decoration: BoxDecoration(
                          color: expiryColor, // Semantic color, not theme-dependent
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                      ),
                      // content
                      Expanded(
                        child: Padding(
                          padding:
                          const EdgeInsets.fromLTRB(12, 12, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      itemname,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    // Use a theme-aware background color for the chip
                                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    label: Text(
                                      'MRP ₹${d['MRP']?.toString() ?? '-'}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        // Ensure text contrasts with chip background
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _infoPair(
                                leftLabel: 'Stock:',
                                leftValue:
                                d['Currentstock']?.toString() ?? '-',
                                rightLabel: 'Batch No:',
                                rightValue:
                                d['BatchNo']?.toString() ?? '-',
                                context: context, // Pass context
                              ),
                              _infoPair(
                                leftLabel: 'Cash Rate:',
                                leftValue:
                                '₹${d['CashTradindPrice']?.toString() ?? '-'}',
                                rightLabel: 'Expiry:',
                                rightValue: _formatDateShort(
                                    d['ExpiryDate']?.toString()),
                                context: context, // Pass context
                              ),
                              _infoPair(
                                leftLabel: 'Credit Rate:',
                                leftValue:
                                '₹${d['CreditTradindPrice']?.toString() ?? '-'}',
                                rightLabel: 'Pur. Rate:',
                                rightValue:
                                '₹${d['PurchasePrice']?.toString() ?? '-'}',
                                context: context, // Pass context
                              ),
                              _infoPair(
                                leftLabel: 'Pkg:',
                                leftValue:
                                d['txt_pkg']?.toString() ?? '-',
                                rightLabel: 'HSN:',
                                rightValue:
                                d['HSNCode']?.toString() ?? '-',
                                context: context, // Pass context
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}