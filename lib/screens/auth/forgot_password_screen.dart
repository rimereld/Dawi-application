import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// UI for the "Forgot Password" flow (spec section 3). NOTE: this is a
/// front-end-only stub — there's no email-sending endpoint on the backend
/// yet, so tapping "Send reset link" just shows the confirmation message.
/// Wire this up to a real `/auth/forgot-password` endpoint before shipping.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_sent) ...[
                const Text(
                  "Enter your email and we'll send you a link to reset your password.",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () => setState(() => _sent = true),
                  child: const Text('Send reset link'),
                ),
              ] else ...[
                const Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.success),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'If an account exists for ${_emailController.text}, a reset link has been sent.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to login')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
