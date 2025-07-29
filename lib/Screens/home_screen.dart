// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/company_name.dart';
import '../util/dashboard_tiles.dart.dart';

import '../controllers/google_signin_controller.dart';
import '../routes/routes.dart'; // ⬅ route constants

// Import the ThemeController
import '../controllers/theme_controller.dart';

// Import the NEW TodayProfitController
import '../controllers/today_profit_controller.dart';

// other feature screens that still open by widget (if any) can stay imported



// ── HomeScreen: Converted to StatefulWidget for Animations ──────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GoogleSignInController googleSignInController = Get.find<GoogleSignInController>();

  // Animation controllers for the main screen content
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // NEW: Animation controllers for the Drawer content
  late AnimationController _drawerAnimationController;
  late Animation<Offset> _drawerSlideAnimation;
  late Animation<double> _drawerFadeAnimation;


  @override
  void initState() {
    super.initState();
    // Initialize main screen animation controller with reduced duration
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400), // Reduced from 1200ms for better performance
    );

    // Define main screen slide animation with less movement
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), // Reduced from 0.2 for smoother animation
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut, // Simpler curve for better performance
    ));

    // Define main screen fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn, // Keep simple fade-in curve
    ));

    // Start the main screen animation when the screen loads
    // Use addPostFrameCallback to ensure it runs after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });

    // Initialize Drawer animation controller with reduced duration
    _drawerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Reduced from 800ms
    );
    _drawerSlideAnimation = Tween<Offset>(
      begin: const Offset(-0.1, 0), // Reduced from -0.2 for smoother animation
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _drawerAnimationController,
      curve: Curves.easeOut, // Simpler curve
    ));
    _drawerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _drawerAnimationController,
      curve: Curves.easeIn,
    ));

    // Trigger drawer animation after a slight delay to avoid competing with main animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _drawerAnimationController.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose(); // Dispose of the main screen controller
    _drawerAnimationController.dispose(); // NEW: Dispose of the drawer controller
    super.dispose();
  }

  /// Navigate via **named route** so bindings fire
  void navigateTo(String route) => Get.toNamed(route);

  // _buildGridItem: Optimized for better performance
  Widget _buildGridItem(
      String label,
      IconData icon,
      VoidCallback onTap,
      BuildContext context,
      int index, // Added index for staggered animation
      ) {
    // Simplified animation for better performance
    final itemSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2), // Reduced movement for smoother animation
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        (0.1 + index * 0.05).clamp(0.0, 0.8), // Reduced stagger delay and shortened interval
        1.0,
        curve: Curves.easeOut, // Simpler curve
      ),
    ));

    final itemFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        (0.1 + index * 0.05).clamp(0.0, 0.8), // Same optimized timing
        1.0,
        curve: Curves.easeIn,
      ),
    ));

    return FadeTransition(
      opacity: itemFadeAnimation, // Fade in each item
      child: SlideTransition(
        position: itemSlideAnimation, // Slide up each item
        child: GestureDetector(
          onTap: onTap,
          child: Card(
            color: Theme.of(context).cardColor,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Updated _buildDrawerItem to include staggered animation
  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, BuildContext context, int index) {
    // NEW: Staggered animation for each drawer item
    final itemSlideAnimation = Tween<Offset>(
      begin: const Offset(-0.1, 0), // Slide slightly from left
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _drawerAnimationController,
      curve: Interval(
        (0.0 + index * 0.08).clamp(0.0, 1.0), // Stagger start time
        1.0,
        curve: Curves.easeOutCubic,
      ),
    ));

    final itemFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _drawerAnimationController,
      curve: Interval(
        (0.0 + index * 0.08).clamp(0.0, 1.0), // Stagger start time
        1.0,
        curve: Curves.easeIn,
      ),
    ));

    return FadeTransition(
      opacity: itemFadeAnimation,
      child: SlideTransition(
        position: itemSlideAnimation,
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).iconTheme.color),
          title: Text(title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          onTap: () {
            // Ensure drawer closes before navigation
            if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
              _scaffoldKey.currentState?.openEndDrawer(); // Close drawer
            }
            // Add a small delay for the animation to play out before navigation
            Future.delayed(const Duration(milliseconds: 200), () {
              onTap();
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GoogleSignInController>();
    final todayProfitController = Get.put(TodayProfitController());
    final themeController = Get.find<ThemeController>();

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        // NEW: Wrap the entire drawer content with animation widgets
        child: FadeTransition(
          opacity: _drawerFadeAnimation,
          child: SlideTransition(
            position: _drawerSlideAnimation,
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
                      child:  Row(
                        children: [
                          Obx(() {
                            final user = googleSignInController.user.value;
                            final photoUrl = user?.photoUrl; // Corrected to photoUrl (lowercase 'u')

                            // Fix for the TypeError: Use child property for Icon
                            if (photoUrl != null && photoUrl.isNotEmpty) {
                              return CircleAvatar(
                                radius: 30,
                                backgroundImage: NetworkImage(photoUrl), // Use NetworkImage
                              );
                            } else {
                              return CircleAvatar(
                                radius: 30,
                                backgroundColor: Theme.of(context).primaryColor, // Provide a background color
                                child: Icon(Icons.person, size: 30, color: Theme.of(context).colorScheme.onPrimary), // Use Icon as a child
                              );
                            }
                          }),
                          SizedBox(width: 16),
                          Obx(() {
                            final user = googleSignInController.user.value;
                            String displayText = "Kisan Krushi Menu";

                            if (user != null) {
                              final userName = user.displayName ?? user.email;
                              if (userName != null && userName.isNotEmpty) {
                                displayText = "Hello $userName";
                              } else {
                                displayText = "Hello User";
                              }
                            }

                            return Expanded(
                              child: Text(
                                displayText,
                                style: TextStyle(fontSize: 20, color: Colors.white),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  // Map existing drawer tiles, passing context and index for staggered animation
                  ...drawerTiles.asMap().entries.map((entry) { // Use asMap().entries to get index
                    final index = entry.key;
                    final t = entry.value;
                    if (t.label == 'Dashboard') {
                      return _buildDrawerItem(
                          dashIcon(t.label), t.label, () {}, context, index);
                    }
                    if (t.label == 'Profile') { // <-- FIND THIS BLOCK
                      return _buildDrawerItem(
                          dashIcon(t.label),
                          t.label,
                              () => navigateTo(Routes.profile), // <-- CHANGE THIS LINE
                          context,
                          index);
                    }
                    return _buildDrawerItem(
                      dashIcon(t.label),
                      t.label,
                          () => t.route.isNotEmpty ? navigateTo(t.route) : {},
                      context,
                      index, // Pass index
                    );
                  }),

                  Obx(() => SwitchListTile(
                    title: Text(
                      themeController.isDarkMode.value ? "Dark Mode" : "Light Mode",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    secondary: Icon(
                      themeController.isDarkMode.value ? Icons.dark_mode : Icons.light_mode,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    value: themeController.isDarkMode.value,
                    onChanged: (bool value) {
                      themeController.toggleTheme();
                    },
                    activeColor: Theme.of(context).primaryColor,
                  )),
                  const Divider(),
                  // Pass index for the logout item as well
                  _buildDrawerItem(Icons.logout, "Logout", () async {
                    await controller.logout();
                    Get.offAllNamed(Routes.login);
                  }, context, drawerTiles.length), // Assign an index after all other tiles
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
          children: [
            // Wave image background (remains static at the bottom of the stack)
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
            // Animated content: top bar, profit card, and grid
            Positioned.fill( // Allows the content to fill the available space
              child: FadeTransition( // Overall fade-in for the content
                opacity: _fadeAnimation,
                child: SlideTransition( // Overall slide-up for the content
                  position: _slideAnimation,
                  child: Column( // Arrange content vertically
                    children: [
                      // Top bar
                      SafeArea(
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
                      // Todays Profit Card
                      Padding( // Use Padding instead of Positioned now that it's in a Column
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), // Adjust top padding
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
                                      Row( // Wrap icon and button in another Row for alignment
                                        children: [
                                          IconButton( // NEW: Refresh button
                                            icon: const Icon(Icons.refresh, color: Colors.white), // Keep white for contrast
                                            onPressed: () {
                                              // Call loadTodayProfit from the new controller
                                              todayProfitController.loadTodayProfit();
                                            },
                                            tooltip: "Refresh Today's Profit",
                                          ),
                                          Icon(Icons.trending_up, color: Colors.white.withOpacity(0.8), size: 30), // Keep white for contrast
                                        ],
                                      ),
                                    ],
                                  ),

                                  Obx(() {
                                    if (todayProfitController.isLoadingTodayProfit.value) { // Use new controller's loading state
                                      return LinearProgressIndicator(
                                        color: Theme.of(context).colorScheme.onPrimary, // Use theme color
                                        backgroundColor: Theme.of(context).primaryColor, // Use theme color
                                      );
                                    }
                                    return Text(
                                      '₹ ${todayProfitController.todayTotalProfit.value.toStringAsFixed(2)}', // Use new controller's profit
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
                      // Grid Dashboard: Now using GridView.builder for staggered animation
                      Expanded( // Takes remaining vertical space in the Column
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: dashTiles.length,
                          itemBuilder: (context, index) {
                            final t = dashTiles[index];
                            return _buildGridItem(
                              t.label,
                              dashIcon(t.label),
                                  () => t.route.isNotEmpty ? navigateTo(t.route) : {},
                              context,
                              index, // Pass the index to the builder for staggered animation
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),

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