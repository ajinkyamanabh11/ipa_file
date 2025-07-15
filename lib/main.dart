// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'bindings/initial_bindings.dart';
import 'routes/routes.dart';

// ── controllers ──────────────────────────────────────────
import 'controllers/sales_controller.dart';
import 'controllers/customerLedger_Controller.dart';

// ── screens ──────────────────────────────────────────────
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/stock_screens/item_type_screen.dart';
import 'screens/stock_screens/item_list_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/customer_ledger_screen.dart';
import 'screens/debtors_screen.dart';          // 👈 NEW

/// Route‑aware animations, etc.
final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1️⃣  Load date symbols for en_IN (once)
  await initializeDateFormatting('en_IN', null);

  // 2️⃣  Register global singletons
  await InitialBindings.ensure();

  // 3️⃣  Default locale for every DateFormat()
  Intl.defaultLocale = 'en_IN';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Safety: ensure locale each rebuild
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
        // ────────────────── auth & home ───────────────────
        GetPage(name: Routes.login, page: () => const LoginScreen()),
        GetPage(name: Routes.home,  page: () =>       HomeScreen()),

        // ────────────────── stock flow ────────────────────
        GetPage(name: Routes.itemTypes, page: () => const ItemTypeScreen()),
        GetPage(name: Routes.itemList,  page: () => const ItemListScreen()),

        // ────────────────── sales ─────────────────────────
        GetPage(
          name: Routes.sales,
          page: () => const SalesScreen(),
          binding: BindingsBuilder(() {
            Get.lazyPut(() => SalesController(), fenix: true);
          }),
        ),

        // ────────────────── customer ledger (outstanding) ─
        GetPage(
          name: Routes.outstanding,
          page: () => const CustomerLedger_Screen(),
          binding: BindingsBuilder(() {
            Get.lazyPut(() => CustomerLedgerController(), fenix: true);
          }),
        ),

        // ────────────────── debtors screen ────────────────
        GetPage(
          name: Routes.debtors,                     // 👈 NEW route constant
          page: () => DebtorsScreen(),
          binding: BindingsBuilder(() {
            // reuse the same controller – already fenix so no duplicate
            Get.lazyPut(() => CustomerLedgerController(), fenix: true);
          }),
        ),
      ],
    );
  }
}
