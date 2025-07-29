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
  RxBool isInitializing = false.obs;

  bool get isSignedIn => user.value != null;

  Future<GoogleSignInAccount?> silentLogin() async {
    try {
      // Add timeout to prevent indefinite blocking
      final account = await _googleSignIn.signInSilently().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          log("Silent login timeout");
          return null;
        },
      );
      if (account != null) {
        user.value = account;
        log("Silent login: ${account.email}");
      }
      return account;
    } catch (e) {
      log("Silent login error: $e");
      return null;
    }
  }

  Future<void> login() async {
    try {
      // Add timeout for manual login as well
      final account = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          log("Manual login timeout");
          return null;
        },
      );
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
    try {
      await _googleSignIn.disconnect().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log("Logout timeout, proceeding anyway");
        },
      );
    } catch (e) {
      log("Logout error: $e");
    } finally {
      user.value = null;
      log("Logged out.");
    }
  }

  Future<Map<String, String>?> getAuthHeaders() async {
    // Attempt silent sign-in if not already signed in to get a fresh account
    final account = user.value ?? await _googleSignIn.signInSilently();
    if (account == null) {
      log("getAuthHeaders: No signed-in user found.");
      return null;
    }
    try {
      final headers = await account.authHeaders.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log("getAuthHeaders timeout");
          return <String, String>{};
        },
      );
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

    // Perform silent sign-in asynchronously without blocking initialization
    _performAsyncSilentSignIn();
  }

  // Separate method for async silent sign-in to avoid blocking onInit
  void _performAsyncSilentSignIn() async {
    isInitializing.value = true;
    try {
      // Use a shorter timeout for initial silent sign-in
      final account = await _googleSignIn.signInSilently().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          log("Initial silent sign-in timeout - proceeding without login");
          return null;
        },
      );
      
      if (account != null) {
        user.value = account;
        log("Initial silent sign-in successful: ${account.email}");
      } else {
        log("Initial silent sign-in: No user found.");
      }
    } catch (e) {
      log("Initial silent sign-in error: $e");
    } finally {
      isInitializing.value = false;
    }
  }
}