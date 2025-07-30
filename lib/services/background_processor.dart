// lib/services/background_processor.dart
import 'dart:async';
import 'dart:isolate';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import '../util/csv_worker.dart';

/// Service for handling heavy background processing tasks
class BackgroundProcessor extends GetxService {
  // Processing state
  final RxBool isProcessing = false.obs;
  final RxDouble progress = 0.0.obs;
  final RxString currentTask = ''.obs;
  final RxInt queueLength = 0.obs;

  // Task queue
  final List<BackgroundTask> _taskQueue = [];
  bool _isProcessingQueue = false;

  // Memory management - reduced for better performance
  static const int _maxConcurrentTasks = 1; // Reduced to prevent overwhelm
  static const int _maxMemoryUsageMB = 100; // Reduced memory limit
  int _activeTasks = 0;

  // Performance monitoring
  Timer? _queueTimer;
  final RxBool isHighMemoryUsage = false.obs;

  @override
  void onInit() {
    super.onInit();
    _startQueueProcessor();
    _startMemoryMonitoring();
  }

  @override
  void onClose() {
    _queueTimer?.cancel();
    cancelAllTasks();
    super.onClose();
  }

  /// Start memory monitoring to prevent excessive usage
  void _startMemoryMonitoring() {
    Timer.periodic(Duration(seconds: 5), (timer) {
      final memoryEstimate = getMemoryUsageEstimate();
      isHighMemoryUsage.value = memoryEstimate > _maxMemoryUsageMB;
      
      if (isHighMemoryUsage.value) {
        optimizeMemory();
      }
    });
  }

  /// Add a task to the background processing queue with priority handling
  Future<T> addTask<T>(BackgroundTask<T> task) async {
    // Skip if memory usage is too high for non-critical tasks
    if (isHighMemoryUsage.value && task.priority > 1) {
      if (kDebugMode) {
        print('🚫 BackgroundProcessor: Skipping non-critical task due to high memory usage');
      }
      throw Exception('Memory usage too high for non-critical operations');
    }

    _taskQueue.add(task);
    _taskQueue.sort((a, b) => a.priority.compareTo(b.priority)); // Sort by priority
    queueLength.value = _taskQueue.length;

    final completer = Completer<T>();
    task._completer = completer;

    _processQueue();
    return completer.future;
  }

  /// Process CSV data in background with progress updates
  Future<List<Map<String, dynamic>>> processCsvData({
    required String csvData,
    required String taskName,
    bool shouldParse = true,
    Function(double)? onProgress,
    int priority = 2, // Default priority
  }) async {
    final task = BackgroundTask<List<Map<String, dynamic>>>(
      name: taskName,
      operation: 'csv_parse',
      priority: priority,
      data: {
        'csvData': csvData,
        'shouldParse': shouldParse,
      },
      onProgress: onProgress,
    );

    return await addTask(task);
  }

  /// Process large dataset in chunks with progress updates
  Future<List<Map<String, dynamic>>> processLargeDataset({
    required List<Map<String, dynamic>> data,
    required String operation,
    required String taskName,
    Map<String, dynamic>? filters,
    int chunkSize = 100,
    Function(double)? onProgress,
  }) async {
    final task = BackgroundTask<List<Map<String, dynamic>>>(
      name: taskName,
      operation: 'dataset_process',
      data: {
        'data': data,
        'operation': operation,
        'filters': filters ?? {},
        'chunkSize': chunkSize,
      },
      onProgress: onProgress,
    );

    return await addTask(task);
  }

  /// Start the queue processor with better timing
  void _startQueueProcessor() {
    _queueTimer = Timer.periodic(Duration(milliseconds: 50), (timer) {
      if (!_isProcessingQueue && _taskQueue.isNotEmpty && _activeTasks < _maxConcurrentTasks) {
        _processQueue();
      }
    });
  }

