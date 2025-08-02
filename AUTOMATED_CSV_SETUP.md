# Automated CSV File Manager

This feature automatically searches and downloads CSV files from the `Softagri_Backups,Financialyear_csv` folder on Google Drive and displays them in your Flutter app.

## Features

✅ **Automatic CSV Discovery**: Automatically searches for all CSV files in the target folder  
✅ **Bulk Download**: Download all CSV files at once with progress tracking  
✅ **Individual Download**: Download specific files as needed  
✅ **Search & Filter**: Search through available CSV files by name  
✅ **File Preview**: View CSV content preview without downloading  
✅ **Beautiful UI**: Modern, gradient-based interface with animations  
✅ **Progress Tracking**: Real-time download progress with statistics  
✅ **Error Handling**: Graceful error handling with retry options  

## How to Use

### 1. Access the Feature
- Open your app and navigate to the home screen
- Tap on **"CSV Manager"** from the dashboard grid
- Or access it from the drawer menu under **"Automated CSV"**

### 2. Search for CSV Files
- The app automatically searches the `Softagri_Backups/[current_year]/softagri_csv` folder
- Use the search bar to filter files by name
- View file information including size and modification date

### 3. Download Files

#### Download All Files
- Tap the **"Download All"** floating action button
- View real-time progress in the header
- See statistics: Total files, Downloaded count, Failed count

#### Download Individual Files
- Tap the download icon next to any file in the "Available Files" tab
- Or tap on a file card and use the "Download" button in the details view

### 4. View Downloaded Files
- Switch to the **"Downloaded"** tab to see all downloaded files
- Tap on any downloaded file to view its full content
- Preview the first few lines directly in the file list

## Technical Implementation

### Files Created:
1. **`lib/services/automated_csv_service.dart`** - Core service for CSV operations
2. **`lib/controllers/automated_csv_controller.dart`** - State management controller
3. **`lib/Screens/automated_csv_screen.dart`** - Beautiful UI screen
4. **Updated bindings and routes** - Integration with app navigation

### Key Components:

#### AutomatedCsvService
- `searchCsvFiles()` - Find all CSV files in target folder
- `downloadAllCsvFiles()` - Bulk download with progress tracking
- `downloadSpecificCsvFile()` - Individual file download
- `searchCsvFilesWithQuery()` - Search/filter functionality

#### AutomatedCsvController
- Reactive state management using GetX
- Progress tracking and error handling
- Statistics calculation
- File content management

#### CsvFileInfo Model
- Represents CSV file metadata
- Tracks download status and content
- Immutable data structure with copyWith support

## UI Features

### Modern Design
- **Gradient Background**: Purple gradient with professional look
- **Card-based Layout**: Clean file cards with rounded corners
- **Tab Navigation**: Separate tabs for Available and Downloaded files
- **Statistics Cards**: Real-time stats with icons and colors
- **Progress Indicators**: Linear progress bar and loading animations

### Interactive Elements
- **Search Bar**: Real-time search with clear functionality
- **Pull-to-Refresh**: Refresh file list by pulling down
- **Bottom Sheet Details**: Full file content viewer
- **Action Buttons**: Download, retry, and navigation actions

### Error Handling
- **User-friendly Errors**: Clear error messages with retry options
- **Graceful Failures**: App continues working even if some files fail
- **Loading States**: Proper loading indicators during operations

## Dependencies Used

The feature leverages existing dependencies in your `pubspec.yaml`:
- `get: ^4.7.2` - State management and navigation
- `googleapis: ^14.0.0` - Google Drive API integration
- `file_picker: ^10.2.1` - File operations
- `intl: ^0.20.2` - Date formatting
- `http: ^1.4.0` - HTTP requests

## Configuration

The feature automatically uses your existing Google Drive configuration:
- Uses the same Google Sign-in setup
- Leverages existing `SoftAgriPath` configuration
- Follows the same folder structure: `SoftAgri_Backups/[year]/softagri_csv`
- Integrates with existing `GoogleDriveService`

## Folder Structure

```
Softagri_Backups/
└── [Financial Year - e.g., 20252026]/
    └── softagri_csv/
        ├── file1.csv
        ├── file2.csv
        └── ...
```

The system automatically determines the correct financial year folder based on your `FinancialYear.csv` configuration.

## Navigation

The feature is accessible from multiple places:
1. **Home Dashboard**: "CSV Manager" tile
2. **Drawer Menu**: "Automated CSV" option
3. **Direct Route**: `/automated-csv`

## Best Practices

1. **Network Connection**: Ensure stable internet connection for downloads
2. **Storage Space**: Check device storage before bulk downloads
3. **File Sizes**: Large CSV files are handled with memory-efficient streaming
4. **Error Recovery**: Use the retry button if downloads fail
5. **Search Usage**: Use search to find specific files quickly

## Troubleshooting

### Common Issues:
1. **No files found**: Check if CSV files exist in the target folder
2. **Download fails**: Verify internet connection and Google Drive permissions
3. **Search not working**: Clear search and try again
4. **Loading forever**: Pull down to refresh or restart the app

### File Requirements:
- Files must have `.csv` extension
- Files must be in the correct folder structure
- Google Drive access must be properly configured

This automated CSV manager streamlines your workflow by eliminating manual file picking and providing a dedicated interface for CSV file management.