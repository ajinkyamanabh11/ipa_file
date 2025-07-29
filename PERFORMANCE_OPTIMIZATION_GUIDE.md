# Performance Optimization Guide for Heavy Data Loading

This guide explains the optimizations implemented to prevent your Flutter app from hanging during heavy data operations.

## 🚀 Key Optimizations Implemented

### 1. **Enhanced Isolate Processing** ✅
- **File**: `lib/util/csv_worker.dart`
- **What it does**: Moves heavy CSV parsing and data processing to background isolates
- **Benefits**: Prevents UI thread blocking, maintains app responsiveness
- **Usage**:
```dart
// Parse CSV data in background
final parsed = await backgroundProcessor.processCsvData(
  csvData: largeCsvString,
  taskName: 'Processing Sales Data',
  shouldParse: true,
  onProgress: (progress) => print('Progress: ${progress * 100}%'),
);
```

### 2. **Background Processing Service** ✅
- **File**: `lib/services/background_processor.dart`
- **What it does**: Manages a queue of heavy operations with progress tracking
- **Benefits**: Non-blocking operations, progress updates, memory management
- **Features**:
  - Task queuing system
  - Progress tracking
  - Memory usage monitoring
  - Automatic cleanup

### 3. **Progressive Loading Widgets** ✅
- **File**: `lib/widget/progressive_loader.dart`
- **What it does**: Provides smooth loading animations and progress indicators
- **Components**:
  - `ProgressiveLoader`: Shows loading overlay with progress
  - `ShimmerListLoader`: Animated skeleton loading for lists
  - `LoadingOverlay`: Simple loading overlay
  - `SmartDataLoader`: Intelligent data loading with error handling

### 4. **Memory Optimization** ✅
- **File**: `lib/util/memory_optimizer.dart`
- **What it does**: Monitors and manages memory usage during heavy operations
- **Features**:
  - Memory usage monitoring
  - Automatic cleanup when thresholds are exceeded
  - Data structure optimization
  - Chunked processing

### 5. **Enhanced CSV Data Service** ✅
- **File**: `lib/services/CsvDataServices.dart` (updated)
- **Improvements**:
  - On-demand CSV parsing using background processor
  - Cached parsed data to avoid re-parsing
  - Memory-aware data loading
  - Progress tracking for large files

## 📱 How to Use the Optimizations

### In Your Screens

1. **Wrap your screen with ProgressiveLoader**:
```dart
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ProgressiveLoader(
      child: Scaffold(
        appBar: AppBar(title: Text('My Screen')),
        body: MyScreenContent(),
      ),
      showProgress: true,
      showQueue: true,
    );
  }
}
```

2. **Use SmartDataLoader for data loading**:
```dart
SmartDataLoader<List<Map<String, dynamic>>>(
  future: controller.loadHeavyData(),
  showProgress: true,
  loadingMessage: 'Loading sales data...',
  builder: (data) => ListView.builder(
    itemCount: data.length,
    itemBuilder: (context, index) => ListTile(
      title: Text(data[index]['name']),
    ),
  ),
  errorBuilder: (error) => Text('Error: $error'),
)
```

3. **Show shimmer loading while data loads**:
```dart
Obx(() => controller.isLoading.value
  ? ShimmerListLoader(itemCount: 10)
  : ListView.builder(...)
)
```

### In Your Controllers

1. **Use background processing for heavy operations**:
```dart
class MyController extends GetxController {
  final backgroundProcessor = Get.find<BackgroundProcessor>();
  
  Future<void> processHeavyData() async {
    final result = await backgroundProcessor.processLargeDataset(
      data: largeDataset,
      operation: 'filter',
      taskName: 'Processing Customer Data',
      filters: {'status': 'active'},
      onProgress: (progress) {
        // Update UI with progress
        processingProgress.value = progress;
      },
    );
  }
}
```

2. **Monitor memory usage**:
```dart
class MyController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    // Monitor memory usage
    ever(dataList, (_) => monitorMemory());
  }
  
  void loadData() async {
    // Check memory before loading
    if (getMemoryStats()['isCritical']) {
      cleanupMemory();
    }
    
    // Load data...
  }
}
```

### Memory-Aware Data Handling

```dart
// Use memory-aware data holder
final dataHolder = MemoryAwareDataHolder<Map<String, dynamic>>(
  maxItems: 1000,
  onDataEvicted: (evictedData) {
    print('Evicted ${evictedData.length} items from memory');
  },
);

// Add data safely
dataHolder.addAll(newData);
```

## 🛠️ Configuration Options

