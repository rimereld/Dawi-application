import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../theme/app_theme.dart';

/// Settings page (spec section 27). NOTE: the toggles here are local UI
/// state for now — persisting them (and wiring notification toggles to
/// actual scheduled reminders) is a natural next step once push/local
/// notifications are set up.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _medicationReminders = true;
  bool _appointmentReminders = true;
  bool _generalNotifications = true;
  bool _biometricLock = false;
  bool _darkMode = false;
  String _language = AppLanguages.all.last;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _SectionHeader('Notifications'),
            SwitchListTile(
              value: _medicationReminders,
              onChanged: (v) => setState(() => _medicationReminders = v),
              title: const Text('Medication reminders'),
            ),
            SwitchListTile(
              value: _appointmentReminders,
              onChanged: (v) => setState(() => _appointmentReminders = v),
              title: const Text('Appointment reminders'),
            ),
            SwitchListTile(
              value: _generalNotifications,
              onChanged: (v) => setState(() => _generalNotifications = v),
              title: const Text('General notifications'),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionHeader('Privacy & Security'),
            SwitchListTile(
              value: _biometricLock,
              onChanged: (v) => setState(() => _biometricLock = v),
              title: const Text('Biometric app lock'),
              subtitle: const Text('Requires Face ID / fingerprint to open the app'),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionHeader('Application'),
            SwitchListTile(
              value: _darkMode,
              onChanged: (v) => setState(() => _darkMode = v),
              title: const Text('Dark mode'),
            ),
            ListTile(
              title: const Text('Language'),
              trailing: DropdownButton<String>(
                value: _language,
                items: AppLanguages.all.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) => setState(() => _language = v ?? _language),
              ),
            ),
            ListTile(
              title: const Text('About'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'HealthKeep',
                applicationVersion: '1.0.0 (MVP)',
                children: const [Text('Your health, organized and understood.')],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 13)),
      );
}
