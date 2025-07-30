// lib/util/dashboard_tiles.dart
import 'package:flutter/material.dart';
import '../routes/routes.dart';

class DashTile {
  final String label;
  final String route;
  const DashTile(this.label, this.route);
}

/// case‑insensitive icon resolver
IconData dashIcon(String label) {
  switch (label.toLowerCase()) {
    case 'dashboard':        return Icons.dashboard;          // 🆕
    case 'profile':          return Icons.person;             // 🆕
    case 'stock':            return Icons.inventory;
    case 'sales':            return Icons.point_of_sale;
    case 'lazy sales':       return Icons.download_rounded;   // 🆕 Lazy loading sales
    case 'customer ledger':  return Icons.money_off;
    case 'debtors':          return Icons.people;
    case 'creditors':        return Icons.account_balance_wallet;
    case 'profit':           return Icons.show_chart;
    case 'transactions':     return Icons.receipt_long;
    case 'sales flow':       return Icons.swap_horiz;
    default:                 return Icons.help_outline;
  }
}

/// grid buttons
const List<DashTile> dashTiles = [
  DashTile('Stock',            Routes.itemTypes),
  DashTile('Sales',            Routes.sales),
  DashTile('Lazy Sales',       Routes.lazySales),     // 🆕 On-demand CSV loading
  DashTile('Customer Ledger',  Routes.customerLedger),
  DashTile('Debtors',          Routes.debtors),       // ✅ fixed
  DashTile('Creditors', Routes.creditors),
  DashTile('Profit',           Routes.profit),
  DashTile('Transactions',     Routes.transactions),
  DashTile('Sales Flow',       ''), // TODO route
];

/// drawer menu items
/// drawer menu items
const List<DashTile> drawerTiles = [
  DashTile('Dashboard',           ''),               // stays on home
  DashTile('Profile',             ''),               // add route later
  DashTile('Stock',               Routes.itemTypes),
  DashTile('Sales',               Routes.sales),
  DashTile('Lazy Sales',          Routes.lazySales), // 🆕 On-demand CSV loading
  DashTile('Customer Ledger',     Routes.customerLedger),
  DashTile('Debtors',             Routes.debtors),    // ✅ fixed
  DashTile('Creditors',           Routes.creditors),  // ✅ fixed
  DashTile('Profit',              Routes.profit),
  DashTile('Transactions',        Routes.transactions),
  DashTile('Sales Purchase Flow', ''),               // add route later
];