### Memory Thresholds
Adjust memory thresholds in `memory_optimizer.dart`:
```dart
static const int _maxMemoryThresholdMB = 200;  // Adjust based on device
static const int _warningThresholdMB = 150;
static const int _criticalThresholdMB = 250;
```

### Background Processing Limits
Configure in `background_processor.dart`:
```dart
static const int _maxConcurrentTasks = 2;  // Adjust based on device capability
static const int _maxMemoryUsageMB = 150;
```

### CSV Processing Chunk Sizes
Adjust in controllers:
```dart
const int chunkSize = 200; // Process 200 items at a time
```

## 📊 Performance Monitoring

### Enable Memory Monitoring
```dart
// In your controller
@override
void onInit() {
  super.onInit();
  
  // Log memory stats periodically
  Timer.periodic(Duration(seconds: 30), (_) {
    MemoryOptimizer.logMemoryStats();
  });
}
```

### Track Background Processing
```dart
// Monitor background processor
final backgroundProcessor = Get.find<BackgroundProcessor>();

Obx(() => Text(
  'Processing: ${backgroundProcessor.currentTask.value} '
  '(${(backgroundProcessor.progress.value * 100).toInt()}%)'
));
```

## 🎯 Best Practices

### 1. **Lazy Loading**
- Load data only when needed
- Use pagination for large datasets
- Implement virtual scrolling for very long lists

### 2. **Data Caching**
- Cache parsed data to avoid re-processing
- Use intelligent cache invalidation
- Clear cache when memory is low

### 3. **Progressive Enhancement**
- Show skeleton/shimmer loading immediately
- Load critical data first
- Load secondary data in background

### 4. **Memory Management**
- Monitor memory usage regularly
- Clean up unused data
- Use memory-aware data structures

### 5. **User Experience**
- Always show progress indicators
- Provide cancellation options for long operations
- Give feedback on what's happening

## 🔧 Troubleshooting

### App Still Hanging?

1. **Check isolate usage**: Ensure heavy operations use `compute()` or `Isolate.run()`
2. **Reduce chunk sizes**: Smaller chunks = more responsive UI
3. **Add more progress updates**: Update UI more frequently
4. **Monitor memory**: Use memory optimizer to prevent OOM crashes

### Memory Issues?

1. **Enable aggressive cleanup**: Lower memory thresholds
2. **Reduce data retention**: Keep less data in memory
3. **Use streaming**: Process data as streams instead of loading all at once

### Performance Still Poor?

1. **Profile your app**: Use Flutter DevTools to identify bottlenecks
2. **Optimize data structures**: Use more efficient data representations
3. **Consider pagination**: Don't load all data at once
4. **Use lazy loading**: Load data on-demand

## 📝 Example Implementation

Here's a complete example of how to implement optimized data loading:

```dart
class OptimizedDataScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ProgressiveLoader(
      child: Scaffold(
        appBar: AppBar(title: Text('Optimized Data Loading')),
        body: GetBuilder<OptimizedDataController>(
          builder: (controller) => SmartDataLoader<List<Map<String, dynamic>>>(
            future: controller.loadOptimizedData(),
            showProgress: true,
            loadingMessage: 'Loading data efficiently...',
            loadingWidget: ShimmerListLoader(itemCount: 10),
            builder: (data) => ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(data[index]['title'] ?? ''),
                subtitle: Text(data[index]['description'] ?? ''),
              ),
            ),
            errorBuilder: (error) => ErrorWidget(error),
          ),
        ),
      ),
    );
  }
}

class OptimizedDataController extends GetxController {
  final backgroundProcessor = Get.find<BackgroundProcessor>();
  final csvDataService = Get.find<CsvDataService>();
  
  Future<List<Map<String, dynamic>>> loadOptimizedData() async {
    // Load CSV data first
    await csvDataService.loadAllCsvs();
    
    // Parse data in background
    final parsed = await backgroundProcessor.processLargeDataset(
      data: await csvDataService.getCachedParsedData('salesMasterCsv'),
      operation: 'filter',
      taskName: 'Processing Sales Data',
      filters: {'status': 'active'},
      chunkSize: 100,
      onProgress: (progress) {
        print('Processing: ${(progress * 100).toInt()}%');
      },
    );
    
    // Optimize for memory
    return MemoryOptimizer.optimizeDataList(
      parsed,
      maxItems: 1000,
      keepOnlyFields: ['id', 'title', 'description', 'date'],
    );
  }
}
```

## 🎉 Results

With these optimizations, your app should:
- ✅ Never hang during data loading
- ✅ Show smooth progress indicators
- ✅ Use memory efficiently
- ✅ Provide better user experience
- ✅ Handle large datasets gracefully

The key is using **isolates for heavy processing**, **progressive loading for UI**, and **memory management** to prevent crashes.