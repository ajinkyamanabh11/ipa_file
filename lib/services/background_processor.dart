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

  // Memory management
  static const int _maxConcurrentTasks = 2;
  static const int _maxMemoryUsageMB = 150;
  int _activeTasks = 0;

  @override
  void onInit() {
    super.onInit();
    _startQueueProcessor();
  }

  /// Add a task to the background processing queue
  Future<T> addTask<T>(BackgroundTask<T> task) async {
    _taskQueue.add(task);
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
  }) async {
    final task = BackgroundTask<List<Map<String, dynamic>>>(
      name: taskName,
      operation: 'csv_parse',
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

  /// Start the queue processor
  void _startQueueProcessor() {
    Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (!_isProcessingQueue && _taskQueue.isNotEmpty && _activeTasks < _maxConcurrentTasks) {
        _processQueue();
      }
    });
  }

  /// Process the task queue
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
      task._completer?.completeError(e);
    } finally {
      _activeTasks--;
      _isProcessingQueue = false;
      
      if (_taskQueue.isEmpty) {
        isProcessing.value = false;
        currentTask.value = '';
        progress.value = 0.0;
      }
    }
  }

  /// Execute a background task
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

  /// Execute CSV parsing task
  Future<List<Map<String, dynamic>>> _executeCsvParseTask(BackgroundTask task) async {
    final csvData = task.data['csvData'] as String;
    final shouldParse = task.data['shouldParse'] as bool? ?? true;

    if (!shouldParse) {
      // Just return empty list if parsing not needed
      return [];
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

  /// Execute dataset processing task
  Future<List<Map<String, dynamic>>> _executeDatasetProcessTask(BackgroundTask task) async {
    final data = List<Map<String, dynamic>>.from(task.data['data']);
    final operation = task.data['operation'] as String;
    final filters = task.data['filters'] as Map<String, dynamic>;
    final chunkSize = task.data['chunkSize'] as int;

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
      await Future.delayed(Duration(milliseconds: 10));
    }

    return results;
  }

  /// Get current memory usage estimate
  double getMemoryUsageEstimate() {
    // This is a rough estimate based on queue size and active tasks
    return (_taskQueue.length * 10) + (_activeTasks * 50);
  }

  /// Clear completed tasks and optimize memory
  void optimizeMemory() {
    // Force garbage collection hint
    List.generate(100, (index) => []).clear();
    
    // Log memory optimization
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
    
    isProcessing.value = false;
    currentTask.value = '';
    progress.value = 0.0;
  }

  @override
  void onClose() {
    cancelAllTasks();
    super.onClose();
  }
}

/// Represents a background processing task
class BackgroundTask<T> {
  final String name;
  final String operation;
  final Map<String, dynamic> data;
  final Function(double)? onProgress;
  
  Completer<T>? _completer;

  BackgroundTask({
    required this.name,
    required this.operation,
    required this.data,
    this.onProgress,
  });
}

/// Extension to easily access BackgroundProcessor
extension BackgroundProcessorExtension on GetxController {
  BackgroundProcessor get backgroundProcessor => Get.find<BackgroundProcessor>();
}