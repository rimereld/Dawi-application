import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

/// Appointments page (spec section 16): upcoming/past appointments with
/// add/edit/cancel.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => AppointmentsScreenState();
}

class AppointmentsScreenState extends State<AppointmentsScreen> {
  late Future<List<ApiAppointment>> _future;

  @override
  void initState() {
    super.initState();
    _future = apiService.listAppointments();
  }

  void refresh() => setState(() => _future = apiService.listAppointments());

  Future<void> _addAppointment() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const _AddAppointmentSheet(),
    );
    if (result == true) refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAppointment,
        icon: const Icon(Icons.add),
        label: const Text('Add appointment'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => refresh(),
          child: FutureBuilder<List<ApiAppointment>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(children: const [EmptyState(icon: Icons.cloud_off, message: "Couldn't load appointments.")]);
              }
              final appointments = snapshot.data ?? [];
              if (appointments.isEmpty) {
                return ListView(children: const [EmptyState(icon: Icons.event_busy_outlined, message: 'No upcoming appointments.')]);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                itemCount: appointments.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) => _AppointmentCard(appointment: appointments[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final ApiAppointment appointment;
  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.event_outlined, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(appointment.specialty.isEmpty ? 'Appointment' : appointment.specialty, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${appointment.date} ${appointment.time}'.trim(), style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            if (appointment.location.isNotEmpty)
              Text(appointment.location, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ]),
        ),
        _StatusBadge(status: appointment.status),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = status == 'completed' ? AppColors.success : (status == 'cancelled' ? Colors.redAccent : AppColors.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _AddAppointmentSheet extends StatefulWidget {
  const _AddAppointmentSheet();
  @override
  State<_AddAppointmentSheet> createState() => _AddAppointmentSheetState();
}

class _AddAppointmentSheetState extends State<_AddAppointmentSheet> {
  final _specialtyController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _locationController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isSaving = false;

  Future<void> _save() async {
    if (_dateController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await apiService.createAppointment(ApiAppointment(
        specialty: _specialtyController.text.trim(),
        date: _dateController.text.trim(),
        time: _timeController.text.trim(),
        location: _locationController.text.trim(),
        reason: _reasonController.text.trim(),
      ));
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add appointment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: AppSpacing.md),
          TextField(controller: _specialtyController, decoration: const InputDecoration(labelText: 'Specialty / reason for visit')),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Expanded(child: TextField(controller: _dateController, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'))),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: TextField(controller: _timeController, decoration: const InputDecoration(labelText: 'Time (HH:MM)'))),
          ]),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _reasonController, decoration: const InputDecoration(labelText: 'Notes (optional)')),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
