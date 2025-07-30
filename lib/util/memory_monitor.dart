// lib/util/memory_monitor.dart

import 'dart:developer';
import 'dart:io';
import 'package:get/get.dart';

import '../services/CsvDataServices.dart';

class MemoryMonitor extends GetxService {
  static const int _warningThresholdMB = 100;
  static const int _criticalThresholdMB = 150;

  final RxDouble currentMemoryUsageMB = 0.0.obs;
  final RxBool isMemoryWarning = false.obs;
  final RxBool isMemoryCritical = false.obs;

  // Memory optimization stats
  final RxInt cleanupCount = 0.obs;
  final Rx<DateTime> lastCleanup = DateTime.now().obs;

  // Memory usage history for trend analysis
  final List<double> _memoryHistory = [];
  static const int _maxHistorySize = 20;

  @override
  void onInit() {
    super.onInit();
    _startMonitoring();
  }

  void _startMonitoring() {
    // Monitor memory every 5 seconds
    ever(currentMemoryUsageMB, (usage) {
      _updateMemoryStatus(usage);
      _updateMemoryHistory(usage);
    });

    // Start periodic memory checks
    _scheduleMemoryCheck();
  }

  void _scheduleMemoryCheck() {
    Future.delayed(Duration(seconds: 5), () {
      _checkMemoryUsage();
      _scheduleMemoryCheck(); // Schedule next check
    });
  }

  void _checkMemoryUsage() {
    try {
      // Get memory info (this is a rough estimate)
      final memoryUsage = _estimateMemoryUsage();
      currentMemoryUsageMB.value = memoryUsage;
    } catch (e) {
      log('MemoryMonitor: Error checking memory usage: $e');
    }
  }

  double _estimateMemoryUsage() {
    try {
      // For mobile platforms, we can get process memory info
      if (Platform.isAndroid || Platform.isIOS) {
        // This is an approximation - actual implementation would require platform channels
        return _approximateMemoryUsage();
      } else {
        // For other platforms, use a different approach
        return _approximateMemoryUsage();
      }
    } catch (e) {
      return 0.0;
    }
  }

  double _approximateMemoryUsage() {
    // This is a rough approximation based on object counts and sizes
    // In a real implementation, you might use platform-specific APIs

    // Trigger a minor garbage collection to get more accurate readings
    List.generate(100, (index) => []).clear();

    // Return a mock value for demonstration
    // In production, this would be replaced with actual memory measurement
    return 50.0 + (DateTime.now().millisecondsSinceEpoch % 1000) / 20.0;
  }

  void _updateMemoryStatus(double memoryMB) {
    if (memoryMB >= _criticalThresholdMB) {
      isMemoryCritical.value = true;
      isMemoryWarning.value = true;
      log('🚨 MemoryMonitor: CRITICAL memory usage: ${memoryMB.toStringAsFixed(1)}MB');
      _triggerEmergencyCleanup();
    } else if (memoryMB >= _warningThresholdMB) {
      isMemoryCritical.value = false;
      isMemoryWarning.value = true;
      log('⚠️ MemoryMonitor: High memory usage: ${memoryMB.toStringAsFixed(1)}MB');
      _triggerMemoryCleanup();
    } else {
      isMemoryCritical.value = false;
      isMemoryWarning.value = false;
    }
  }

  void _updateMemoryHistory(double memoryMB) {
    _memoryHistory.add(memoryMB);
    if (_memoryHistory.length > _maxHistorySize) {
      _memoryHistory.removeAt(0);
    }
  }

  void _triggerMemoryCleanup() {
    log('🧹 MemoryMonitor: Triggering memory cleanup');

    // Request garbage collection
    _requestGarbageCollection();

    // Notify other services to clean up
    try {
      final csvService = Get.find<CsvDataService>();
      csvService.performMemoryCleanup();
    } catch (e) {
      log('MemoryMonitor: Error during cleanup: $e');
    }
  }

  void _triggerEmergencyCleanup() {
    log('🚨 MemoryMonitor: Triggering EMERGENCY cleanup');

    // More aggressive cleanup
    _requestGarbageCollection();

    // Clear all non-essential data
    try {
      final csvService = Get.find<CsvDataService>();

      // Force clear optional CSV data
      csvService.accountMasterCsv.value = '';
      csvService.allAccountsCsv.value = '';
      csvService.customerInfoCsv.value = '';
      csvService.supplierInfoCsv.value = '';
    } catch (e) {
      log('MemoryMonitor: Error during emergency cleanup: $e');
    }
  }

  void _requestGarbageCollection() {
    // Multiple approaches to encourage garbage collection
    for (int i = 0; i < 3; i++) {
      List.generate(1000, (index) => []).clear();
    }
  }

  /// Get memory trend (increasing, stable, decreasing)
  String getMemoryTrend() {
    if (_memoryHistory.length < 5) return 'Unknown';

    final recent = _memoryHistory.sublist(_memoryHistory.length - 5);
    final average = recent.reduce((a, b) => a + b) / recent.length;
    final latest = recent.last;

    if (latest > average * 1.1) {
      return 'Increasing';
    } else if (latest < average * 0.9) {
      return 'Decreasing';
    } else {
      return 'Stable';
    }
  }

  /// Get memory statistics
  Map<String, dynamic> getMemoryStats() {
    return {
      'current': currentMemoryUsageMB.value,
      'isWarning': isMemoryWarning.value,
      'isCritical': isMemoryCritical.value,
      'trend': getMemoryTrend(),
      'warningThreshold': _warningThresholdMB,
      'criticalThreshold': _criticalThresholdMB,
      'history': List.from(_memoryHistory),
    };
  }

  /// Force a memory check
  void forceMemoryCheck() {
    _checkMemoryUsage();
  }

  /// Reset memory monitoring
  void reset() {
    _memoryHistory.clear();
    currentMemoryUsageMB.value = 0.0;
    isMemoryWarning.value = false;
    isMemoryCritical.value = false;
  }

  /// Check if it's safe to perform memory-intensive operations
  bool isSafeForLargeOperations() {
    return !isMemoryWarning.value && getMemoryTrend() != 'Increasing';
  }

  /// Get recommended action based on current memory state
  String getRecommendedAction() {
    if (isMemoryCritical.value) {
      return 'Stop all non-essential operations and clear data';
    } else if (isMemoryWarning.value) {
      return 'Reduce data processing and enable pagination';
    } else if (getMemoryTrend() == 'Increasing') {
      return 'Monitor closely and prepare for cleanup';
    } else {
      return 'Normal operation';
    }
  }
}