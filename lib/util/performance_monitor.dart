import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  static bool _isInitialized = false;
  static int _frameCount = 0;
  static int _droppedFrames = 0;
  static Duration _totalFrameTime = Duration.zero;

  /// Initialize performance monitoring
  static void initialize() {
    if (_isInitialized || kReleaseMode) return;
    _isInitialized = true;

    // Monitor frame rendering performance
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);

    // Log performance metrics periodically
    _startPeriodicLogging();
  }

  static void _onFrame(Duration timestamp) {
    _frameCount++;

    // Track frame timing
    final frameStart = DateTime.now();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final frameEnd = DateTime.now();
      final frameDuration = frameEnd.difference(frameStart);
      _totalFrameTime += frameDuration;

      // Consider frames longer than 16ms as dropped (60fps target)
      if (frameDuration.inMilliseconds > 16) {
        _droppedFrames++;
        if (kDebugMode) {
          developer.log(
            'Slow frame detected: ${frameDuration.inMilliseconds}ms',
            name: 'PerformanceMonitor',
          );
        }
      }
    });
  }

  static void _startPeriodicLogging() {
    if (kReleaseMode) return;

    // Log performance summary every 30 seconds
    Stream.periodic(const Duration(seconds: 30)).listen((_) {
      logPerformanceSummary();
    });
  }

  /// Log current performance metrics
  static void logPerformanceSummary() {
    if (kReleaseMode || _frameCount == 0) return;

    final avgFrameTime = _totalFrameTime.inMilliseconds / _frameCount;
    final droppedFramePercentage = (_droppedFrames / _frameCount) * 100;

    developer.log(
      'Performance Summary:\n'
          'Total Frames: $_frameCount\n'
          'Dropped Frames: $_droppedFrames (${droppedFramePercentage.toStringAsFixed(1)}%)\n'
          'Average Frame Time: ${avgFrameTime.toStringAsFixed(2)}ms\n'
          'Target: <16ms for 60fps',
      name: 'PerformanceMonitor',
    );
  }

  /// Mark the start of a potentially expensive operation
  static Stopwatch startOperation(String operationName) {
    if (kReleaseMode) return Stopwatch();

    final stopwatch = Stopwatch()..start();
    developer.log('Started: $operationName', name: 'PerformanceMonitor');
    return stopwatch;
  }

  /// Mark the end of an operation and log its duration
  static void endOperation(String operationName, Stopwatch stopwatch) {
    if (kReleaseMode) return;

    stopwatch.stop();
    final duration = stopwatch.elapsedMilliseconds;

    if (duration > 16) {
      developer.log(
        'Slow operation: $operationName took ${duration}ms',
        name: 'PerformanceMonitor',
      );
    } else if (kDebugMode) {
      developer.log(
        'Completed: $operationName (${duration}ms)',
        name: 'PerformanceMonitor',
      );
    }
  }

  /// Reset performance counters
  static void reset() {
    _frameCount = 0;
    _droppedFrames = 0;
    _totalFrameTime = Duration.zero;
  }

  /// Get current performance stats
  static Map<String, dynamic> getStats() {
    if (_frameCount == 0) {
      return {
        'frameCount': 0,
        'droppedFrames': 0,
        'averageFrameTime': 0.0,
        'droppedFramePercentage': 0.0,
      };
    }

    return {
      'frameCount': _frameCount,
      'droppedFrames': _droppedFrames,
      'averageFrameTime': _totalFrameTime.inMilliseconds / _frameCount,
      'droppedFramePercentage': (_droppedFrames / _frameCount) * 100,
    };
  }
}