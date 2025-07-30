// lib/util/memory_monitor.dart

import 'dart:developer';
import 'dart:io';
import 'package:get/get.dart';

import '../services/CsvDataServices.dart';
import '../services/background_processor.dart';

class MemoryMonitor extends GetxService {
  static const int _warningThresholdMB = 120;
  static const int _criticalThresholdMB = 180;
  static const int _emergencyThresholdMB = 220;

  final RxDouble currentMemoryUsageMB = 0.0.obs;
  final RxBool isMemoryWarning = false.obs;
  final RxBool isMemoryCritical = false.obs;
  final RxBool isMemoryEmergency = false.obs;

  // Memory usage history for trend analysis
  final List<double> _memoryHistory = [];
  static const int _maxHistorySize = 30;

  // Memory pressure levels
  final RxString memoryPressureLevel = 'normal'.obs; // normal, warning, critical, emergency

  // Memory optimization stats
  final RxInt cleanupCount = 0.obs;
  final RxDateTime lastCleanup = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    _startMonitoring();
  }

  void _startMonitoring() {
    // Monitor memory every 3 seconds for better responsiveness
    ever(currentMemoryUsageMB, (usage) {
      _updateMemoryStatus(usage);
      _updateMemoryHistory(usage);
      _handleMemoryPressure(usage);
    });

    // Start periodic memory checks
    _scheduleMemoryCheck();
  }

  void _scheduleMemoryCheck() {
    Future.delayed(Duration(seconds: 3), () {
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
    double totalUsage = 0.0;

    try {
      // Get CSV data service memory usage
      if (Get.isRegistered<CsvDataService>()) {
        final csvService = Get.find<CsvDataService>();
        totalUsage += csvService.getCurrentMemoryUsageMB();
      }

      // Get background processor memory usage
      if (Get.isRegistered<BackgroundProcessor>()) {
        final backgroundProcessor = Get.find<BackgroundProcessor>();
        totalUsage += backgroundProcessor.getMemoryUsageEstimate();
      }

      // Add base app memory estimate (rough)
      totalUsage += 30.0; // Base app memory

      // Add system memory pressure if available (Android/iOS specific)
      if (Platform.isAndroid || Platform.isIOS) {
        // This is a rough estimate - in a real app you might use platform channels
        // to get actual memory usage from the native side
        totalUsage += _getSystemMemoryPressure();
      }

    } catch (e) {
      log('MemoryMonitor: Error estimating memory: $e');
      totalUsage = 50.0; // Fallback estimate
    }

    return totalUsage;
  }

  double _getSystemMemoryPressure() {
    // This is a placeholder - in a real implementation you would use
    // platform channels to get actual system memory pressure
    return 20.0; // Rough estimate
  }

  void _updateMemoryStatus(double usage) {
    isMemoryWarning.value = usage > _warningThresholdMB;
    isMemoryCritical.value = usage > _criticalThresholdMB;
    isMemoryEmergency.value = usage > _emergencyThresholdMB;

    // Update pressure level
    if (usage > _emergencyThresholdMB) {
      memoryPressureLevel.value = 'emergency';
    } else if (usage > _criticalThresholdMB) {
      memoryPressureLevel.value = 'critical';
    } else if (usage > _warningThresholdMB) {
      memoryPressureLevel.value = 'warning';
    } else {
      memoryPressureLevel.value = 'normal';
    }
  }

  void _updateMemoryHistory(double usage) {
    _memoryHistory.add(usage);
    if (_memoryHistory.length > _maxHistorySize) {
      _memoryHistory.removeAt(0);
    }
  }

  void _handleMemoryPressure(double usage) {
    if (usage > _emergencyThresholdMB) {
      _performEmergencyCleanup();
    } else if (usage > _criticalThresholdMB) {
      _performCriticalCleanup();
    } else if (usage > _warningThresholdMB) {
      _performWarningCleanup();
    }
  }

  void _performEmergencyCleanup() {
    log('🚨 MemoryMonitor: EMERGENCY cleanup triggered at ${currentMemoryUsageMB.value.toStringAsFixed(1)}MB');
    
    // Emergency cleanup - most aggressive
    _performCriticalCleanup();
    
    // Cancel non-essential background tasks
    if (Get.isRegistered<BackgroundProcessor>()) {
      final backgroundProcessor = Get.find<BackgroundProcessor>();
      backgroundProcessor.cancelAllTasks();
    }

    // Force multiple garbage collection cycles
    for (int i = 0; i < 3; i++) {
      _forceGarbageCollection();
    }

    cleanupCount.value++;
    lastCleanup.value = DateTime.now();
  }

  void _performCriticalCleanup() {
    log('⚠️ MemoryMonitor: CRITICAL cleanup triggered at ${currentMemoryUsageMB.value.toStringAsFixed(1)}MB');
    
    // Critical cleanup - aggressive
    _performWarningCleanup();

    // Clear more cached data
    if (Get.isRegistered<CsvDataService>()) {
      final csvService = Get.find<CsvDataService>();
      csvService.clearParsedCache();
      
      // Clear non-essential CSV data from memory (but keep in storage)
      csvService.performMemoryCleanup();
    }

    // Force garbage collection
    _forceGarbageCollection();

    cleanupCount.value++;
    lastCleanup.value = DateTime.now();
  }

  void _performWarningCleanup() {
    log('💡 MemoryMonitor: WARNING cleanup triggered at ${currentMemoryUsageMB.value.toStringAsFixed(1)}MB');
    
    // Warning cleanup - gentle
    if (Get.isRegistered<CsvDataService>()) {
      final csvService = Get.find<CsvDataService>();
      csvService.performMemoryCleanup();
    }

    // Optimize background processor memory
    if (Get.isRegistered<BackgroundProcessor>()) {
      final backgroundProcessor = Get.find<BackgroundProcessor>();
      backgroundProcessor.optimizeMemory();
    }

    cleanupCount.value++;
    lastCleanup.value = DateTime.now();
  }

  void _forceGarbageCollection() {
    // This is a hint to the Dart VM to consider garbage collection
    // Create and immediately discard objects to trigger GC
    final temp = List.generate(1000, (index) => List.filled(100, index));
    temp.clear();
  }

  /// Get memory trend (increasing, decreasing, stable)
  String getMemoryTrend() {
    if (_memoryHistory.length < 5) return 'unknown';

    final recent = _memoryHistory.skip(_memoryHistory.length - 5).toList();
    final average = recent.reduce((a, b) => a + b) / recent.length;
    final latest = recent.last;

    if (latest > average * 1.1) {
      return 'increasing';
    } else if (latest < average * 0.9) {
      return 'decreasing';
    } else {
      return 'stable';
    }
  }

  /// Get memory usage statistics
  Map<String, dynamic> getMemoryStats() {
    final stats = {
      'current': currentMemoryUsageMB.value,
      'trend': getMemoryTrend(),
      'pressureLevel': memoryPressureLevel.value,
      'cleanupCount': cleanupCount.value,
      'lastCleanup': lastCleanup.value.toIso8601String(),
      'isWarning': isMemoryWarning.value,
      'isCritical': isMemoryCritical.value,
      'isEmergency': isMemoryEmergency.value,
    };

    if (_memoryHistory.isNotEmpty) {
      stats['min'] = _memoryHistory.reduce((a, b) => a < b ? a : b);
      stats['max'] = _memoryHistory.reduce((a, b) => a > b ? a : b);
      stats['average'] = _memoryHistory.reduce((a, b) => a + b) / _memoryHistory.length;
    }

    return stats;
  }

  /// Force memory cleanup manually
  void forceCleanup({bool aggressive = false}) {
    log('🧹 MemoryMonitor: Manual cleanup requested (aggressive: $aggressive)');
    
    if (aggressive) {
      _performCriticalCleanup();
    } else {
      _performWarningCleanup();
    }
  }

  /// Check if memory usage is trending upward dangerously
  bool isMemoryTrendingUp() {
    if (_memoryHistory.length < 10) return false;

    final recent = _memoryHistory.skip(_memoryHistory.length - 5).toList();
    final older = _memoryHistory.skip(_memoryHistory.length - 10).take(5).toList();

    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.reduce((a, b) => a + b) / older.length;

    return recentAvg > olderAvg * 1.2; // 20% increase trend
  }

  /// Get color for memory status display
  String getMemoryStatusColor() {
    switch (memoryPressureLevel.value) {
      case 'emergency':
        return '#FF0000'; // Red
      case 'critical':
        return '#FF6600'; // Orange-Red
      case 'warning':
        return '#FFAA00'; // Orange
      default:
        return '#00AA00'; // Green
    }
  }

  /// Get memory status description
  String getMemoryStatusDescription() {
    final usage = currentMemoryUsageMB.value;
    final trend = getMemoryTrend();
    
    switch (memoryPressureLevel.value) {
      case 'emergency':
        return 'Emergency: ${usage.toStringAsFixed(1)}MB - App may crash soon!';
      case 'critical':
        return 'Critical: ${usage.toStringAsFixed(1)}MB - Performance severely impacted';
      case 'warning':
        return 'Warning: ${usage.toStringAsFixed(1)}MB - Memory usage high ($trend)';
      default:
        return 'Normal: ${usage.toStringAsFixed(1)}MB - Memory usage healthy ($trend)';
    }
  }

  /// Predict if memory will exceed threshold soon
  bool predictMemoryPressure() {
    if (_memoryHistory.length < 10) return false;

    final trend = getMemoryTrend();
    final current = currentMemoryUsageMB.value;
    
    // If trending up and close to warning threshold
    if (trend == 'increasing' && current > _warningThresholdMB * 0.8) {
      return true;
    }

    return false;
  }

  @override
  void onClose() {
    _memoryHistory.clear();
    super.onClose();
  }
}