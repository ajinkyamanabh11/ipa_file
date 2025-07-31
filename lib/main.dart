
import 'package:demo/routes/app_page_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/date_symbol_data_local.dart';
// Import your custom theme definitions
import 'util/themes.dart';
import 'util/preference_manager.dart';
// Import your theme controller
import 'controllers/theme_controller.dart';
import 'controllers/google_signin_controller.dart';
import 'bindings/initial_bindings.dart';
import 'routes/routes.dart';
// Ensure this is imported for getPages

// ── controllers (only those that still need per‑page binding) ──
import 'controllers/sales_controller.dart';
// ── screens ───────────────────────────────────────────────────
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/stock_screens/item_type_screen.dart';
import 'screens/stock_screens/item_list_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/customer_ledger_screen.dart';
import 'screens/debtors_screen.dart';
import 'screens/creditors_screen.dart';
import 'screens/profit_screen.dart';


/// Route‑aware animations
final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

// main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_IN', null);
  await GetStorage.init();
  Get.put(ThemeController());
  await InitialBindings.ensure(); // This will put GoogleSignInController and GoogleDriveService

  final signInController = Get.find<GoogleSignInController>(); // Get the already put instance
  // IMPORTANT: Do NOT await signInSilently here if you want to handle it on the login screen
  // The silent login is already happening in the onInit of GoogleSignInController
  // but we don't need to block the UI or make routing decisions based on its *immediate* result here.

  // Instead, just check the initial state of the user.
  // The GoogleSignInController's `user` stream will update when silent sign-in completes.
  // For the initial route, we assume they're not logged in until proven otherwise by the controller's state.

  final hasSeenWalkthrough = PreferenceManager.hasSeenWalkthrough();
  runApp(MyApp(
    isLoggedIn: signInController.isSignedIn,
    hasSeenWalkthrough: hasSeenWalkthrough,
  )); // Pass the *initial* state
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool hasSeenWalkthrough;
  const MyApp({super.key, required this.isLoggedIn, required this.hasSeenWalkthrough});

  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = 'en_IN';
    final themeController = Get.find<ThemeController>();
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Kisan Krushi",
      navigatorObservers: [routeObserver],
      // The initialRoute now correctly points to walkthrough if not logged in and hasn't seen walkthrough,
      // login if not logged in but has seen walkthrough, or home if logged in.
      initialRoute: isLoggedIn
          ? Routes.home
          : (hasSeenWalkthrough ? Routes.login : Routes.walkthrough),
      getPages: AppPages.routes,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeController.theme,
    );
  }
}