import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const HealthKeepApp());
}

/// Root widget for the personal health app.
///
/// Flow: [SplashScreen] restores any saved session, then routes to
/// onboarding (first launch), login (returning, logged out), or
/// [MainShell] (logged in) — see splash_screen.dart for the exact logic.
class HealthKeepApp extends StatelessWidget {
  const HealthKeepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'HealthKeep',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const SplashScreen(),
      ),
    );
  }
}
