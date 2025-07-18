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
import 'screens/profit_screen.dart'; // Ensure this is imported correctly

/// Route‑aware animations
final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_IN', null);

  // 1. Initialize GetStorage (important for theme persistence)
  await GetStorage.init();

  // 2. Register your ThemeController early
  Get.put(ThemeController());

  // 3. Ensure all other bindings are registered
  await InitialBindings.ensure();

  // 4. Perform silent sign-in BEFORE app launches
  final signInController = Get.put(GoogleSignInController());
  final account = await signInController.silentLogin();
  if (account != null) {
    signInController.user.value = account;
  }

  // 5. Initialize theme based on saved preference AFTER ThemeController is put
  // This sets the initial theme mode for GetMaterialApp.
  Get.find<ThemeController>().initTheme();

  runApp(MyApp(isLoggedIn: account != null));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = 'en_IN';

    // Get an instance of your ThemeController
    final themeController = Get.find<ThemeController>();

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Kisan Krushi",
      navigatorObservers: [routeObserver],
      initialRoute: isLoggedIn ? Routes.home : Routes.login,
      getPages: [
        // ───── auth & home ──────────────────────────────────────
        GetPage(name: Routes.login, page: () => const LoginScreen()),
        GetPage(name: Routes.home, page: () => HomeScreen()),

        // ───── stock ────────────────────────────────────────────
        GetPage(name: Routes.itemTypes, page: () => const ItemTypeScreen()),
        GetPage(name: Routes.itemList, page: () => const ItemListScreen()),

        // ───── sales (needs its own controller) ─────────────────
        GetPage(
          name: Routes.sales,
          page: () => const SalesScreen(),
          binding: BindingsBuilder(() {
            Get.lazyPut(() => SalesController(), fenix: true);
          }),
        ),

        // ───── ledger family (reuse PERMANENT controller) ───────
        GetPage(
          name: Routes.customerLedger,
          page: () => const CustomerLedger_Screen(),
        ),
        GetPage(name: Routes.debtors, page: () => DebtorsScreen()),
        GetPage(name: Routes.creditors, page: () => const CreditorsScreen()),
        GetPage(
          name: Routes.profit,
          page: () => ProfitReportScreen(),
        ),
      ],

      // Configure your themes here
      theme: AppThemes.lightTheme, // Your defined light theme
      darkTheme: AppThemes.darkTheme, // Your defined dark theme

      // Set the themeMode directly using the reactive property from your controller.
      // GetMaterialApp is already smart enough to react to changes in themeController.theme.
      themeMode: themeController.theme,

      // REMOVE THE BUILDER WITH Obx THAT CALLS Get.changeThemeMode
      // This was the cause of the error.
      // builder: (context, child) {
      //   return Obx(() {
      //     Get.changeThemeMode(themeController.isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
      //     return child!;
      //   });
      // },
    );
  }
}