import 'package:get/get.dart';
import '../controllers/google_signin_controller.dart';
import '../controllers/item_detail_controller.dart';
import '../controllers/item_type_controller.dart';
import '../controllers/customerLedger_Controller.dart';

class InitialBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(GoogleSignInController());
    Get.put(ItemTypeController());
    Get.put(ItemDetailController());
    Get.lazyPut<CustomerLedger_Controller>(() => CustomerLedger_Controller(), fenix: true);

  }
}
