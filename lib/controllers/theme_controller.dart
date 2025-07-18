import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart'; // For persistent storage

class ThemeController extends GetxController {
  final _box = GetStorage();
  final _key = 'isDarkMode';

  /// Check if dark mode is currently enabled
  RxBool get isDarkMode => _loadThemeFromBox().obs;

  /// Get the current theme based on the [_isDarkMode] state
  ThemeMode get theme => _loadThemeFromBox() ? ThemeMode.dark : ThemeMode.light;

  /// Load theme preference from GetStorage
  bool _loadThemeFromBox() => _box.read(_key) ?? false; // Default to light mode

  /// Save theme preference to GetStorage
  _saveThemeToBox(bool isDarkMode) => _box.write(_key, isDarkMode);

  /// Toggle between light and dark mode
  void toggleTheme() {
    Get.changeThemeMode(_loadThemeFromBox() ? ThemeMode.light : ThemeMode.dark);
    _saveThemeToBox(!_loadThemeFromBox());
  }

  /// Set a specific theme mode
  void setThemeMode(ThemeMode mode) {
    if (mode == ThemeMode.dark) {
      Get.changeThemeMode(ThemeMode.dark);
      _saveThemeToBox(true);
    } else {
      Get.changeThemeMode(ThemeMode.light);
      _saveThemeToBox(false);
    }
  }

  /// Initialize theme on app start (e.g., in main.dart)
  void initTheme() {
    Get.changeThemeMode(_loadThemeFromBox() ? ThemeMode.dark : ThemeMode.light);
  }
}