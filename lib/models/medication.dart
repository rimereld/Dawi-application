import 'package:flutter/material.dart';
import 'api_models.dart';

/// A single medicine line item extracted from a scanned prescription.
class Medication {
  final String name;
  final String form; // e.g. Tablet, Capsule, Drops
  final String dose;
  final String frequency;
  final String timing;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  bool confirmed;

  Medication({
    required this.name,
    required this.form,
    required this.dose,
    required this.frequency,
    required this.timing,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    this.confirmed = true,
  });

  /// Builds a UI-ready [Medication] from data returned by the real backend,
  /// picking an icon/color based on the medication's form so
  /// [MedicationCard] can render it the same way as mock data.
  factory Medication.fromApi(ApiMedication m) {
    final formLower = m.form.toLowerCase();
    IconData icon = Icons.medication_outlined;
    Color bg = const Color(0xFFEAF1FE);
    Color fg = const Color(0xFF3B6FE0);

    if (formLower.contains('capsule')) {
      icon = Icons.medication;
      bg = const Color(0xFFE7F7EF);
      fg = const Color(0xFF2FB273);
    } else if (formLower.contains('drop')) {
      icon = Icons.water_drop_outlined;
      bg = const Color(0xFFF3ECFE);
      fg = const Color(0xFF8B6BF2);
    } else if (formLower.contains('syrup')) {
      icon = Icons.local_drink_outlined;
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE7A23B);
    } else if (formLower.contains('injection')) {
      icon = Icons.vaccines_outlined;
      bg = const Color(0xFFFDEBEE);
      fg = const Color(0xFFE0527A);
    } else if (m.timing.toLowerCase().contains('night')) {
      icon = Icons.nightlight_round;
      bg = const Color(0xFFF3ECFE);
      fg = const Color(0xFF8B6BF2);
    }

    return Medication(
      name: m.name,
      form: m.form,
      dose: m.dose,
      frequency: m.frequency,
      timing: m.timing,
      icon: icon,
      iconBackground: bg,
      iconColor: fg,
      confirmed: m.confirmed,
    );
  }
}
