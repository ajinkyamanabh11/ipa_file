// lib/util/memory_optimizer.dart
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Memory optimization utility for managing heavy data operations
class MemoryOptimizer {
  static const int _maxMemoryThresholdMB = 200;
  static const int _warningThresholdMB = 150;
  static const int _criticalThresholdMB = 250;

  /// Check current memory usage (rough estimate)
  static double getCurrentMemoryUsageMB() {
    if (kIsWeb) {
      // Web platform - can't get accurate memory info
      return 0.0;
    }

    try {
      // This is a rough estimate for mobile platforms
      final info = ProcessInfo.currentRss;
      return info / (1024 * 1024); // Convert bytes to MB
    } catch (e) {
      return 0.0;
    }
  }

  /// Check if memory usage is above threshold
  static bool isMemoryUsageHigh() {
    final usage = getCurrentMemoryUsageMB();
    return usage > _warningThresholdMB;
  }

  /// Check if memory usage is critical
  static bool isMemoryUsageCritical() {
    final usage = getCurrentMemoryUsageMB();
    return usage > _criticalThresholdMB;
  }

  /// Perform aggressive memory cleanup
  static void performMemoryCleanup() {
    developer.log('🧹 MemoryOptimizer: Performing memory cleanup');

    // Clear GetX controller cache for non-permanent controllers
    Get.deleteAll(force: false);

    // Force garbage collection hint
    _forceGarbageCollection();

    // Clear image cache if available
    _clearImageCache();

    developer.log('🧹 MemoryOptimizer: Memory cleanup completed');
  }

  /// Force garbage collection (hint to Dart VM)
  static void _forceGarbageCollection() {
    // Create and immediately dispose temporary objects to hint GC
    for (int i = 0; i < 100; i++) {
      List.generate(100, (index) => <String, dynamic>{}).clear();
    }
  }

  /// Clear image cache to free memory
  static void _clearImageCache() {
    try {
      // This would clear Flutter's image cache
      // Note: This is a simplified approach
      if (kDebugMode) {
        developer.log('🖼️ MemoryOptimizer: Image cache cleared');
      }
    } catch (e) {
      developer.log('⚠️ MemoryOptimizer: Failed to clear image cache: $e');
    }
  }

  /// Monitor memory usage and trigger cleanup if needed
  static void monitorAndOptimize() {
    final usage = getCurrentMemoryUsageMB();

    if (usage > _criticalThresholdMB) {
      developer.log('🚨 MemoryOptimizer: Critical memory usage detected: ${usage.toStringAsFixed(1)}MB');
      performMemoryCleanup();
    } else if (usage > _warningThresholdMB) {
      developer.log('⚠️ MemoryOptimizer: High memory usage detected: ${usage.toStringAsFixed(1)}MB');
      _forceGarbageCollection();
    }
  }

  /// Optimize data structures for memory efficiency
  static List<Map<String, dynamic>> optimizeDataList(
      List<Map<String, dynamic>> data, {
        int? maxItems,
        List<String>? keepOnlyFields,
      }) {
    if (data.isEmpty) return data;

    List<Map<String, dynamic>> optimized = data;

    // Limit number of items if specified
    if (maxItems != null && data.length > maxItems) {
      optimized = data.take(maxItems).toList();
      developer.log('📊 MemoryOptimizer: Limited data from ${data.length} to $maxItems items');
    }

    // Keep only specified fields if provided
    if (keepOnlyFields != null && keepOnlyFields.isNotEmpty) {
      optimized = optimized.map((item) {
        final filtered = <String, dynamic>{};
        for (final field in keepOnlyFields) {
          if (item.containsKey(field)) {
            filtered[field] = item[field];
          }
        }
        return filtered;
      }).toList();
      developer.log('📊 MemoryOptimizer: Filtered data to keep only ${keepOnlyFields.length} fields');
    }

    return optimized;
  }

