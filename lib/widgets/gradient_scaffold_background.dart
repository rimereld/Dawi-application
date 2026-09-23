import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Soft mint-to-white gradient backdrop used behind chat / mockup style
/// screens, matching the reference designs.
class GradientScaffoldBackground extends StatelessWidget {
  final Widget child;
  const GradientScaffoldBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.mintBackground, AppColors.scaffoldBackground],
        ),
      ),
      child: child,
    );
  }
}
