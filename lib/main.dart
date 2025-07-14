import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'Screens/outstanding_screen.dart';
import 'Screens/sales_screen.dart';
import 'bindings/initial_bindings.dart';
import 'controllers/outstanding_controller.dart';
import 'controllers/sales_controller.dart';
import 'routes/routes.dart';                      // ← import constants
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/stock_Screens/item_type_screen.dart';
import 'screens/stock_Screens/item_list_screen.dart';

// for BindingsBuilder

void main() => runApp(const MyApp());

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green.shade800,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      initialBinding: InitialBindings(),
      initialRoute: Routes.login,
      navigatorObservers: [routeObserver],
      getPages: [
        GetPage(name: Routes.login,     page: () => const LoginScreen()),
        GetPage(name: Routes.home,      page: () => HomeScreen()),
        GetPage(name: Routes.itemTypes, page: () => const ItemTypeScreen()),
        GetPage(name: Routes.itemList,  page: () => const ItemListScreen()),
        GetPage(
          name: Routes.sales,
          page: () => const SalesScreen(),
          binding: BindingsBuilder(() {
            Get.lazyPut<SalesController>(() => SalesController());
          }),
        ),
        GetPage(
          name: Routes.outstanding,
          page: () => OutstandingScreen(),
          binding: BindingsBuilder(() {
            Get.lazyPut<OutstandingController>(() => OutstandingController());
          }),
        ),
      ],
    );
  }
}
