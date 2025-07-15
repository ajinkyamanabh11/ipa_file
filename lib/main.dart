import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'bindings/initial_bindings.dart';
import 'controllers/customerLedger_Controller.dart';
import 'controllers/sales_controller.dart';
import 'routes/routes.dart';
import 'package:intl/date_symbol_data_local.dart';
// ── screens ─────────────────────────────────────────────
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/stock_screens/item_type_screen.dart';
import 'screens/stock_screens/item_list_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/customer_ledger_screen.dart';

// Route‑aware animations, etc.
final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// 1️⃣  Load date symbols for en_IN (once)
  await initializeDateFormatting('en_IN', null);

  /// 2️⃣  Register singletons
  await InitialBindings.ensure();

  /// 3️⃣  Set as default so every `DateFormat()` picks it up
  Intl.defaultLocale = 'en_IN';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Fix for Indian locale money formatting used in screens
    Intl.defaultLocale = 'en_IN';

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20), // green.800
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      navigatorObservers: [routeObserver],
      initialRoute: Routes.login,
      getPages: [
        GetPage(name: Routes.login,     page: () => const LoginScreen()),
        GetPage(name: Routes.home,      page: () =>       HomeScreen()),
        GetPage(name: Routes.itemTypes, page: () => const ItemTypeScreen()),
        GetPage(name: Routes.itemList,  page: () => const ItemListScreen()),
        GetPage(
          name: Routes.sales,
          page: () => const SalesScreen(),
          binding: BindingsBuilder(() {
            Get.lazyPut(() => SalesController(), fenix: true);
          }),
        ),
        GetPage(
          name: Routes.outstanding,
          page: () => const CustomerLedger_Screen(),
          binding: BindingsBuilder(() {
            Get.lazyPut(() => CustomerLedgerController(), fenix: true);
          }),
        ),
      ],
    );
  }
}