  /// Process the task queue with better error handling
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _taskQueue.isEmpty || _activeTasks >= _maxConcurrentTasks) {
      return;
    }

    _isProcessingQueue = true;
    _activeTasks++;

    final task = _taskQueue.removeAt(0);
    queueLength.value = _taskQueue.length;

    try {
      isProcessing.value = true;
      currentTask.value = task.name;
      progress.value = 0.0;

      final result = await _executeTask(task);
      task._completer?.complete(result);
    } catch (e) {
      if (kDebugMode) {
        print('❌ BackgroundProcessor: Task failed: ${task.name}, Error: $e');
      }
      task._completer?.completeError(e);
    } finally {
      _activeTasks--;
      _isProcessingQueue = false;

      if (_taskQueue.isEmpty && _activeTasks == 0) {
        isProcessing.value = false;
        currentTask.value = '';
        progress.value = 0.0;
      }

      // Schedule next task processing with a small delay to prevent blocking
      if (_taskQueue.isNotEmpty && _activeTasks < _maxConcurrentTasks) {
        Future.delayed(Duration(milliseconds: 10), () => _processQueue());
      }
    }
  }

  /// Execute a background task with better resource management
  Future<dynamic> _executeTask(BackgroundTask task) async {
    switch (task.operation) {
      case 'csv_parse':
        return await _executeCsvParseTask(task);
      case 'dataset_process':
        return await _executeDatasetProcessTask(task);
      default:
        throw Exception('Unknown task operation: ${task.operation}');
    }
  }

  /// Execute CSV parsing task with memory optimization
  Future<List<Map<String, dynamic>>> _executeCsvParseTask(BackgroundTask task) async {
    final csvData = task.data['csvData'] as String;
    final shouldParse = task.data['shouldParse'] as bool? ?? true;

    if (!shouldParse) {
      // Just return empty list if parsing not needed
      task.onProgress?.call(1.0);
      progress.value = 1.0;
      return [];
    }

    // Check data size and process accordingly
    final dataSizeMB = (csvData.length * 2) / (1024 * 1024);
    if (dataSizeMB > 50) { // For very large data
      return await _processLargeCsvInChunks(csvData, task);
    }

    // Use isolate for heavy parsing
    final result = await compute(parseAndCacheCsv, {
      'key': 'background_parse',
      'csvData': csvData,
      'shouldParse': shouldParse,
    });

    // Update progress
    progress.value = 1.0;
    task.onProgress?.call(1.0);

    // Return parsed data or empty list if parsing failed
    return List<Map<String, dynamic>>.from(result['parsedData'] ?? []);
  }

  /// Process large CSV files in chunks to prevent memory issues
  Future<List<Map<String, dynamic>>> _processLargeCsvInChunks(String csvData, BackgroundTask task) async {
    final lines = csvData.split('\n');
    final chunkSize = 1000; // Process 1000 lines at a time
    final results = <Map<String, dynamic>>[];
    
    if (lines.isEmpty) return results;
    
    final header = lines.first;
    final dataLines = lines.skip(1).toList();
    final totalChunks = (dataLines.length / chunkSize).ceil();
    
    for (int i = 0; i < dataLines.length; i += chunkSize) {
      final chunk = dataLines.skip(i).take(chunkSize).toList();
      final chunkCsv = '$header\n${chunk.join('\n')}';
      
      final chunkResult = await compute(parseAndCacheCsv, {
        'key': 'chunk_parse_$i',
        'csvData': chunkCsv,
        'shouldParse': true,
      });
      
      final chunkData = List<Map<String, dynamic>>.from(chunkResult['parsedData'] ?? []);
      results.addAll(chunkData);
      
      // Update progress
      final chunkProgress = ((i / chunkSize) + 1) / totalChunks;
      progress.value = chunkProgress;
      task.onProgress?.call(chunkProgress);
      
      // Allow UI thread to breathe
      await Future.delayed(Duration(milliseconds: 5));
    }
    
    return results;
  }

  /// Execute dataset processing task
  Future<List<Map<String, dynamic>>> _executeDatasetProcessTask(BackgroundTask task) async {
    final data = List<Map<String, dynamic>>.from(task.data['data']);
    final operation = task.data['operation'] as String;
    final filters = task.data['filters'] as Map<String, dynamic>;
    final chunkSize = task.data['chunkSize'] as int? ?? 500; // Smaller default chunk

    // Process in chunks with progress updates
    final List<Map<String, dynamic>> results = [];
    final totalChunks = (data.length / chunkSize).ceil();

    for (int i = 0; i < data.length; i += chunkSize) {
      final chunk = data.skip(i).take(chunkSize).toList();

      // Process chunk in isolate
      final chunkResult = await compute(processLargeDatasetInChunks, {
        'data': chunk,
        'operation': operation,
        'filters': filters,
        'chunkSize': chunkSize,
      });

      results.addAll(List<Map<String, dynamic>>.from(chunkResult['results'] ?? []));

      // Update progress
      final currentProgress = ((i / chunkSize) + 1) / totalChunks;
      progress.value = currentProgress;
      task.onProgress?.call(currentProgress);

      // Allow other tasks to process
      await Future.delayed(Duration(milliseconds: 5));
    }

    return results;
  }

  /// Get current memory usage estimate
  double getMemoryUsageEstimate() {
    // More accurate memory estimation
    final queueMemory = _taskQueue.length * 5; // 5MB per queued task
    final activeMemory = _activeTasks * 25; // 25MB per active task
    return queueMemory + activeMemory;
  }

  /// Clear completed tasks and optimize memory
  void optimizeMemory() {
    // Force garbage collection hint
    List.generate(50, (index) => []).clear(); // Reduced from 100

    if (kDebugMode) {
      print('🧹 BackgroundProcessor: Memory optimization performed');
    }
  }

  /// Cancel all pending tasks
  void cancelAllTasks() {
    for (final task in _taskQueue) {
      task._completer?.completeError('Task cancelled');
    }
    _taskQueue.clear();
    queueLength.value = 0;
  }

  /// Get processing statistics
  Map<String, dynamic> getStats() {
    return {
      'queueLength': _taskQueue.length,
      'activeTasks': _activeTasks,
      'isProcessing': isProcessing.value,
      'memoryUsage': getMemoryUsageEstimate(),
      'currentTask': currentTask.value,
      'progress': progress.value,
    };
  }
}

/// Represents a background processing task
class BackgroundTask<T> {
  final String name;
  final String operation;
  final Map<String, dynamic> data;
  final Function(double)? onProgress;
  final int priority; // Added priority field

  Completer<T>? _completer;

  BackgroundTask({
    required this.name,
    required this.operation,
    required this.data,
    this.onProgress,
    this.priority = 2, // Default priority
  });
}

/// Extension to easily access BackgroundProcessor
extension BackgroundProcessorExtension on GetxController {
  BackgroundProcessor get backgroundProcessor => Get.find<BackgroundProcessor>();
}