import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../theme/app_theme.dart';

/// Card that shows one extracted medication with dose / frequency / timing,
/// mirroring the "Paracetamol / Amoxicillin" result cards in the mock.
class MedicationCard extends StatelessWidget {
  final Medication medication;
  final ValueChanged<bool>? onConfirmChanged;

  const MedicationCard({
    super.key,
    required this.medication,
    this.onConfirmChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: medication.iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(medication.icon, color: medication.iconColor),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                    Text(
                      medication.form,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => onConfirmChanged?.call(!medication.confirmed),
                borderRadius: BorderRadius.circular(20),
                child: Icon(
                  medication.confirmed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: medication.confirmed
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(icon: Icons.local_pharmacy_outlined, label: 'Dose', value: medication.dose),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.event_repeat, label: 'Frequency', value: medication.frequency),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.schedule, label: 'Timing', value: medication.timing),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
      ],
    );
  }
}
