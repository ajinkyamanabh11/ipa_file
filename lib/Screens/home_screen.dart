// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Import for DateFormat

import '../controllers/company_name.dart';
import '../util/dashboard_tiles.dart.dart';

import '../controllers/google_signin_controller.dart';
import '../routes/routes.dart';                     // ⬅ route constants

// Import the ThemeController
import '../controllers/theme_controller.dart'; // <--- ADD THIS LINE

// other feature screens that still open by widget (if any) can stay imported
import 'stock_Screens/item_type_screen.dart';      // we’ll navigate by route now
import 'stock_Screens/item_list_screen.dart';
import 'customer_ledger_screen.dart';

import 'profit_screen.dart';
import 'transactions_screen.dart';
import 'sales_screen.dart';                        // only for Grid preview icon

// Import the ProfitReportController
import '../controllers/profit_report_controller.dart';


class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});


  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Navigate via **named route** so bindings fire
  void navigateTo(String route) => Get.toNamed(route);

  // Updated to use theme colors for consistency
  Widget _buildGridItem(
      String label,
      IconData icon,
      VoidCallback onTap,
      BuildContext context, // Pass BuildContext to access theme
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        // Use theme's card color
        color: Theme.of(context).cardColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              // Use theme's primary color for the avatar background
              backgroundColor: Theme.of(context).primaryColor,
              child: Icon(icon, color: Colors.white), // Icon color typically white on primary
            ),
            const SizedBox(height: 10),
            Text(label,
                textAlign: TextAlign.center,
                // Use theme's text style for consistency
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // Updated to use theme colors and text styles for consistency
  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, BuildContext context) {
    return ListTile(
      // Use theme's icon color
      leading: Icon(icon, color: Theme.of(context).iconTheme.color),
      title: Text(title,
          // Use theme's text style
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      onTap: () {
        Get.back();
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GoogleSignInController>();
    final profitController = Get.find<ProfitReportController>();
    final themeController = Get.find<ThemeController>(); // <--- GET THE THEME CONTROLLER

    // Calculate today's date once in build for use
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day);
    final endDate = DateTime(today.year, today.month, today.day);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // This ensures profit data for today is loaded when the screen is first built
      profitController.loadProfitReport(startDate: startDate, endDate: endDate);
    });

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        // The drawer's background will automatically adapt based on scaffoldBackgroundColor
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
                    children: [
                      // Using fixed colors for elements on a background image for contrast
                      CircleAvatar(radius: 30, backgroundImage: AssetImage('assets/applogo.png')),
                      SizedBox(width: 16),
                      Text("Kisan Krushi Menu",
                          style: TextStyle(fontSize: 20, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              // Map existing drawer tiles, passing context
              ...drawerTiles.map((t) {
                if (t.label == 'Dashboard') {
                  return _buildDrawerItem(
                      dashIcon(t.label), t.label, () {}, context); // Pass context
                }
                if (t.label == 'Profile') {
                  return _buildDrawerItem(
                      dashIcon(t.label), t.label, () {}, context); // Pass context
                }
                return _buildDrawerItem(
                  dashIcon(t.label),
                  t.label,
                      () => t.route.isNotEmpty ? navigateTo(t.route) : {},
                  context, // Pass context
                );
              }).toList(),

              // <--- ADD THE THEME TOGGLE HERE ---
              Obx(() => SwitchListTile(
                title: Text(
                  themeController.isDarkMode.value ? "Dark Mode" : "Light Mode",
                  style: Theme.of(context).textTheme.bodyMedium, // Use theme text style
                ),
                secondary: Icon(
                  themeController.isDarkMode.value ? Icons.dark_mode : Icons.light_mode,
                  color: Theme.of(context).iconTheme.color, // Use theme icon color
                ),
                value: themeController.isDarkMode.value,
                onChanged: (bool value) {
                  themeController.toggleTheme(); // Call the toggle method
                },
                activeColor: Theme.of(context).primaryColor, // Use theme's primary color
              )),
              // --- END THEME TOGGLE ---

              const Divider(), // Divider color will adapt via theme.dividerColor
              _buildDrawerItem(Icons.logout, "Logout", () async {
                await controller.logout();
                Get.offAllNamed(Routes.login);
              }, context), // Pass context
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // wave image background (existing)
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
          // top bar (existing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white), // Keep white for contrast on image
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    const Spacer(),
                    Expanded(
                      flex: 3,
                      child: FutureBuilder<String>(
                        future: fetchCompanyNameFromDrive(),
                        builder: (context, snapshot) {
                          final company = snapshot.data ?? 'Loading ...';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                company,
                                style: const TextStyle(
                                  color: Colors.white, // Keep white for contrast on image
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.end,
                                softWrap: true,
                              ),
                              const Text(
                                "By Manabh",
                                style: TextStyle(color: Colors.white, fontSize: 14), // Keep white for contrast on image
                                textAlign: TextAlign.end,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Todays Profit Card - Now with appbarimg.png background
          Positioned(
            top: 140,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    // Box shadow color can be theme-dependent, but black54 is often good for both.
                    color: Colors.black54,
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                // NEW: Use DecorationImage for the background
                image: const DecorationImage(
                  image: AssetImage('assets/appbarimg.png'),
                  fit: BoxFit.cover, // Ensures the image covers the card area
                  // You might want to adjust colorFilter for better text readability
                  // colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                ),
              ),
              child: Card(
                color: Colors.transparent, // Keep transparent to show Container's image
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today's Profit",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // Keep text white for contrast on image
                            ),
                          ),
                          // Place the refresh button next to the trending icon
                          Row( // Wrap icon and button in another Row for alignment
                            children: [
                              IconButton( // NEW: Refresh button
                                icon: const Icon(Icons.refresh, color: Colors.white), // Keep white for contrast
                                onPressed: () {
                                  // Call loadProfitReport with today's date
                                  profitController.loadProfitReport(
                                    startDate: startDate, // Use the calculated startDate
                                    endDate: endDate,     // Use the calculated endDate
                                  );
                                },
                                tooltip: "Refresh Today's Profit",
                              ),
                              Icon(Icons.trending_up, color: Colors.white.withOpacity(0.8), size: 30), // Keep white for contrast
                            ],
                          ),
                        ],
                      ),

                      Obx(() {
                        if (profitController.isLoading.value) {
                          return LinearProgressIndicator(
                            color: Theme.of(context).colorScheme.onPrimary, // Use theme color
                            backgroundColor: Theme.of(context).primaryColor, // Use theme color
                          );
                        }
                        return Text(
                          '₹ ${profitController.totalProfit.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Keep white for contrast on image
                          ),
                        );
                      }),

                      Text(
                        'As of ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8), // Keep white for contrast on image
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // grid dashboard (adjusted top padding)
          Padding(
            padding: const EdgeInsets.only(top: 320),
            child: GridView.count(
              padding: const EdgeInsets.all(12),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              children: dashTiles.map((t) {
                return _buildGridItem(
                  t.label,
                  dashIcon(t.label),
                      () => t.route.isNotEmpty ? navigateTo(t.route) : {},
                  context, // <--- PASS CONTEXT HERE
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