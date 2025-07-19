// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/google_signin_controller.dart';
import '../routes/routes.dart';
import '../widget/custom_app_bar.dart'; // Assuming you have this custom app bar

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final GoogleSignInController googleSignInController = Get.find<GoogleSignInController>();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary;
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color surfaceColor = Theme.of(context).colorScheme.surface;
    final Color cardColor = Theme.of(context).cardColor;
    final Color outlineColor = Theme.of(context).colorScheme.outline;
    final Color errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: CustomAppBar(
        title: Text('Profile', style: Theme.of(context).appBarTheme.titleTextStyle),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Obx(() {
            final user = googleSignInController.user.value;

            if (user == null) {
              return Center(
                child: Text(
                  'User not signed in.',
                  style: TextStyle(color: onSurfaceColor),
                ),
              );
            }

            final photoUrl = user.photoUrl;
            final displayName = user.displayName ?? 'N/A';
            final email = user.email ?? 'N/A';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: primaryColor.withOpacity(0.2),
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          :null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? Icon(Icons.person, size: 60, color: primaryColor)
                          : null,
                    ),
                    const SizedBox(height: 24),
                    Card(
                      color: cardColor,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: outlineColor.withOpacity(0.5)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.person_outline, color: primaryColor),
                              title: Text(
                                'Name',
                                style: TextStyle(color: onSurfaceColor.withOpacity(0.7)),
                              ),
                              subtitle: Text(
                                displayName,
                                style: TextStyle(
                                  color: onSurfaceColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Divider(color: outlineColor.withOpacity(0.3)),
                            ListTile(
                              leading: Icon(Icons.email_outlined, color: primaryColor),
                              title: Text(
                                'Email',
                                style: TextStyle(color: onSurfaceColor.withOpacity(0.7)),
                              ),
                              subtitle: Text(
                                email,
                                style: TextStyle(
                                  color: onSurfaceColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await googleSignInController.logout();
                        Get.offAllNamed(Routes.login);
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        'Logout',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: errorColor, // Use error color for logout button
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}