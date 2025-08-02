import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../controllers/google_signin_controller.dart';

// External JS API definitions
@JS()
external JSObject get gapi;

@JS()
external JSObject get google;

@JS('gapi.load')
external void gapiLoad(String api, JSFunction callback);

@JS()
@anonymous
extension type PickerData(JSObject _) implements JSObject {
  external String get action;
  external JSArray<JSObject> get docs;
}

@JS()
@anonymous
extension type FileData(JSObject _) implements JSObject {
  external String get id;
  external String get name;
  external String get mimeType;
  external int? get sizeBytes;
  external String? get url;
}

@JS()
@anonymous
extension type PickerBuilder(JSObject _) implements JSObject {
  external PickerBuilder addView(JSObject view);
  external PickerBuilder enableFeature(JSObject feature);
  external PickerBuilder setOAuthToken(String token);
  external PickerBuilder setDeveloperKey(String key);
  external PickerBuilder setAppId(String appId);
  external PickerBuilder setCallback(JSFunction callback);
  external JSObject build();
}

@JS()
@anonymous
extension type DocsView(JSObject _) implements JSObject {
  external DocsView setMimeTypes(String mimeType);
  external DocsView setParent(String parentId);
}

@JS()
@anonymous
extension type Picker(JSObject _) implements JSObject {
  external void setVisible(bool visible);
}

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
    gapiLoad('picker', (() {
      completer.complete();
    }).toJS);

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
      final pickerCallback = ((PickerData data) {
        final action = data.action;

        if (action == 'picked') {
          final docs = data.docs;
          final selectedFiles = <Map<String, dynamic>>[];

          for (int i = 0; i < docs.length; i++) {
            final doc = docs[i] as FileData;
            selectedFiles.add({
              'id': doc.id,
              'name': doc.name,
              'mimeType': doc.mimeType,
              'sizeBytes': doc.sizeBytes,
              'url': doc.url,
            });
          }

          completer.complete(selectedFiles);
        } else if (action == 'cancel') {
          completer.complete(null);
        }
      }).toJS;

      // Build the picker
      final picker = google['picker'] as JSObject;
      final pickerBuilderConstructor = picker['PickerBuilder'] as JSFunction;
      final pickerBuilder = pickerBuilderConstructor.callAsConstructor() as PickerBuilder;

      // Add Drive view
      final docsViewConstructor = picker['DocsView'] as JSFunction;
      final docsView = docsViewConstructor.callAsConstructor() as DocsView;

      // Set MIME types filter if provided
      if (mimeTypes != null && mimeTypes.isNotEmpty) {
        for (final mimeType in mimeTypes) {
          docsView.setMimeTypes(mimeType);
        }
      }

      // Set folder if provided
      if (folderId != null) {
        docsView.setParent(folderId);
      }

      pickerBuilder.addView(docsView as JSObject);

      // Enable multiselect if requested
      if (multiSelect) {
        final feature = picker['Feature'] as JSObject;
        final multiselectFeature = feature['MULTISELECT_ENABLED'] as JSObject;
        pickerBuilder.enableFeature(multiselectFeature);
      }

      // Set OAuth token
      pickerBuilder.setOAuthToken(accessToken);

      // Set API key
      pickerBuilder.setDeveloperKey(_apiKey);

      // Set app ID
      pickerBuilder.setAppId(_appId);

      // Set callback
      pickerBuilder.setCallback(pickerCallback);

      // Build and show picker
      final picker = pickerBuilder.build() as Picker;
      picker.setVisible(true);

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