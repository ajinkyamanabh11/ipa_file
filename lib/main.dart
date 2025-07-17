import 'package:demo/screens/profit_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';


import 'controllers/google_signin_controller.dart';
import 'screens/profit_screen.dart';
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
  await initializeDateFormatting('en_IN', null);

  // 🔁 Ensure all bindings are registered
  await InitialBindings.ensure();

  // 🔍 Perform silent sign-in BEFORE app launches
  final signInController = Get.put(GoogleSignInController());
  final account = await signInController.silentLogin();
  if (account != null) {
    signInController.user.value = account;
  }

  runApp(MyApp(isLoggedIn: account != null));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key,required this.isLoggedIn});

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
          page: () =>  ProfitReportScreen(),   // or ProfitScreen() if you kept old
        ),
      ],
    );
  }
}
