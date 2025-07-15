import 'package:get/get.dart';

import '../controllers/google_signin_controller.dart';
import '../services/google_drive_service.dart';
import '../controllers/item_type_controller.dart';
import '../controllers/customerLedger_Controller.dart';

class InitialBindings {
  static bool _done = false;

  static Future<void> ensure() async {
    if (_done) return;
    _done = true;

    // 1️⃣  Google sign‑in
    Get.put(GoogleSignInController(), permanent: true);

    // 2️⃣  Google Drive service (async)
    await Get.putAsync<GoogleDriveService>(
          () => GoogleDriveService.init(),
      permanent: true,
    );

    // 3️⃣  Core controllers
    Get.lazyPut<ItemTypeController>(() => ItemTypeController(), fenix: true);

    Get.lazyPut<CustomerLedgerController>(() => CustomerLedgerController(),
        fenix: true);
  }
}
