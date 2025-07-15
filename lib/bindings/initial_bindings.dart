import 'package:get/get.dart';

import '../controllers/google_signin_controller.dart';
import '../services/google_drive_service.dart';
import '../controllers/item_type_controller.dart';
import '../controllers/customerLedger_Controller.dart';

class InitialBindings {
  static bool _done = false;

  /// Call once from main.dart to register every global singleton.
  static Future<void> ensure() async {
    if (_done) return;
    _done = true;

    // 1️⃣  Google Sign‑in controller (never disposed)
    Get.put<GoogleSignInController>(
      GoogleSignInController(),
      permanent: true,
    );

    // 2️⃣  Google Drive helper (async init; never disposed)
    await Get.putAsync<GoogleDriveService>(
          () => GoogleDriveService.init(),
      permanent: true,
    );

    // 3️⃣  Core app‑wide controllers
    Get.put<CustomerLedgerController>(              // ← PERMANENT instance
      CustomerLedgerController(),
      permanent: true,
    );

    // Item / stock logic can be recreated when needed (fenix)
    Get.lazyPut<ItemTypeController>(() => ItemTypeController(), fenix: true);
  }
}
