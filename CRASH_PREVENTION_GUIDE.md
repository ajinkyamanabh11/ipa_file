# Crash Prevention Guide for Large Datasets

This guide explains the improvements made to prevent crashes when handling large datasets in your Flutter application.

## 🚨 Problems Identified

### 1. Memory Issues
- **Problem**: Loading entire CSV files into memory simultaneously
- **Location**: `CsvDataService.loadAllCsvs()` using `Future.wait()`
- **Impact**: OutOfMemory crashes with large datasets

### 2. Inefficient Data Processing
- **Problem**: Processing all data at once without pagination
- **Locations**: Stock, Sales, and Profit report controllers
- **Impact**: UI freezing and memory exhaustion

### 3. No Memory Management
- **Problem**: No monitoring or cleanup of memory usage
- **Impact**: Gradual memory leaks leading to crashes

## ✅ Solutions Implemented

### 1. Memory-Efficient CSV Loading
**File**: `lib/services/CsvDataServices.dart`

- **Priority-based loading**: Essential CSVs loaded first
- **Memory monitoring**: Tracks usage and skips non-essential files
- **Sequential downloads**: Prevents simultaneous large downloads
- **Automatic cleanup**: Clears non-essential data when memory is high

```dart
// Memory management constants
static const int _maxMemoryUsageMB = 100;
static const int _chunkSize = 1000;

// Priority-based CSV configuration
final List<Map<String, dynamic>> csvConfigs = [
  // Essential CSVs (always load)
  {'key': _salesMasterCacheKey, 'filename': 'SalesInvoiceMaster.csv', 'priority': 1},
  // Optional CSVs (load only if memory allows)
  {'key': _accountMasterCacheKey, 'filename': 'AccountMaster.csv', 'priority': 2},
];
```

### 2. Pagination and Chunked Processing
**Files**: 
- `lib/controllers/stock_report_controller.dart`
- `lib/controllers/profit_report_controller.dart`

- **Pagination**: Display 50 items per page instead of all data
- **Chunked processing**: Process large datasets in 500-item chunks
- **Progress tracking**: Show processing progress for large datasets
- **Memory detection**: Automatically switch to chunked mode for large files

```dart
// Pagination variables
var currentPage = 0.obs;
var itemsPerPage = 50.obs;
var totalItems = 0.obs;
var totalPages = 0.obs;

// Memory management
var isProcessingLargeDataset = false.obs;
var processingProgress = 0.0.obs;
```

### 3. Streaming File Downloads
**File**: `lib/services/google_drive_service.dart`

- **File size limits**: 50MB maximum per file
- **Streaming downloads**: Process data in chunks instead of loading all at once
- **Memory-efficient parsing**: Use `Uint8List` for better memory management
- **Progress reporting**: Optional progress callbacks for large downloads

```dart
// Memory management constants
static const int _maxChunkSize = 1024 * 1024; // 1MB chunks
static const int _maxFileSize = 50 * 1024 * 1024; // 50MB max

// Streaming download with memory management
Future<String> downloadCsv(String id) async {
  // Check file size first
  final fileSize = int.tryParse(fileMetadata.size ?? '0') ?? 0;
  if (fileSize > _maxFileSize) {
    throw Exception('File too large: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB');
  }
  // Use streaming approach
  return await _streamToString(media.stream, fileSize);
}
```

### 4. Memory Monitoring System
**File**: `lib/util/memory_monitor.dart`

- **Real-time monitoring**: Tracks memory usage every 5 seconds
- **Automatic cleanup**: Triggers cleanup at warning thresholds
- **Emergency mode**: Aggressive cleanup for critical memory situations
- **Trend analysis**: Monitors memory usage patterns

```dart
static const int _warningThresholdMB = 100;
static const int _criticalThresholdMB = 150;

// Automatic cleanup triggers
void _updateMemoryStatus(double memoryMB) {
  if (memoryMB >= _criticalThresholdMB) {
    _triggerEmergencyCleanup();
  } else if (memoryMB >= _warningThresholdMB) {
    _triggerMemoryCleanup();
  }
}
```

## 📊 Usage Instructions

### 1. Accessing Pagination Controls

