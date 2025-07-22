// lib/controllers/theme_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeController extends GetxController {
  final _box = GetStorage();
  final _key = 'isDarkMode';

  // This is where the RxBool instance itself should be stored.
  // It's initialized in onInit.
  late final RxBool _isDarkMode;

  @override
  void onInit() {
    super.onInit();
    // 1. Read the raw boolean value from storage.
    final bool initialDarkModeValue = _box.read<bool>(_key) ?? false;

    // 2. Initialize the _isDarkMode *RxBool* using its constructor.
    // This creates an RxBool instance with the initial value.
    _isDarkMode = RxBool(initialDarkModeValue); // This line is correct for initializing the RxBool

    // 3. Set the theme in GetX based on the loaded preference.
    Get.changeThemeMode(_isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  /// Check if dark mode is currently enabled
  // 🔴 CRITICAL FIX: DO NOT call .obs here. Return the existing RxBool instance.
  RxBool get isDarkMode => _isDarkMode; // Directly return the _isDarkMode RxBool instance.

  /// Get the current theme based on the [_isDarkMode] state
  ThemeMode get theme => _isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  /// Load theme preference from GetStorage (this helper is no longer strictly needed but harmless)
  // bool _loadThemeFromBox() => _box.read(_key) ?? false; // Kept for completeness, but not directly used by getter anymore

  /// Save theme preference to GetStorage
  _saveThemeToBox(bool isDarkMode) => _box.write(_key, isDarkMode);

  /// Toggle between light and dark mode
  void toggleTheme() {
    // Read the current reactive value
    final bool currentValue = _isDarkMode.value;
    final ThemeMode newMode = currentValue ? ThemeMode.light : ThemeMode.dark;

    Get.changeThemeMode(newMode);
    _isDarkMode.value = !currentValue; // Update the RxBool's value
    _saveThemeToBox(_isDarkMode.value); // Save the new state
  }

  /// Set a specific theme mode
  void setThemeMode(ThemeMode mode) {
    bool shouldBeDarkMode = mode == ThemeMode.dark;
    if (_isDarkMode.value != shouldBeDarkMode) { // Only update if different
      Get.changeThemeMode(mode);
      _isDarkMode.value = shouldBeDarkMode;
      _saveThemeToBox(shouldBeDarkMode);
    }
  }

// The initTheme method (if it still exists and is called) should also be removed/cleaned up,
// as the onInit handles the initial theme setting.
// void initTheme() {
//   // This logic is now handled in onInit
// }
}