import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer';
import 'package:flutter/foundation.dart' show kIsWeb; // IMPORTANT: Import kIsWeb

class GoogleSignInController extends GetxController {
  // IMPORTANT: Replace 'YOUR_WEB_CLIENT_ID_FROM_CONSOLE.apps.googleusercontent.com'
  // with the actual Web application Client ID you created in Google Cloud Console
  // for your Flutter web app.
  static const String _webClientId = '639885057295-u22nhp0cafui6h3bfbedhj2tcnlqvp5v.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.readonly',
    ],
    // CRITICAL: Conditionally provide the clientId for web builds.
    // For iOS and Android, the native SDKs pick up the client ID from Info.plist
    // and google-services.json respectively, so it's 'null' for them.
    clientId: kIsWeb ? _webClientId : null,
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
      // Consider showing a user-friendly error message here, e.g., using Get.snackbar
    }
  }

  Future<void> logout() async {
    await _googleSignIn.disconnect();
    user.value = null;
    log("Logged out.");
  }

  Future<Map<String, String>?> getAuthHeaders() async {
    // Attempt silent sign-in if not already signed in to get a fresh account
    final account = user.value ?? await _googleSignIn.signInSilently();
    if (account == null) {
      log("getAuthHeaders: No signed-in user found.");
      return null;
    }
    try {
      final headers = await account.authHeaders;
      log("getAuthHeaders: Successfully retrieved auth headers.");
      return headers;
    } catch (e) {
      log("getAuthHeaders error: $e");
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Listen for changes to the current user
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      user.value = account;
      if (account != null) {
        log("onCurrentUserChanged: User is now ${account.email}");
      } else {
        log("onCurrentUserChanged: User is now null (signed out)");
      }
    });

    // Attempt silent sign-in on app startup
    _googleSignIn.signInSilently().then((account) {
      if (account != null) {
        user.value = account;
        log("Initial silent sign-in successful: ${account.email}");
      } else {
        log("Initial silent sign-in: No user found.");
      }
    }).catchError((e) {
      log("Initial silent sign-in error: $e");
    });
  }
}