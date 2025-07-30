// lib/widget/csv_loading_widget.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/lazy_csv_service.dart';
import 'animated_Dots_LoadingText.dart';

/// A custom loading widget for CSV data loading with progress indicators
class CsvLoadingWidget extends StatelessWidget {
  final List<CsvType> csvTypes;
  final String? title;
  final bool showProgress;
  final bool showFileNames;
  final VoidCallback? onCancel;
  final Color? primaryColor;
  final double? size;

  const CsvLoadingWidget({
    super.key,
    required this.csvTypes,
    this.title,
    this.showProgress = true,
    this.showFileNames = true,
    this.onCancel,
    this.primaryColor,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final lazyCsvService = Get.find<LazyCsvService>();
    final theme = Theme.of(context);
    final effectivePrimaryColor = primaryColor ?? theme.primaryColor;
    final effectiveSize = size ?? 200.0;

    return GetBuilder<LazyCsvService>(
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: effectivePrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],

            // Main loading indicator
            SizedBox(
              width: effectiveSize,
              height: effectiveSize * 0.6,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle
                  SizedBox(
                    width: effectiveSize * 0.4,
                    height: effectiveSize * 0.4,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      backgroundColor: effectivePrimaryColor.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(effectivePrimaryColor),
                      value: _getOverallProgress(lazyCsvService),
                    ),
                  ),
                  // Progress text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download_rounded,
                        size: 32,
                        color: effectivePrimaryColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_getOverallProgress(lazyCsvService) * 100).toInt()}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: effectivePrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Animated loading text
            DotsWaveLoadingText(color: effectivePrimaryColor),

            const SizedBox(height: 16),

            // Individual file progress
            if (showProgress && showFileNames) ...[
              _buildFileProgressList(lazyCsvService, theme, effectivePrimaryColor),
              const SizedBox(height: 16),
            ],

            // Memory usage indicator
            Obx(() {
              final memoryUsage = lazyCsvService.memoryUsageMB.value;
              final isWarning = lazyCsvService.isMemoryWarning.value;
              
              if (memoryUsage > 1.0) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isWarning ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isWarning ? Colors.orange : Colors.green,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isWarning ? Icons.warning_amber_rounded : Icons.memory_rounded,
                        size: 16,
                        color: isWarning ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Memory: ${memoryUsage.toStringAsFixed(1)}MB',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isWarning ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            // Cancel button
            if (onCancel != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileProgressList(LazyCsvService service, ThemeData theme, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: csvTypes.map((csvType) {
        final state = service.getLoadingState(csvType);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // Status icon
              SizedBox(
                width: 20,
                height: 20,
                child: state.isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : state.error != null
                        ? Icon(Icons.error, color: Colors.red, size: 16)
                        : state.progress == 1.0
                            ? Icon(Icons.check_circle, color: Colors.green, size: 16)
                            : Icon(Icons.pending, color: Colors.grey, size: 16),
              ),
              const SizedBox(width: 12),
              
              // File name and progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDisplayName(csvType),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: state.error != null ? Colors.red : null,
                      ),
                    ),
                    if (state.isLoading) ...[
                      const SizedBox(height: 2),
                      LinearProgressIndicator(
                        value: state.progress,
                        backgroundColor: primaryColor.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        minHeight: 2,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Progress percentage
              if (state.isLoading)
                Text(
                  '${(state.progress * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  double _getOverallProgress(LazyCsvService service) {
    if (csvTypes.isEmpty) return 0.0;
    
    double totalProgress = 0.0;
    for (final csvType in csvTypes) {
      final state = service.getLoadingState(csvType);
      totalProgress += state.progress;
    }
    
    return totalProgress / csvTypes.length;
  }

  String _getDisplayName(CsvType csvType) {
    switch (csvType) {
      case CsvType.salesMaster:
        return 'Sales Master';
      case CsvType.salesDetails:
        return 'Sales Details';
      case CsvType.itemMaster:
        return 'Item Master';
      case CsvType.itemDetail:
        return 'Item Details';
      case CsvType.accountMaster:
        return 'Account Master';
      case CsvType.allAccounts:
        return 'All Accounts';
      case CsvType.customerInfo:
        return 'Customer Info';
      case CsvType.supplierInfo:
        return 'Supplier Info';
    }
  }
}

/// A simple loading widget for single CSV loading
class SimpleCsvLoadingWidget extends StatelessWidget {
  final CsvType csvType;
  final String? customMessage;
  final Color? color;

  const SimpleCsvLoadingWidget({
    super.key,
    required this.csvType,
    this.customMessage,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final lazyCsvService = Get.find<LazyCsvService>();
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.primaryColor;

    return GetBuilder<LazyCsvService>(
      builder: (_) {
        final state = lazyCsvService.getLoadingState(csvType);
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  backgroundColor: effectiveColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
                  value: state.progress,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                customMessage ?? 'Loading ${_getDisplayName(csvType)}...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: effectiveColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (state.progress > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${(state.progress * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: effectiveColor.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _getDisplayName(CsvType csvType) {
    switch (csvType) {
      case CsvType.salesMaster:
        return 'Sales Master';
      case CsvType.salesDetails:
        return 'Sales Details';
      case CsvType.itemMaster:
        return 'Item Master';
      case CsvType.itemDetail:
        return 'Item Details';
      case CsvType.accountMaster:
        return 'Account Master';
      case CsvType.allAccounts:
        return 'All Accounts';
      case CsvType.customerInfo:
        return 'Customer Info';
      case CsvType.supplierInfo:
        return 'Supplier Info';
    }
  }
}

/// A loading indicator that can be used in app bars or small spaces
class CsvLoadingIndicator extends StatelessWidget {
  final List<CsvType> csvTypes;
  final double size;
  final Color? color;

  const CsvLoadingIndicator({
    super.key,
    required this.csvTypes,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final lazyCsvService = Get.find<LazyCsvService>();
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.primaryColor;

    return GetBuilder<LazyCsvService>(
      builder: (_) {
        final anyLoading = csvTypes.any((type) => lazyCsvService.isLoading(type));
        final progress = _getOverallProgress(lazyCsvService);
        
        if (!anyLoading) return const SizedBox.shrink();
        
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            backgroundColor: effectiveColor.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
            value: progress,
          ),
        );
      },
    );
  }

  double _getOverallProgress(LazyCsvService service) {
    if (csvTypes.isEmpty) return 0.0;
    
    double totalProgress = 0.0;
    for (final csvType in csvTypes) {
      final state = service.getLoadingState(csvType);
      totalProgress += state.progress;
    }
    
    return totalProgress / csvTypes.length;
  }
}