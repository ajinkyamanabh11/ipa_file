import 'package:demo/Screens/Creditors_screen.dart';
import 'package:demo/Screens/Debtors_screen.dart';
import 'package:get/get.dart';
import '../Screens/User_profile_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/customer_ledger_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/sales_screen.dart';
import '../screens/profit_screen.dart';
import '../screens/stock_Screens/item_type_screen.dart';
import '../screens/stock_Screens/item_list_screen.dart';
 // <-- Ensure this import exists

import 'routes.dart';

class AppPages {
  static final routes = [
    GetPage(name: Routes.login, page: () => LoginScreen()),
    GetPage(name: Routes.home, page: () => HomeScreen()),
    GetPage(name: Routes.customerLedger, page: () => const CustomerLedger_Screen()),
    GetPage(name: Routes.debtors, page: () => const DebtorsScreen()),
    GetPage(name: Routes.creditors, page: () => const CreditorsScreen()),

    //GetPage(name: Routes.transactions, page: () {}),
    GetPage(name: Routes.sales, page: () => const SalesScreen()),
    GetPage(name: Routes.profit, page: () => const ProfitReportScreen()),
    GetPage(name: Routes.itemTypes, page: () => const ItemTypeScreen()),
    GetPage(name: Routes.itemList, page: () => const ItemListScreen()),
    GetPage(name: Routes.profile, page: () => const ProfileScreen()), // <-- Must be present and correctly defined
  ];
}