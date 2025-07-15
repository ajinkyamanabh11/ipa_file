// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../util/dashboard_tiles.dart.dart';

import '../controllers/google_signin_controller.dart';
import '../routes/routes.dart';                     // ⬅ route constants

// other feature screens that still open by widget (if any) can stay imported
import 'stock_Screens/item_type_screen.dart';      // we’ll navigate by route now
import 'stock_Screens/item_list_screen.dart';
import 'customer_ledger_screen.dart';

import 'customer_ledger_screen.dart';
import 'profit_screen.dart';
import 'transactions_screen.dart';
import 'sales_screen.dart';                        // only for Grid preview icon

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Navigate via **named route** so bindings fire
  void navigateTo(String route) => Get.toNamed(route);

  Widget _buildGridItem(
      String label,
      IconData icon,
      VoidCallback onTap,
      Color color,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.green.shade50,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
            const SizedBox(height: 10),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.green.shade800),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: () {
        Get.back();
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GoogleSignInController>();

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: SingleChildScrollView(
          child: Column(
            children: [
              ClipPath(
                clipper: WaveClipper(),
                child: DrawerHeader(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage("assets/appbarimg.png"),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Row(
                    children: const [
                      CircleAvatar(radius: 30, backgroundImage: AssetImage('assets/applogo.png')),
                      SizedBox(width: 16),
                      Text("Kisan Krushi Menu",
                          style: TextStyle(fontSize: 20, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              ...drawerTiles.map((t) {
                if (t.label == 'Dashboard') {
                  return _buildDrawerItem(
                      dashIcon(t.label), t.label, () {});            // stay on home
                }
                if (t.label == 'Profile') {
                  return _buildDrawerItem(
                      dashIcon(t.label), t.label, () {});            // TODO: add route
                }
                // normal navigation
                return _buildDrawerItem(
                  dashIcon(t.label),
                  t.label,
                      () => t.route.isNotEmpty ? navigateTo(t.route) : {},
                );
              }).toList(),
          
              const Divider(),
              _buildDrawerItem(Icons.logout, "Logout", () async {
                await controller.logout();
                Get.offAllNamed(Routes.login);
              }),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // wave image background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: 310,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/appbarimg.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          // top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text("Kisan Krushi",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold)),
                        Text("By Manabh",
                            style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // grid dashboard
          Padding(
            padding: const EdgeInsets.only(top: 300),
            child: GridView.count(
              padding: const EdgeInsets.all(12),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              children: dashTiles.map((t) {
                return _buildGridItem(
                  t.label,
                  dashIcon(t.label),             // public helper
                      () => t.route.isNotEmpty ? navigateTo(t.route) : {},
                  Colors.green,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(size.width * .25, size.height, size.width * .5, size.height - 30);
    path.quadraticBezierTo(size.width * .75, size.height - 60, size.width, size.height - 30);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
