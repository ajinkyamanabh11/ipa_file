import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/google_signin_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final GoogleSignInController googleSignInController = Get.find<GoogleSignInController>();

  late AnimationController _logoAnimationController;
  late Animation<double> _logoFadeAnimation;
  late Animation<Offset> _logoSlideAnimation;

  late AnimationController _welcomeTextAnimationController;
  late Animation<double> _welcomeTextFadeAnimation;
  late Animation<Offset> _welcomeTextSlideAnimation;

  late AnimationController _manabhTextAnimationController;
  late Animation<double> _manabhTextFadeAnimation;
  late Animation<Offset> _manabhTextSlideAnimation;

  late AnimationController _sloganTextAnimationController;
  late Animation<double> _sloganTextFadeAnimation;
  late Animation<Offset> _sloganTextSlideAnimation;

  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonFadeAnimation;
  late Animation<Offset> _buttonSlideAnimation;

  @override
  void initState() {
    super.initState();

    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoAnimationController, curve: Curves.easeIn),
    );
    _logoSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _logoAnimationController, curve: Curves.easeOutCubic),
    );

    _welcomeTextAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _welcomeTextFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _welcomeTextAnimationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );
    _welcomeTextSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _welcomeTextAnimationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _manabhTextAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _manabhTextFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _manabhTextAnimationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
    _manabhTextSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _manabhTextAnimationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _sloganTextAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _sloganTextFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sloganTextAnimationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );
    _sloganTextSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _sloganTextAnimationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _buttonFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );
    _buttonSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _logoAnimationController.forward();
    _welcomeTextAnimationController.forward();
    _manabhTextAnimationController.forward();
    _sloganTextAnimationController.forward();
    _buttonAnimationController.forward();
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _welcomeTextAnimationController.dispose();
    _manabhTextAnimationController.dispose();
    _sloganTextAnimationController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            "assets/loginbg1.png",
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.black.withOpacity(0.10),
          ),
          // Use a Column to arrange elements vertically,
          // with Spacers to push the button to the bottom
          Column(
            mainAxisAlignment: MainAxisAlignment.start, // Align content from the top
            children: [
              const Spacer(flex: 3), // Pushes content down from the top

              FadeTransition(
                opacity: _logoFadeAnimation,
                child: SlideTransition(
                  position: _logoSlideAnimation,
                  child: Hero(
                    tag: 'logo',
                    child: Container(
                      height: 120,
                      width: 120,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset("assets/applogo_circle.png"),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              FadeTransition(
                opacity: _welcomeTextFadeAnimation,
                child: SlideTransition(
                  position: _welcomeTextSlideAnimation,
                  child: const Text(
                    'Welcome to',
                    style: TextStyle(
                      fontSize: 26,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              FadeTransition(
                opacity: _manabhTextFadeAnimation,
                child: SlideTransition(
                  position: _manabhTextSlideAnimation,
                  child: const Text(
                    'Manabh Softagri',
                    style: TextStyle(
                      fontSize: 26,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),
              FadeTransition(
                opacity: _sloganTextFadeAnimation,
                child: SlideTransition(
                  position: _sloganTextSlideAnimation,
                  child: const Text(
                    'Login to access your SoftAgri Data',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),

               // Pushes the button towards the bottom
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _buttonFadeAnimation,
                child: SlideTransition(
                  position: _buttonSlideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                      icon: Image.asset(
                        'assets/googleicon.png',
                        height: 24,
                        width: 24,
                      ),
                      label: const Text(
                        "Sign in with Google",
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                      onPressed: () async {
                        await googleSignInController.login();
                        if (googleSignInController.isSignedIn) {
                          Get.offAllNamed('/home');
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40), // Padding at the very bottom
            ],
          ),
        ],
      ),
    );
  }
}