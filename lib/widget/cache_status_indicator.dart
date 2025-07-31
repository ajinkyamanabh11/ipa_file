import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../services/CsvDataServices.dart';

class CacheStatusIndicator extends StatelessWidget {
  final bool showTimestamp;
  final double? width;
  final EdgeInsetsGeometry? margin;

  const CacheStatusIndicator({
    super.key,
    this.showTimestamp = true,
    this.width,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final csvService = Get.find<CsvDataService>();
    final theme = Theme.of(context);

    return Obx(() {
      final dataSource = csvService.lastDataSource.value;
      final lastCacheTime = csvService.lastCacheTime.value;
      final isFromCache = csvService.isDataFromCache.value;

      if (dataSource == 'Unknown') {
        return const SizedBox.shrink();
      }

      final Color indicatorColor;
      final IconData indicatorIcon;
      final String statusText;

      if (isFromCache) {
        indicatorColor = theme.colorScheme.secondary;
        indicatorIcon = Icons.cached;
        statusText = 'Cached Data';
      } else {
        indicatorColor = theme.colorScheme.primary;
        indicatorIcon = Icons.cloud_download;
        statusText = 'Fresh Data';
      }

      return Container(
        width: width,
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: indicatorColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: indicatorColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              indicatorIcon,
              size: 14,
              color: indicatorColor,
            ),
            const SizedBox(width: 4),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: indicatorColor,
              ),
            ),
            if (showTimestamp && lastCacheTime != null) ...[
              const SizedBox(width: 4),
              Text(
                '•',
                style: TextStyle(
                  fontSize: 11,
                  color: indicatorColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('HH:mm').format(lastCacheTime),
                style: TextStyle(
                  fontSize: 10,
                  color: indicatorColor.withOpacity(0.8),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}