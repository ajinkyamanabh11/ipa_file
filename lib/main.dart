import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

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
import 'Screens/debtors_screen.dart';
import 'Screens/creditors_screen.dart';

/// Route‑aware animations
final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('en_IN', null); // locale symbols
  await InitialBindings.ensure();                // register singletons
  Intl.defaultLocale = 'en_IN';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // (safety) ensure locale each rebuild
    Intl.defaultLocale = 'en_IN';

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      navigatorObservers: [routeObserver],
      initialRoute: Routes.login,
      getPages: [
        // ───── auth & home ──────────────────────────────────────
        GetPage(name: Routes.login, page: () => const LoginScreen()),
        GetPage(name: Routes.home,  page: () =>       HomeScreen()),

        // ───── stock ────────────────────────────────────────────
        GetPage(name: Routes.itemTypes, page: () => const ItemTypeScreen()),
        GetPage(name: Routes.itemList,  page: () => const ItemListScreen()),

        // ───── sales (needs its own controller) ─────────────────
        GetPage(
          name: Routes.sales,
          page: () => const SalesScreen(),
          binding: BindingsBuilder(() {
            Get.lazyPut(() => SalesController(), fenix: true);
          }),
        ),

        // ───── ledger family (reuse PERMANENT controller) ───────
        GetPage(name: Routes.customerLedger, page: () => const CustomerLedger_Screen()),
        GetPage(name: Routes.debtors,        page: () => DebtorsScreen()),
        GetPage(name: Routes.creditors,      page: () => const CreditorsScreen()),
      ],
    );
  }
}
