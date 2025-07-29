// main.dart
import 'package:demo/routes/app_page_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'util/performance_monitor.dart';
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
  // Minimize work on main isolate during startup
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize performance monitoring
  PerformanceMonitor.initialize();
  
  // Set preferred orientations for better performance
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize only critical synchronous operations
  await GetStorage.init();
  
  // Initialize date formatting asynchronously to avoid blocking
  initializeDateFormatting('en_IN', null).catchError((e) {
    debugPrint('Date formatting initialization failed: $e');
  });
  
  // Create theme controller immediately (lightweight)
  Get.put(ThemeController());
  
  // Initialize other services asynchronously after app starts
  _initializeServicesAsync();

  // Start app immediately with default logged-out state
  runApp(const MyApp(isLoggedIn: false));
}

// Asynchronous initialization to avoid blocking main thread
void _initializeServicesAsync() async {
  final stopwatch = PerformanceMonitor.startOperation('Service Initialization');
  try {
    await InitialBindings.ensure();
    
    // Check sign-in status after services are ready
    final signInController = Get.find<GoogleSignInController>();
    if (signInController.isSignedIn) {
      // Navigate to home if already signed in
      Get.offAllNamed(Routes.home);
    }
  } catch (e) {
    debugPrint('Service initialization failed: $e');
    // App can still function without these services
  } finally {
    PerformanceMonitor.endOperation('Service Initialization', stopwatch);
  }
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
      // Always start with login screen for faster startup
      initialRoute: Routes.login,
      getPages: AppPages.routes,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeController.theme,
      // Add performance optimizations
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // Disable accessibility scaling that can cause performance issues
            textScaleFactor: 1.0,
          ),
          child: child!,
        );
      },
      // Additional performance settings
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 200), // Reduced transition time
      routingCallback: (routing) {
        // Log route changes for performance monitoring
        if (routing?.current != null) {
          PerformanceMonitor.startOperation('Route: ${routing!.current}');
        }
      },
    );
  }
}