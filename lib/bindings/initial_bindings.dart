// lib/initial_bindings.dart
// ... (existing imports)

import 'package:demo/controllers/stock_report_controller.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart';

import '../controllers/customerLedger_Controller.dart';
import '../controllers/google_signin_controller.dart';
import '../controllers/item_type_controller.dart';
import '../controllers/sales_controller.dart';
import '../controllers/theme_controller.dart';
import '../services/CsvDataServices.dart';
import '../services/google_drive_service.dart';
// NEW IMPORT

class InitialBindings {
  static bool _done = false;

  /// Call once from main.dart to register every global singleton.
  static Future<void> ensure() async {
    if (_done) return;
    _done = true;

    try {
      // Initialize GetStorage first
      await GetStorage.init().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('GetStorage initialization timeout');
        },
      );

      // 1️⃣ Google Sign‑in controller (never disposed) - non-blocking
      Get.put<GoogleSignInController>(GoogleSignInController(), permanent: true);

      // 2️⃣ Initialize other essential services in parallel
      await Future.wait([
        _initializeGoogleDriveService(),
        _initializeCsvDataService(),
        _initializeControllers(),
      ], eagerError: false); // Continue even if some services fail

    } catch (e) {
      debugPrint('InitialBindings error: $e');
      // Continue app execution even if some services fail
    }
  }

  // Separate method for Google Drive service with timeout and error handling
  static Future<void> _initializeGoogleDriveService() async {
    try {
      await Get.putAsync<GoogleDriveService>(
            () => GoogleDriveService.init().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('GoogleDriveService initialization timeout');
            return GoogleDriveService(); // Return basic instance
          },
        ),
        permanent: true,
      );
    } catch (e) {
      debugPrint('GoogleDriveService initialization failed: $e');
      // Put a basic instance so app doesn't crash
      Get.put<GoogleDriveService>(GoogleDriveService(), permanent: true);
    }
  }

  // Separate method for CSV data service
  static Future<void> _initializeCsvDataService() async {
    try {
      Get.put<CsvDataService>(CsvDataService(), permanent: true);
    } catch (e) {
      debugPrint('CsvDataService initialization failed: $e');
    }
  }

  // Initialize other controllers
  static Future<void> _initializeControllers() async {
    try {
      // Core app‑wide controllers
      Get.put<CustomerLedgerController>(
        CustomerLedgerController(),
        permanent: true,
      );

      // Item / stock logic can be recreated when needed (fenix)
      Get.lazyPut<ItemTypeController>(() => ItemTypeController(), fenix: true);
      Get.lazyPut<StockReportController>(() => StockReportController(), fenix: true);
      Get.lazyPut<SalesController>(() => SalesController(), fenix: true);
    } catch (e) {
      debugPrint('Controllers initialization failed: $e');
    }
  }
}