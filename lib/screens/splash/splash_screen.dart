import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/token_storage.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../home/main_shell.dart';
import '../onboarding/onboarding_screen.dart';

/// Minimal splash screen (spec section 1): logo, name, tagline, loading
/// animation, then automatic navigation to onboarding, login, or the main
/// app shell depending on whether onboarding was seen and whether a saved
/// session restores successfully.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthProvider>();
    final seenOnboarding = await tokenStorage.hasSeenOnboarding();
    await auth.tryAutoLogin();
    // Small minimum delay so the splash doesn't just flash by.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    Widget next;
    if (auth.status == AuthStatus.authenticated) {
      next = const MainShell();
    } else if (!seenOnboarding) {
      next = const OnboardingScreen();
    } else {
      next = const LoginScreen();
    }

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.health_and_safety_rounded, color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'HealthKeep',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Your health, organized and understood.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
