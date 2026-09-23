import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Privacy & Security page (spec section 26) — static explanatory content
/// in plain language, plus action rows for consent/export/delete. The
/// actions here are placeholders until the corresponding backend
/// endpoints (data export, account deletion) are built.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _Section(
              title: 'What data we collect',
              body: 'Your account details, the medical documents you scan or upload, and the information '
                  'extracted from them (medications, appointments, doctors), plus any health profile details you choose to add.',
            ),
            _Section(
              title: 'Why we collect it',
              body: 'To build your personal health dashboard, power the AI Health Assistant, and send you reminders you set up.',
            ),
            _Section(
              title: 'How your data is stored',
              body: 'Your documents and data are stored securely and are only accessible to your account.',
            ),
            _Section(
              title: 'AI processing',
              body: 'When you scan a document or use the AI Assistant, the relevant text is sent to our AI provider '
                  'to extract information or generate a response. It is not used to identify you to any third party.',
            ),
            _Section(
              title: 'Does this app replace a doctor?',
              body: 'No. This app helps you organize and understand your health information, but it never diagnoses '
                  'conditions or replaces professional medical advice.',
            ),
            const SizedBox(height: AppSpacing.lg),
            _ActionTile(icon: Icons.download_outlined, title: 'Export my data', onTap: () => _notImplemented(context)),
            _ActionTile(icon: Icons.delete_outline, title: 'Delete my documents', onTap: () => _notImplemented(context)),
            _ActionTile(icon: Icons.person_remove_outlined, title: 'Delete my account', onTap: () => _notImplemented(context), destructive: true),
          ],
        ),
      ),
    );
  }

  void _notImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This action needs a backend endpoint — not wired up yet.')),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5)),
        ]),
      );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;
  const _ActionTile({required this.icon, required this.title, required this.onTap, this.destructive = false});
  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.redAccent : AppColors.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: destructive ? Colors.redAccent : AppColors.textPrimary))),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ]),
      ),
    );
  }
}
