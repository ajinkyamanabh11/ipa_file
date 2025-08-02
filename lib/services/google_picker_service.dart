import 'dart:async';
import 'dart:js' as js;
import 'package:get/get.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../controllers/google_signin_controller.dart';

class GooglePickerService extends GetxService {
  final _google = Get.find<GoogleSignInController>();

  // Your Google API key - replace with your actual API key
  static const String _apiKey = 'YOUR_API_KEY_HERE';
  static const String _appId = 'YOUR_APP_ID_HERE';

  static const String _scope = 'https://www.googleapis.com/auth/drive.file';

  bool _isPickerLoaded = false;

  Future<void> loadPicker() async {
    if (!kIsWeb) {
      throw Exception('Google Picker is only available on web platform');
    }

    if (_isPickerLoaded) return;

    try {
      // Load the Picker API
      await _loadGoogleAPIs();
      _isPickerLoaded = true;
    } catch (e) {
      throw Exception('Failed to load Google Picker API: $e');
    }
  }

  Future<void> _loadGoogleAPIs() async {
    final completer = Completer<void>();

    // Load Google APIs
    js.context.callMethod('gapi.load', ['picker', js.allowInterop((result) {
      completer.complete();
    })]);

    return completer.future;
  }

  /// Show file picker and return selected file information
  Future<List<Map<String, dynamic>>?> pickFiles({
    bool multiSelect = false,
    List<String>? mimeTypes,
    String? folderId,
  }) async {
    if (!kIsWeb) {
      throw Exception('Google Picker is only available on web platform');
    }

    if (!_isPickerLoaded) {
      await loadPicker();
    }

    final authHeaders = await _google.getAuthHeaders();
    if (authHeaders == null) {
      throw Exception('User must be signed in to use file picker');
    }

    final accessToken = authHeaders['Authorization']?.replaceFirst('Bearer ', '');
    if (accessToken == null) {
      throw Exception('No access token available');
    }

    return _showPicker(
      accessToken: accessToken,
      multiSelect: multiSelect,
      mimeTypes: mimeTypes,
      folderId: folderId,
    );
  }

  Future<List<Map<String, dynamic>>?> _showPicker({
    required String accessToken,
    bool multiSelect = false,
    List<String>? mimeTypes,
    String? folderId,
  }) async {
    final completer = Completer<List<Map<String, dynamic>>?>();

    try {
      // Create picker callback
      final pickerCallback = js.allowInterop((data) {
        final action = data['action'];

        if (action == 'picked') {
          final docs = data['docs'] as List;
          final selectedFiles = docs.map((doc) => {
            'id': doc['id'],
            'name': doc['name'],
            'mimeType': doc['mimeType'],
            'sizeBytes': doc['sizeBytes'],
            'url': doc['url'],
          }).toList();

          completer.complete(selectedFiles);
        } else if (action == 'cancel') {
          completer.complete(null);
        }
      });

      // Build the picker
      final pickerBuilder = js.context['google']['picker']['PickerBuilder']();

      // Add Drive view
      final docsView = js.context['google']['picker']['DocsView']();

      // Set MIME types filter if provided
      if (mimeTypes != null && mimeTypes.isNotEmpty) {
        for (final mimeType in mimeTypes) {
          docsView.callMethod('setMimeTypes', [mimeType]);
        }
      }

      // Set folder if provided
      if (folderId != null) {
        docsView.callMethod('setParent', [folderId]);
      }

      pickerBuilder.callMethod('addView', [docsView]);

      // Enable multiselect if requested
      if (multiSelect) {
        pickerBuilder.callMethod('enableFeature', [
          js.context['google']['picker']['Feature']['MULTISELECT_ENABLED']
        ]);
      }

      // Set OAuth token
      pickerBuilder.callMethod('setOAuthToken', [accessToken]);

      // Set API key
      pickerBuilder.callMethod('setDeveloperKey', [_apiKey]);

      // Set app ID
      pickerBuilder.callMethod('setAppId', [_appId]);

      // Set callback
      pickerBuilder.callMethod('setCallback', [pickerCallback]);

      // Build and show picker
      final picker = pickerBuilder.callMethod('build');
      picker.callMethod('setVisible', [true]);

    } catch (e) {
      completer.completeError(e);
    }

    return completer.future;
  }

  /// Pick CSV files specifically
  Future<List<Map<String, dynamic>>?> pickCsvFiles({bool multiSelect = false}) async {
    return pickFiles(
      multiSelect: multiSelect,
      mimeTypes: [
        'text/csv',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ],
    );
  }

  /// Pick files from a specific folder
  Future<List<Map<String, dynamic>>?> pickFilesFromFolder(
      String folderId, {
        bool multiSelect = false,
        List<String>? mimeTypes,
      }) async {
    return pickFiles(
      multiSelect: multiSelect,
      mimeTypes: mimeTypes,
      folderId: folderId,
    );
  }
}