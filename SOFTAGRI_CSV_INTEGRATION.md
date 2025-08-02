# Softagri CSV Integration Guide

This integration allows you to automatically download CSV files from your Google Drive's Softagri_Backups folder using Google Sign-In and Google Drive APIs.

## ✅ Features Implemented

- **🔐 Google Sign-In with drive.file scope** - Secure authentication
- **📁 Automatic folder detection** - Finds `Softagri_Backups/20252026/softagri_csv`
- **📥 Automated CSV downloads** - Downloads all required files
- **📊 CSV parsing and data access** - Easy data manipulation
- **💾 Local storage** - Optional local file caching
- **📈 Progress tracking** - Real-time download progress
- **🔍 Data validation** - Ensures data integrity

## 📂 Expected Folder Structure

```
📁 My Drive
└── Softagri_Backups
    └── 20252026
        └── softagri_csv
            ├── SalesInvoiceMaster.csv
            ├── SalesInvoiceDetails.csv
            ├── ItemMaster.csv
            ├── ItemDetail.csv
            ├── AccountMaster.csv
            ├── AllAccounts.csv
            ├── CustomerInformation.csv
            ├── SupplierInformation.csv
            └── selfinformation.csv
```

## 🚀 Quick Start

### 1. Basic Usage

```dart
import 'package:get/get.dart';
import 'lib/services/softagri_csv_service.dart';
import 'lib/controllers/softagri_csv_controller.dart';

// Get the service instance
final csvService = Get.find<SoftagriCsvService>();

// Or use the controller for UI interactions
final controller = Get.put(SoftagriCsvController());

// Check if user has access to the folder
bool hasAccess = await csvService.checkFolderAccess();

// Download all CSV files
if (hasAccess) {
  final results = await csvService.downloadAllCsvFiles();
  print('Downloaded ${results.length} files');
}
```

### 2. Download Specific Files

```dart
// Download a specific CSV file
String? content = await csvService.downloadSpecificCsv('SalesInvoiceMaster.csv');

if (content != null) {
  print('Downloaded SalesInvoiceMaster.csv successfully');
}
```

### 3. Progress Tracking

```dart
// Download with progress tracking
await csvService.downloadAllCsvFiles(
  onProgress: (fileName, progress) {
    print('$fileName: ${(progress * 100).toStringAsFixed(0)}%');
  },
  onFileComplete: (fileName, content) {
    print('✅ Completed: $fileName');
  },
);
```

## 📊 Working with Downloaded Data

### Using SoftagriCsvHelper

```dart
import 'lib/util/softagri_csv_helper.dart';

// Get sales data
final salesData = SoftagriCsvHelper.getSalesData();
if (salesData != null) {
  print('Total invoices: ${salesData['totalInvoices']}');
  print('Total line items: ${salesData['totalLineItems']}');
}

// Get inventory data
final inventory = SoftagriCsvHelper.getInventoryData();
print('Total items: ${inventory?['totalItems']}');

// Search for items
final searchResults = SoftagriCsvHelper.searchItems('apple');
print('Found ${searchResults.length} items matching "apple"');

// Get customers
final customers = SoftagriCsvHelper.getCustomers();
print('Total customers: ${customers?.length}');

// Calculate total sales
double totalSales = SoftagriCsvHelper.calculateTotalSales();
print('Total sales amount: \$${totalSales.toStringAsFixed(2)}');
```

### Direct Service Access

```dart
// Get parsed CSV data directly
List<Map<String, dynamic>>? salesMaster = csvService.getParsedCsv('SalesInvoiceMaster.csv');

if (salesMaster != null) {
  for (final invoice in salesMaster) {
    print('Invoice ID: ${invoice['InvoiceId']}');
    print('Customer: ${invoice['CustomerName']}');
    print('Amount: ${invoice['TotalAmount']}');
  }
}
```

## 🎨 UI Integration

### Using the Demo Screen

```dart
import 'lib/screens/softagri_csv_demo_screen.dart';

// Navigate to the demo screen
Get.to(() => const SoftagriCsvDemoScreen());
```

### Custom UI with Controller