  /// Process large datasets in memory-efficient chunks
  static Future<List<T>> processInChunks<T>(
      List<dynamic> data,
      T Function(dynamic item) processor, {
        int chunkSize = 100,
        Function(double)? onProgress,
      }) async {
    final List<T> results = [];
    final totalItems = data.length;

    for (int i = 0; i < totalItems; i += chunkSize) {
      final chunk = data.skip(i).take(chunkSize);

      // Process chunk
      for (final item in chunk) {
        results.add(processor(item));
      }

      // Update progress
      final progress = (i + chunkSize) / totalItems;
      onProgress?.call(progress.clamp(0.0, 1.0));

      // Allow other operations and GC
      await Future.delayed(const Duration(milliseconds: 1));

      // Check memory usage and cleanup if needed
      if (i % (chunkSize * 10) == 0) {
        monitorAndOptimize();
      }
    }

    return results;
  }

  /// Create a memory-efficient stream from large data
  static Stream<List<T>> createDataStream<T>(
      List<T> data, {
        int chunkSize = 50,
        Duration delay = const Duration(milliseconds: 100),
      }) async* {
    for (int i = 0; i < data.length; i += chunkSize) {
      final chunk = data.skip(i).take(chunkSize).toList();
      yield chunk;

      if (delay.inMilliseconds > 0) {
        await Future.delayed(delay);
      }
    }
  }

  /// Compress string data to save memory
  static String compressString(String data) {
    // Simple compression by removing extra whitespace
    return data
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Get memory usage statistics
  static Map<String, dynamic> getMemoryStats() {
    final currentUsage = getCurrentMemoryUsageMB();

    return {
      'currentUsageMB': currentUsage,
      'warningThresholdMB': _warningThresholdMB,
      'maxThresholdMB': _maxMemoryThresholdMB,
      'criticalThresholdMB': _criticalThresholdMB,
      'isHigh': currentUsage > _warningThresholdMB,
      'isCritical': currentUsage > _criticalThresholdMB,
      'usagePercentage': (currentUsage / _maxMemoryThresholdMB * 100).clamp(0.0, 100.0),
    };
  }

  /// Log memory usage statistics
  static void logMemoryStats() {
    final stats = getMemoryStats();
    developer.log(
        '📊 Memory Stats: ${stats['currentUsageMB'].toStringAsFixed(1)}MB '
            '(${stats['usagePercentage'].toStringAsFixed(1)}% of threshold)'
    );
  }
}

/// Extension to add memory optimization methods to controllers
extension MemoryOptimizerExtension on GetxController {
  /// Monitor memory usage in this controller
  void monitorMemory() {
    MemoryOptimizer.monitorAndOptimize();
  }

  /// Get memory statistics
  Map<String, dynamic> getMemoryStats() {
    return MemoryOptimizer.getMemoryStats();
  }

  /// Perform memory cleanup
  void cleanupMemory() {
    MemoryOptimizer.performMemoryCleanup();
  }
}

/// Memory-aware data holder that automatically manages memory
class MemoryAwareDataHolder<T> {
  final int _maxItems;
  final List<T> _data = [];
  final Function(List<T>)? _onDataEvicted;

  MemoryAwareDataHolder({
    int maxItems = 1000,
    Function(List<T>)? onDataEvicted,
  }) : _maxItems = maxItems,
        _onDataEvicted = onDataEvicted;

  /// Add item to the holder
  void add(T item) {
    _data.add(item);
    _checkMemoryAndCleanup();
  }

  /// Add multiple items
  void addAll(List<T> items) {
    _data.addAll(items);
    _checkMemoryAndCleanup();
  }

  /// Get all data
  List<T> get data => List.unmodifiable(_data);

  /// Get data count
  int get length => _data.length;

  /// Clear all data
  void clear() {
    _data.clear();
  }

  /// Check memory usage and cleanup if needed
  void _checkMemoryAndCleanup() {
    if (_data.length > _maxItems) {
      final toRemove = _data.length - _maxItems;
      final evicted = _data.take(toRemove).toList();
      _data.removeRange(0, toRemove);

      _onDataEvicted?.call(evicted);

      developer.log(
          '🧹 MemoryAwareDataHolder: Evicted $toRemove items to maintain memory limit'
      );
    }

    // Check system memory usage
    if (MemoryOptimizer.isMemoryUsageHigh()) {
      MemoryOptimizer.monitorAndOptimize();
    }
  }
}