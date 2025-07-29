// lib/initial_bindings.dart
// ... (existing imports)

import 'package:demo/controllers/stock_report_controller.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get_storage/get_storage.dart';

import '../controllers/customerLedger_Controller.dart';
import '../controllers/google_signin_controller.dart';
import '../controllers/item_type_controller.dart';
import '../controllers/sales_controller.dart';
import '../controllers/theme_controller.dart';
import '../services/CsvDataServices.dart';
import '../services/google_drive_service.dart';
import '../services/data_loading_service.dart';
import '../util/memory_monitor.dart'; // NEW IMPORT

class InitialBindings {
  static bool _done = false;

  /// Call once from main.dart to register every global singleton.
  static Future<void> ensure() async {
    if (_done) return;
    _done = true;

    // Initialize GetStorage before any controller that uses it
    await GetStorage.init(); // IMPORTANT: Initialize GetStorage here

    // 🔴 NEW: Memory Monitor (initialize first for early monitoring)
    Get.put<MemoryMonitor>(MemoryMonitor(), permanent: true);

    // 1️⃣ Google Sign‑in controller (never disposed)
    Get.put<GoogleSignInController>(GoogleSignInController(), permanent: true);

    // 2️⃣ Google Drive helper (async init; never disposed)
    await Get.putAsync<GoogleDriveService>(
          () => GoogleDriveService.init(),
      permanent: true,
    );

    // 🔴 NEW: Centralized CSV Data Service
    Get.put<CsvDataService>(CsvDataService(), permanent: true);

    // 🔴 NEW: Data Loading Service (coordinates all data loading)
    Get.put<DataLoadingService>(DataLoadingService(), permanent: true);

    // 🔴 NEW: Theme Controller (permanent singleton)
    Get.put<ThemeController>(ThemeController(), permanent: true); // ADD THIS

    // 3️⃣ Core app‑wide controllers
    Get.put<CustomerLedgerController>(
      CustomerLedgerController(),
      permanent: true,
    );

    // Item / stock logic can be recreated when needed (fenix)
    Get.lazyPut<ItemTypeController>(() => ItemTypeController(), fenix: true);

    // Batch‑wise profit (permanent singleton)
    // Get.lazyPut<ProfitReportController>(() => ProfitReportController(), fenix: true);
    // (If you want it permanent, change to Get.put)
    // If ProfitReportController is used frequently and needs to be alive, permanent is fine.
    // If it's only for a specific screen and can be disposed, fenix is fine.
    // For now, let's assume it's okay as you had it or as lazyPut.

    Get.lazyPut<StockReportController>(() => StockReportController(), fenix: true);
    Get.lazyPut<SalesController>(() => SalesController(), fenix: true);
  }
}