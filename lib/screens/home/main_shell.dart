import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../ai/ai_assistant_screen.dart';
import '../documents/documents_screen.dart';
import '../health/medical_record_screen.dart';
import '../profile/profile_screen.dart';
import 'home_dashboard_screen.dart';

/// Main navigation shell (spec section 31): bottom nav with 5 sections —
/// Home, Documents, Health, AI Assistant, Profile. Uses an IndexedStack so
/// each tab keeps its own scroll position / state when switching.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static _MainShellState? of(BuildContext context) => context.findAncestorStateOfType<_MainShellState>();

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void goToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeDashboardScreen(),
          DocumentsScreen(),
          MedicalRecordScreen(),
          AiAssistantScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: goToTab,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primaryLight,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: AppColors.primary), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder, color: AppColors.primary), label: 'Documents'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite, color: AppColors.primary), label: 'Health'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy, color: AppColors.primary), label: 'Assistant'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: AppColors.primary), label: 'Profile'),
        ],
      ),
    );
  }
}
