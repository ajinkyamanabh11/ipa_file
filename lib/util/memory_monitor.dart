// lib/util/memory_monitor.dart

import 'package:get/get.dart';
import 'dart:developer';
import 'dart:async';

class MemoryMonitor extends GetxController {
  final RxDouble currentMemoryUsageMB = 0.0.obs;
  final RxBool isMemoryWarning = false.obs;
  final RxBool isMemoryCritical = false.obs;
  
  Timer? _monitoringTimer;
  
  // Memory thresholds
  static const double _warningThresholdMB = 100.0;
  static const double _criticalThresholdMB = 150.0;
  
  @override
  void onInit() {
    super.onInit();
    _startMonitoring();
  }
  
  @override
  void onClose() {
    _monitoringTimer?.cancel();
    super.onClose();
  }
  
  void _startMonitoring() {
    // Monitor memory every 15 seconds
    _monitoringTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      _checkMemoryUsage();
    });
  }
  
  void _checkMemoryUsage() {
    // This is a simplified memory check
    // In a real app, you might want to use platform-specific memory APIs
    
    // Estimate memory usage based on data size
    double estimatedUsage = _estimateMemoryUsage();
    currentMemoryUsageMB.value = estimatedUsage;
    
    if (estimatedUsage > _criticalThresholdMB) {
      isMemoryCritical.value = true;
      isMemoryWarning.value = true;
      log('🚨 MemoryMonitor: CRITICAL memory usage: ${estimatedUsage.toStringAsFixed(1)}MB');
      _handleCriticalMemory();
    } else if (estimatedUsage > _warningThresholdMB) {
      isMemoryWarning.value = true;
      isMemoryCritical.value = false;
      log('⚠️ MemoryMonitor: High memory usage: ${estimatedUsage.toStringAsFixed(1)}MB');
    } else {
      isMemoryWarning.value = false;
      isMemoryCritical.value = false;
    }
  }
  
  double _estimateMemoryUsage() {
    // This is a rough estimate - in a real app you'd use platform APIs
    // For now, we'll return a placeholder value
    return 50.0; // Placeholder - replace with actual memory calculation
  }
  
  void _handleCriticalMemory() {
    // Trigger memory cleanup
    _requestMemoryCleanup();
  }
  
  void _requestMemoryCleanup() {
    // Hint to Dart VM to perform garbage collection
    List.generate(1000, (index) => []).clear();
    
    // You can also trigger cleanup in other services
    // For example, clear non-essential cached data
  }
  
  /// Manual memory cleanup request
  void requestCleanup() {
    log('🧹 MemoryMonitor: Manual cleanup requested');
    _requestMemoryCleanup();
  }
  
  /// Get memory status message
  String get memoryStatus {
    if (isMemoryCritical.value) {
      return 'Critical: ${currentMemoryUsageMB.value.toStringAsFixed(1)}MB';
    } else if (isMemoryWarning.value) {
      return 'High: ${currentMemoryUsageMB.value.toStringAsFixed(1)}MB';
    } else {
      return 'Normal: ${currentMemoryUsageMB.value.toStringAsFixed(1)}MB';
    }
  }
  
  /// Check if memory usage is acceptable for new operations
  bool get canPerformHeavyOperation {
    return currentMemoryUsageMB.value < _warningThresholdMB;
  }
}