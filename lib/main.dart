// main.dart
import 'package:demo/routes/app_page_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
// Import your custom theme definitions
import 'util/themes.dart';
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

  // Initialize only critical controllers first
  Get.put(ThemeController());

  // Initialize core services without blocking startup
  await InitialBindings.ensureCore(); // Only core services initially

  final signInController = Get.find<GoogleSignInController>();

  // Run the app immediately, defer heavy data loading
  runApp(MyApp(isLoggedIn: signInController.isSignedIn));

  // Schedule background initialization after app starts
  Future.delayed(Duration(milliseconds: 500), () {
    InitialBindings.ensureSecondary(); // Load secondary services in background
  });
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = 'en_IN';
    final themeController = Get.find<ThemeController>();
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Kisan Krushi",
      navigatorObservers: [routeObserver],
      // The initialRoute now correctly points to login if not logged in
      // or home if the silent login from GoogleSignInController's onInit succeeded.
      initialRoute: isLoggedIn ? Routes.home : Routes.login,
      getPages: AppPages.routes,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeController.theme,
    );
  }
}