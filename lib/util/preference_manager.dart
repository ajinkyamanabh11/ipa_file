import 'package:get_storage/get_storage.dart';

class PreferenceManager {
  static const String _walkthroughSeenKey = 'walkthrough_seen';

  static final GetStorage _storage = GetStorage();

  /// Check if user has seen the walkthrough
  static bool hasSeenWalkthrough() {
    return _storage.read(_walkthroughSeenKey) ?? false;
  }

  /// Mark walkthrough as seen
  static Future<void> setWalkthroughSeen() async {
    await _storage.write(_walkthroughSeenKey, true);
  }

  /// Reset walkthrough seen status (for testing purposes)
  static Future<void> resetWalkthroughSeen() async {
    await _storage.remove(_walkthroughSeenKey);
  }

  /// Debug method to check all stored preferences
  static Map<String, dynamic> getAllPreferences() {
    return _storage.getKeys().fold<Map<String, dynamic>>({}, (map, key) {
      map[key] = _storage.read(key);
      return map;
    });
  }
}