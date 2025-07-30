import 'package:demo/model/customerModel.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer';

class GoogleSignInController extends GetxController {
  static const List<String> _scopes = ['https://www.googleapis.com/auth/drive'];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  final Rx<GoogleSignInAccount?> user = Rx<GoogleSignInAccount?>(null);

  // Auth header caching
  Map<String, String>? _cachedAuthHeaders;
  DateTime? _authHeadersCacheTime;
  static const Duration _authCacheExpiry = Duration(minutes: 30); // Cache for 30 minutes

  bool get isSignedIn => user.value != null;

  // Basic customer methods
  String get customerId => user.value?.id ?? '';
  String get customerEmail => user.value?.email ?? '';
  String get customerName => user.value?.displayName ?? '';

  CustomerModel get currentCustomer => CustomerModel(
        customerId: customerId,
        customerName: customerName,
        customerEmail: customerEmail,
      );

  Future<void> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        user.value = account;
        log("Signed in as: ${account.email}");
        // Clear cached auth headers to force refresh
        _invalidateAuthCache();
      }
    } catch (e) {
      log("Error signing in: $e");
    }
  }

  Future<void> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        user.value = account;
        log("Silent sign-in successful: ${account.email}");
        // Clear cached auth headers to force refresh
        _invalidateAuthCache();
      } else {
        log("Initial silent sign-in: No user found.");
      }
    } catch (e) {
      log("Error during silent sign-in: $e");
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      user.value = null;
      _invalidateAuthCache(); // Clear cache on sign out
      log("Logged out.");
    }
  }

  /// Get auth headers with intelligent caching to reduce redundant calls
  Future<Map<String, String>?> getAuthHeaders() async {
    // Check if we have valid cached headers
    if (_cachedAuthHeaders != null && 
        _authHeadersCacheTime != null &&
        DateTime.now().difference(_authHeadersCacheTime!) < _authCacheExpiry) {
      log("getAuthHeaders: Using cached auth headers.");
      return _cachedAuthHeaders;
    }

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
      
      if (headers.isNotEmpty) {
        // Cache the headers
        _cachedAuthHeaders = headers;
        _authHeadersCacheTime = DateTime.now();
        log("getAuthHeaders: Successfully retrieved and cached auth headers.");
      }
      
      return headers;
    } catch (e) {
      log("getAuthHeaders error: $e");
      _invalidateAuthCache(); // Clear invalid cache
      return null;
    }
  }

  /// Invalidate auth header cache (call when user changes or signs out)
  void _invalidateAuthCache() {
    _cachedAuthHeaders = null;
    _authHeadersCacheTime = null;
    log("Auth headers cache invalidated.");
  }

  /// Force refresh of auth headers (useful for long-running operations)
  Future<Map<String, String>?> refreshAuthHeaders() async {
    _invalidateAuthCache();
    return await getAuthHeaders();
  }

  @override
  void onInit() {
    super.onInit();
    // Listen for changes to the current user
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      user.value = account;
      if (account != null) {
        log("onCurrentUserChanged: User is now ${account.email}");
        // Invalidate cache when user changes
        _invalidateAuthCache();
      } else {
        log("onCurrentUserChanged: User is now null (signed out)");
        _invalidateAuthCache();
      }
    });

    // Sign in silently when the controller is first instantiated
    // but don't await it here to avoid blocking initialization
    signInSilently();
  }
}