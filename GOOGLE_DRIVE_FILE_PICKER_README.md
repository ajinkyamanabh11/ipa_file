# Mobile-Compatible Google Drive File Picker

This implementation replaces the web-only Google Picker API with a mobile-compatible solution using the Google Drive API directly.

## What Changed

The original code used `dart:js_interop` and `dart:js_interop_unsafe` which are web-only libraries. This new implementation:

1. **Removed web-only dependencies**: No more `dart:js_interop` or `dart:js_interop_unsafe`
2. **Enhanced existing service**: Extended `GoogleDriveService` with file picker functionality
3. **Added mobile UI**: Created a proper Flutter dialog for file selection
4. **Maintained compatibility**: Same API surface as the original picker service

## Features

- ✅ **Mobile & Web Compatible**: Works on iOS, Android, and Web
- ✅ **File Filtering**: Support for MIME type filtering
- ✅ **Multi-select**: Choose single or multiple files
- ✅ **Rich UI**: Beautiful file browser with icons and metadata
- ✅ **Download Support**: Download files directly from Drive
- ✅ **CSV Specialization**: Built-in CSV file picker
- ✅ **Folder Support**: Browse files in specific folders

## Usage

### Basic File Picking

```dart
// Get the service (already registered in InitialBindings)
final driveService = Get.find<GoogleDriveService>();

// Pick a single file
final files = await driveService.pickFiles(
  multiSelect: false,
  title: 'Select a File',
);

// Pick multiple files
final files = await driveService.pickFiles(
  multiSelect: true,
  title: 'Select Files',
);
```

### CSV Files

```dart
// Pick CSV files specifically
final csvFiles = await driveService.pickCsvFiles(multiSelect: true);
```

### Filter by MIME Type

```dart
// Pick only images
final images = await driveService.pickFiles(
  multiSelect: true,
  mimeTypes: [
    'image/jpeg',
    'image/png',
    'image/gif',
  ],
  title: 'Select Images',
);

// Pick documents
final docs = await driveService.pickFiles(
  mimeTypes: [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ],
);
```

### Browse Specific Folder

```dart
final folderFiles = await driveService.pickFilesFromFolder(
  'your-folder-id',
  multiSelect: true,
  mimeTypes: ['text/csv'],
);
```

### Download Files

```dart
// Download as text (for CSV/text files)
final content = await driveService.downloadCsv(fileId);

// Download as bytes (for any file)
final bytes = await driveService.downloadFileAsBytes(fileId);
```

### Get File Metadata

```dart
final metadata = await driveService.getFileMetadata(fileId);
print('File: ${metadata?.name}');
print('Size: ${metadata?.sizeBytes} bytes');
print('Type: ${metadata?.mimeType}');
```

## Demo Widget

Use the `GoogleDriveFilePickerWidget` for a complete demo:

```dart
import 'package:flutter/material.dart';
import 'package:demo/widget/google_drive_file_picker_widget.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const GoogleDriveFilePickerWidget();
  }
}
```

## Requirements

### Permissions

Make sure your Google Sign-In includes the necessary Drive scopes:

```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'https://www.googleapis.com/auth/drive.file',        // Required for file picker
    'https://www.googleapis.com/auth/drive.readonly',
  ],
);
```

### Dependencies

The following packages are required (already in your `pubspec.yaml`):

- `google_sign_in: ^6.2.1`
- `googleapis: ^14.0.0`
- `googleapis_auth: ^2.0.0`
- `http: ^1.4.0`
- `get: ^4.7.2`

### Google Console Setup

1. Enable the Google Drive API in your Google Cloud Console
2. Configure OAuth 2.0 credentials for your app
3. Add the necessary scopes to your OAuth consent screen

## API Reference

### GoogleDriveService Methods

#### File Listing
- `listFiles({mimeTypes, folderId, nameContains, pageSize, pageToken})` - List files with filters

#### File Picking
- `pickFiles({multiSelect, mimeTypes, folderId, title})` - Show file picker dialog
- `pickCsvFiles({multiSelect})` - Pick CSV files specifically
- `pickFilesFromFolder(folderId, {multiSelect, mimeTypes})` - Pick from specific folder

#### File Operations
- `downloadFileAsBytes(fileId)` - Download file as byte array
- `downloadCsv(fileId)` - Download and parse as text (existing method)
- `getFileMetadata(fileId)` - Get file information

### DriveFile Class

```dart
class DriveFile {
  final String id;
  final String name;
  final String mimeType;
  final int? sizeBytes;
  final List<String>? parents;
  final DateTime? createdTime;
  final DateTime? modifiedTime;
  final String? webViewLink;
  final String? webContentLink;
  final String? thumbnailLink;
}
```

## Migration Guide

If you were using the old `GooglePickerService`, replace:

```dart
// OLD (web-only)
final picker = Get.find<GooglePickerService>();
final files = await picker.pickFiles();

// NEW (mobile-compatible)
final driveService = Get.find<GoogleDriveService>();
final files = await driveService.pickFiles();
```

The API is very similar, so migration should be straightforward!

## Troubleshooting

### "User must be signed in" Error
Make sure the user is signed in with Google before calling any file picker methods.

### No Files Found
- Check that the user has files in their Google Drive
- Verify MIME type filters are not too restrictive
- Ensure the folder ID is correct (if using folder filtering)

### Download Errors
- Verify the file ID is correct
- Ensure the user has permission to access the file
- Check network connectivity

### Permission Errors
- Verify Drive API is enabled in Google Console
- Check OAuth scopes include `drive.file` or `drive.readonly`
- Make sure consent screen includes necessary scopes