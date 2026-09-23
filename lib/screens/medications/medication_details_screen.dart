import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

/// Medication details page (spec section 14): dosage/instructions plus a
/// reminder-time picker. NOTE: reminder scheduling here is UI-only for now
/// — wiring up local notifications (e.g. via `flutter_local_notifications`)
/// is a natural next step once this screen is in place.
class MedicationDetailsScreen extends StatefulWidget {
  final String medicationId;
  const MedicationDetailsScreen({super.key, required this.medicationId});

  @override
  State<MedicationDetailsScreen> createState() => _MedicationDetailsScreenState();
}

class _MedicationDetailsScreenState extends State<MedicationDetailsScreen> {
  late Future<ApiMedication> _future;
  final Set<String> _reminderTimes = {};

  @override
  void initState() {
    super.initState();
    _future = apiService.getMedication(widget.medicationId);
  }

  Future<void> _delete() async {
    try {
      await apiService.deleteMedication(widget.medicationId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication details'),
        actions: [IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: SafeArea(
        child: FutureBuilder<ApiMedication>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text("Couldn't load this medication."));
            }
            final m = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(MedicationStatus.label(m.status), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
                    child: Column(children: [
                      _Row(label: 'Dose', value: m.dose),
                      const SizedBox(height: 10),
                      _Row(label: 'Frequency', value: m.frequency),
                      const SizedBox(height: 10),
                      _Row(label: 'Timing', value: m.timing),
                      if (m.doctorName.isNotEmpty) ...[const SizedBox(height: 10), _Row(label: 'Prescribed by', value: m.doctorName)],
                      if (m.startDate.isNotEmpty) ...[const SizedBox(height: 10), _Row(label: 'Start date', value: m.startDate)],
                      if (m.endDate.isNotEmpty) ...[const SizedBox(height: 10), _Row(label: 'End date', value: m.endDate)],
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text('Reminder schedule', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    children: ['Morning', 'Afternoon', 'Evening', 'Custom'].map((slot) {
                      final selected = _reminderTimes.contains(slot);
                      return FilterChip(
                        label: Text(slot),
                        selected: selected,
                        onSelected: (v) => setState(() => v ? _reminderTimes.add(slot) : _reminderTimes.remove(slot)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: _reminderTimes.isEmpty
                        ? null
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Reminder set for: ${_reminderTimes.join(', ')}')),
                            ),
                    icon: const Icon(Icons.alarm_add_outlined),
                    label: const Text('Create reminder'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
        Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]);
}
