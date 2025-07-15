import 'package:get/get.dart';

mixin BaseRemoteController on GetxController {
  final isLoading = false.obs;
  final error     = RxnString();

  /// Wrap async work with loading/error handling.
  Future<void> guard(Future<void> Function() job) async {
    try {
      isLoading.value = true;
      error.value     = null;
      await job();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}