import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Onboarding Screen'),
            const SizedBox(height: 8),
            const Text('Setup - Permissions - Download Core Pack'),
          ],
        ),
      ),
    );
  }
}
