import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/google_signin_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GoogleSignInController>();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            "assets/loginbg1.png",
            fit: BoxFit.cover,
          ),
      Container(
        color: Colors.black.withValues(alpha: 0.10), // 10 % alpha, precise
      ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'logo',
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset("assets/applogo.png"),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Welcome to Kisan Krushi',
                style: TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Login to access your SoftAgri Data',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
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
                    await controller.login();
                    if (controller.isSignedIn) {
                      Get.offAllNamed('/home');
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );

  }
}
