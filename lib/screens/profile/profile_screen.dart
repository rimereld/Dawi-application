import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../theme/app_theme.dart';
import '../settings/privacy_screen.dart';
import '../settings/settings_screen.dart';

/// Profile page (spec section 25).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Center(
              child: Column(children: [
                const CircleAvatar(radius: 40, backgroundColor: AppColors.primaryLight, child: Icon(Icons.person, size: 40, color: AppColors.primary)),
                const SizedBox(height: AppSpacing.sm),
                Text(user?.fullName.isNotEmpty == true ? user!.fullName : 'Your profile',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(user?.email ?? '', style: const TextStyle(color: AppColors.textSecondary)),
              ]),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProfileTile(icon: Icons.phone_outlined, title: 'Phone', subtitle: user?.phone.isEmpty ?? true ? 'Not set' : user!.phone),
            _ProfileTile(icon: Icons.language_outlined, title: 'Preferred language', subtitle: user?.preferredLanguage ?? 'English'),
            const SizedBox(height: AppSpacing.lg),
            _NavTile(icon: Icons.settings_outlined, title: 'Settings', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
            _NavTile(icon: Icons.privacy_tip_outlined, title: 'Privacy & Security', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()))),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _ProfileTile({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(title, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
          child: Row(children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ]),
        ),
      );
}