**Stock Report Controller**:
```dart
final controller = Get.find<StockReportController>();

// Navigation
controller.nextPage();
controller.previousPage();
controller.goToPage(2);

// Configuration
controller.setItemsPerPage(25);

// Information
String info = controller.getPaginationInfo(); // "Showing 1-50 of 1000 items"
bool hasNext = controller.hasNextPage;
bool hasPrev = controller.hasPreviousPage;
```

**Profit Report Controller**:
```dart
final controller = Get.find<ProfitReportController>();

// Same methods available
controller.nextPage();
controller.setItemsPerPage(100);
String info = controller.getPaginationInfo();
```

### 2. Memory Monitoring

```dart
final memoryMonitor = Get.find<MemoryMonitor>();

// Get current status
Map<String, dynamic> stats = memoryMonitor.getMemoryStats();
print('Memory usage: ${stats['current']}MB');
print('Status: ${memoryMonitor.getRecommendedAction()}');

// Check if safe for operations
if (memoryMonitor.isSafeForLargeOperations()) {
  // Proceed with memory-intensive task
}

// Force memory check
memoryMonitor.forceMemoryCheck();
```

### 3. CSV Data Service

```dart
final csvService = Get.find<CsvDataService>();

// Check memory usage
double usage = csvService.getCurrentMemoryUsageMB();

// Force refresh with memory management
await csvService.loadAllCsvs(forceDownload: true);

// Monitor memory warnings
csvService.isMemoryWarning.listen((isWarning) {
  if (isWarning) {
    print('High memory usage detected!');
  }
});
```

## 🔧 Configuration Options

### Memory Thresholds
Adjust in `lib/services/CsvDataServices.dart`:
```dart
static const int _maxMemoryUsageMB = 100; // Warning threshold
static const int _chunkSize = 1000; // Processing chunk size
```

### File Size Limits
Adjust in `lib/services/google_drive_service.dart`:
```dart
static const int _maxFileSize = 50 * 1024 * 1024; // 50MB max
```

### Pagination Settings
Adjust in controllers:
```dart
var itemsPerPage = 50.obs; // Items per page
const int chunkSize = 500; // Processing chunk size
```

## 🚀 Performance Tips

### 1. For Large Datasets (>10,000 rows)
- Use pagination with 25-50 items per page
- Enable chunked processing
- Monitor memory usage regularly
- Clear search filters when not needed

### 2. For Memory-Constrained Devices
- Reduce `itemsPerPage` to 25
- Lower memory thresholds to 75MB
- Enable more aggressive cleanup

### 3. For Better User Experience
- Show processing progress for large operations
- Implement loading states
- Provide feedback on memory status

## 🐛 Troubleshooting

### App Still Crashes?
1. **Check file sizes**: Ensure CSV files are under 50MB
2. **Monitor memory**: Use memory monitor to identify issues
3. **Reduce pagination**: Lower items per page
4. **Clear cache**: Force refresh CSV data

### Memory Usage Too High?
1. **Clear non-essential data**: Use memory cleanup
2. **Reduce chunk sizes**: Lower processing batch sizes
3. **Enable aggressive cleanup**: Lower memory thresholds

### Slow Performance?
1. **Check chunked processing**: Ensure large datasets use chunking
2. **Optimize search**: Clear filters when not needed
3. **Monitor trends**: Use memory trend analysis

## 📈 Monitoring Dashboard

The app now includes built-in monitoring:

- **Memory usage**: Real-time tracking
- **Processing progress**: For large operations
- **Pagination info**: Current page and total items
- **Performance trends**: Memory usage patterns

Access through:
```dart
// Memory stats
final memoryStats = Get.find<MemoryMonitor>().getMemoryStats();

// CSV service stats
final csvStats = Get.find<CsvDataService>().getCurrentMemoryUsageMB();

// Controller pagination info
final stockInfo = Get.find<StockReportController>().getPaginationInfo();
```

## 🔄 Regular Maintenance

### Daily
- Monitor memory usage trends
- Check for memory warnings in logs
- Clear unnecessary cached data

### Weekly
- Review file sizes for growth
- Analyze crash reports (if any)
- Update memory thresholds if needed

### Monthly
- Performance testing with large datasets
- Review and optimize chunk sizes
- Update documentation

---

**Note**: These improvements significantly reduce crash likelihood, but extremely large datasets (>100MB) may still require additional optimization or server-side processing.