```dart
class MyCustomScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SoftagriCsvController());
    
    return Scaffold(
      appBar: AppBar(title: Text('My CSV Data')),
      body: Obx(() => Column(
        children: [
          // Status display
          Text(controller.statusMessage.value),
          
          // Download button
          ElevatedButton(
            onPressed: controller.hasAccess.value 
              ? () => controller.downloadAllFiles()
              : null,
            child: Text('Download CSV Files'),
          ),
          
          // Progress indicators
          ...controller.downloadProgress.entries.map((entry) =>
            LinearProgressIndicator(value: entry.value)
          ),
          
          // Downloaded files list
          ...controller.downloadedFiles.keys.map((fileName) =>
            ListTile(
              title: Text(fileName),
              trailing: Icon(Icons.check_circle, color: Colors.green),
            )
          ),
        ],
      )),
    );
  }
}
```

## 🔧 Configuration

The service is automatically registered in `InitialBindings` and requires:

1. **Google Sign-In** - Already configured with `drive.file` scope
2. **Internet connection** - For Google Drive API access
3. **User permissions** - User must have access to the Softagri_Backups folder

## 📱 Testing

### Manual Testing

1. Open the demo screen: `SoftagriCsvDemoScreen`
2. Sign in with Google (if not already signed in)
3. Click "Check Access" to verify folder access
4. Click "Download All" to download all CSV files
5. Monitor progress and view results

### Programmatic Testing

```dart
// Test folder access
test('Should have access to Softagri folder', () async {
  final csvService = Get.find<SoftagriCsvService>();
  final hasAccess = await csvService.checkFolderAccess();
  expect(hasAccess, isTrue);
});

// Test file download
test('Should download specific CSV file', () async {
  final csvService = Get.find<SoftagriCsvService>();
  final content = await csvService.downloadSpecificCsv('ItemMaster.csv');
  expect(content, isNotNull);
});
```

## 🐛 Troubleshooting

### Common Issues

1. **"Folder not found" error**
   - Ensure the exact folder structure exists in Google Drive
   - Check folder names are exactly: `Softagri_Backups/20252026/softagri_csv`
   - Verify user has access to these folders

2. **"Google Sign-In required" error**
   - User needs to sign in with Google first
   - Check if `drive.file` scope is properly configured

3. **File download fails**
   - Check internet connection
   - Verify file exists in the expected folder
   - Ensure file isn't corrupted or too large (>50MB limit)

4. **Empty or null data**
   - Check if CSV files have proper headers
   - Verify CSV format is valid
   - Ensure files aren't empty

### Debug Information

```dart
// Get download statistics
final stats = csvService.getDownloadStats();
print('Success rate: ${stats['successRate']}%');
print('Downloaded files: ${stats['downloadedFileNames']}');

// Check data validation
final validation = SoftagriCsvHelper.getDataValidation();
print('Data is valid: ${validation['isValid']}');
print('Errors: ${validation['errors']}');
print('Warnings: ${validation['warnings']}');

// Get missing files
final missing = SoftagriCsvHelper.getMissingFiles();
print('Missing files: $missing');
```

## 🔄 Advanced Usage

### Custom Folder Paths

If you need to modify the folder structure, update the path in `SoftagriCsvService`:

```dart
// In findSoftagriCsvFolderId() method
final folderId = await _driveService.folderId([
  'YourCustomFolder',     // Change this
  'YourYear',            // Change this
  'YourCsvFolder'        // Change this
]);
```

### Adding New CSV Files

To include additional CSV files, update the `requiredCsvFiles` list:

```dart
// In SoftagriCsvService
static const List<String> requiredCsvFiles = [
  'SalesInvoiceMaster.csv',
  'SalesInvoiceDetails.csv',
  // ... existing files ...
  'YourNewFile.csv',     // Add new files here
];
```

### Local Storage Management

```dart
// Save all files locally
final savedPaths = await csvService.saveAllCsvsToLocal();
print('Files saved to: $savedPaths');

// Clear local storage (optional)
// You would need to implement this in the service
```

## 📈 Performance Notes

- Files are downloaded with a 1MB chunk size for memory efficiency
- Maximum file size limit is 50MB per file
- Small delay (500ms) between file downloads to avoid API rate limits
- Local caching reduces redundant downloads

## 🔐 Security

- Uses OAuth 2.0 with `drive.file` scope (limited access)
- No full Google Drive access required
- Files are only accessible to the authenticated user
- Data is stored in memory and optionally cached locally

## 📞 Support

If you encounter issues:

1. Check the console logs for detailed error messages
2. Verify your Google Drive folder structure
3. Ensure proper internet connectivity
4. Check Google API quotas and limits

The integration follows Google Drive API best practices and includes proper error handling and progress tracking.