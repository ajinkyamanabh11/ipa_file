import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'preference_manager.dart';
import '../routes/routes.dart';

/// Test helper for walkthrough functionality
/// This is for development/testing purposes only
class WalkthroughTestHelper {

  /// Show debug info about walkthrough status
  static void showWalkthroughStatus() {
    final hasSeenWalkthrough = PreferenceManager.hasSeenWalkthrough();
    final allPrefs = PreferenceManager.getAllPreferences();

    Get.dialog(
      AlertDialog(
        title: const Text('Walkthrough Debug Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Has seen walkthrough: $hasSeenWalkthrough'),
            const SizedBox(height: 10),
            const Text('All preferences:'),
            Text(allPrefs.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Reset walkthrough and navigate to it
  static Future<void> resetAndShowWalkthrough() async {
    await PreferenceManager.resetWalkthroughSeen();
    Get.offAllNamed(Routes.walkthrough);
  }

  /// Force show walkthrough (without resetting preference)
  static void forceShowWalkthrough() {
    Get.toNamed(Routes.walkthrough);
  }

  /// Create a floating debug button for testing
  static Widget buildDebugButton() {
    return Positioned(
      top: 100,
      right: 20,
      child: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.red.withOpacity(0.7),
        onPressed: () {
          Get.dialog(
            AlertDialog(
              title: const Text('Walkthrough Test'),
              content: const Text('Choose a test action:'),
              actions: [
                TextButton(
                  onPressed: () {
                    Get.back();
                    showWalkthroughStatus();
                  },
                  child: const Text('Show Status'),
                ),
                TextButton(
                  onPressed: () {
                    Get.back();
                    resetAndShowWalkthrough();
                  },
                  child: const Text('Reset & Show'),
                ),
                TextButton(
                  onPressed: () {
                    Get.back();
                    forceShowWalkthrough();
                  },
                  child: const Text('Force Show'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.bug_report, size: 16),
      ),
    );
  }
}

/// Extension to easily add debug functionality to any screen
extension WalkthroughDebug on Widget {
  Widget withWalkthroughDebug() {
    return Stack(
      children: [
        this,
        WalkthroughTestHelper.buildDebugButton(),
      ],
    );
  }
}