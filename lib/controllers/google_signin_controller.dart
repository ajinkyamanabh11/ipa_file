import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer';

class GoogleSignInController extends GetxController {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.readonly',
    ],
  );

  Rx<GoogleSignInAccount?> user = Rx<GoogleSignInAccount?>(null);

  bool get isSignedIn => user.value != null;
  Future<GoogleSignInAccount?> silentLogin() async {
    final account = await _googleSignIn.signInSilently();
    if (account != null) {
      user.value = account;
      log("Silent login: ${account.email}");
    }
    return account;
  }
  Future<void> login() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        user.value = account;
        log("Logged in as: ${account.email}");
      }
    } catch (e) {
      log("Login error: $e");
    }
  }

  Future<void> logout() async {
    await _googleSignIn.disconnect();
    user.value = null;
  }

  Future<Map<String, String>?> getAuthHeaders() async {
    final account = user.value ?? await _googleSignIn.signInSilently();
    if (account == null) return null;
    return await account.authHeaders;
  }

  @override
  void onInit() {
    super.onInit();
    _googleSignIn.signInSilently().then((account) {
      if (account != null) {
        user.value = account; // ✅ important!
        log("Signed in silently as ${account.email}");
      }
    });
  }
}
