# Lazy Loading Data Management Guide

## Overview

The app now uses a **Lazy Data Service** that loads CSV data only when needed, instead of pre-downloading everything at startup. This improves:

- **Performance**: Faster app startup
- **Memory Usage**: Only loads data when required
- **Network Efficiency**: Reduces unnecessary downloads
- **User Experience**: Responsive UI without waiting for all data

## Key Changes

### 1. New LazyDataService

The `LazyDataService` provides methods to load specific data types on demand:

```dart
// Load sales-related data only
await _lazyDataService.loadSalesData(forceRefresh: false);

// Load item data only
await _lazyDataService.loadItemData(forceRefresh: false);

// Load account data only
await _lazyDataService.loadAccountData(forceRefresh: false);

// Load customer data only
await _lazyDataService.loadCustomerData(forceRefresh: false);

// Load supplier data only
await _lazyDataService.loadSupplierData(forceRefresh: false);
```

### 2. Updated Controllers

Controllers no longer automatically load data on initialization. Instead, they wait for explicit requests:

#### Before (Pre-loading everything):
```dart
@override
Future<void> onInit() async {
  super.onInit();
  await _loadSales(forceRefresh: true); // Loads all data immediately
}
```

#### After (Lazy loading):
```dart
@override
Future<void> onInit() async {
  super.onInit();
  // Don't load data automatically - wait for explicit request
}

// Public method to load data when needed
Future<void> fetchSales({bool forceRefresh = false}) async {
  return guard(() => _loadSales(forceRefresh: forceRefresh));
}
```

## How to Use in Screens

### 1. Load Data When Screen Opens

```dart
class SalesScreen extends StatefulWidget {
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final SalesController sc = Get.find<SalesController>();

  @override
  void initState() {
    super.initState();
    // Load data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sc.fetchSales();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sales')),
      body: Obx(() {
        if (sc.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (sc.error.value != null) {
          return Center(child: Text('Error: ${sc.error.value}'));
        }

        return ListView.builder(
          itemCount: sc.sales.length,
          itemBuilder: (context, index) {
            final sale = sc.sales[index];
            return ListTile(
              title: Text(sale.accountName),
              subtitle: Text(sale.billNo),
              trailing: Text('₹${sale.amount}'),
            );
          },
        );
      }),
    );
  }
}
```

### 2. Refresh Data with Pull-to-Refresh

```dart
RefreshIndicator(
  onRefresh: () async {
    await sc.fetchSales(forceRefresh: true);
  },
  child: ListView.builder(
    // Your list content
  ),
)
```

### 3. Load Data on Button Press

```dart
ElevatedButton(
  onPressed: () async {
    await sc.fetchSales(forceRefresh: true);
  },
  child: Text('Refresh Sales Data'),
)
```

## Memory Management

The LazyDataService automatically manages memory:

### Automatic Cleanup
- Monitors memory usage
- Clears least-used data when memory is high
- Customer and supplier data are cleared first (less frequently used)

### Manual Cleanup
```dart
// Clear specific data type
_lazyDataService.clearData('sales');

// Clear all data
_lazyDataService.clearAllData();
```

### Memory Monitoring
```dart
// Check current memory usage
double usage = _lazyDataService.getCurrentMemoryUsageMB();

// Listen to memory warnings
Obx(() {
  if (_lazyDataService.isMemoryWarning.value) {
    // Handle memory warning
    return Text('High memory usage detected');
  }
  return Container();
})
```

## Cache Management

### Cache Duration
- Default cache duration: 1 hour
- Data is cached locally and reused if within cache duration
- Force refresh bypasses cache

### Cache Keys
Each data type has its own cache:
- `sales_lastSync`
- `items_lastSync`
- `accounts_lastSync`
- `customers_lastSync`
- `suppliers_lastSync`

## Error Handling

### Network Errors
```dart
try {
  await _lazyDataService.loadSalesData();
} catch (e) {
  // Handle network or download errors
  print('Failed to load sales data: $e');
}
```

### Missing Data
```dart
if (_lazyDataService.salesMasterCsv.value.isEmpty) {
  // Handle missing data
  return Text('No sales data available');
}
```

## Migration Guide

### For Existing Controllers

1. **Add LazyDataService dependency:**
```dart
final LazyDataService _lazyDataService = Get.find<LazyDataService>();
```

2. **Remove automatic loading from onInit:**
```dart
@override
Future<void> onInit() async {
  super.onInit();
  // Remove automatic data loading
}
```

3. **Update data loading methods:**
```dart
// Before
await _csvDataService.loadAllCsvs(forceDownload: forceRefresh);

// After
await _lazyDataService.loadSalesData(forceRefresh: forceRefresh);
```

4. **Update data access:**
```dart
// Before
final data = _csvDataService.salesMasterCsv.value;

// After
final data = _lazyDataService.salesMasterCsv.value;
```

### For New Screens

1. **Inject the controller:**
```dart
final SalesController sc = Get.find<SalesController>();
```

2. **Load data when screen opens:**
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    sc.fetchSales();
  });
}
```

3. **Handle loading states:**
```dart
Obx(() {
  if (sc.isLoading.value) {
    return LoadingWidget();
  }
  // Show your content
})
```

## Best Practices

### 1. Load Data at the Right Time
- Load data when screen opens, not at app startup
- Use pull-to-refresh for user-initiated updates
- Consider loading data in background for frequently accessed screens

### 2. Handle Loading States
- Always show loading indicators
- Provide error messages for failed loads
- Allow users to retry failed operations

### 3. Optimize Memory Usage
- Clear unused data when leaving screens
- Monitor memory usage in development
- Use force refresh sparingly

### 4. Cache Strategy
- Use cache for frequently accessed data
- Force refresh for critical updates
- Consider cache invalidation strategies

## Example: Complete Screen Implementation

```dart
class SalesScreen extends StatefulWidget {
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final SalesController sc = Get.find<SalesController>();

  @override
  void initState() {
    super.initState();
    // Load data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sc.fetchSales();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sales Report'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => sc.fetchSales(forceRefresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => sc.fetchSales(forceRefresh: true),
        child: Obx(() {
          if (sc.isLoading.value) {
            return Center(child: CircularProgressIndicator());
          }

          if (sc.error.value != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${sc.error.value}'),
                  ElevatedButton(
                    onPressed: () => sc.fetchSales(),
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (sc.sales.isEmpty) {
            return Center(child: Text('No sales data available'));
          }

          return ListView.builder(
            itemCount: sc.sales.length,
            itemBuilder: (context, index) {
              final sale = sc.sales[index];
              return ListTile(
                title: Text(sale.accountName),
                subtitle: Text(sale.billNo),
                trailing: Text('₹${sale.amount}'),
              );
            },
          );
        }),
      ),
    );
  }
}
```

This implementation provides a complete example of how to use lazy loading in a screen with proper error handling, loading states, and user interaction.