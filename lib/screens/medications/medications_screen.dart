import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import 'medication_details_screen.dart';

/// Medications page (spec section 13): active / completed / upcoming tabs,
/// plus a standalone "Add medication" flow not tied to a scanned document.
class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => MedicationsScreenState();
}

class MedicationsScreenState extends State<MedicationsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);
  late Future<List<ApiMedication>> _future;

  @override
  void initState() {
    super.initState();
    _future = apiService.listMedications();
  }

  void refresh() => setState(() => _future = apiService.listMedications());

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addMedication() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const _AddMedicationSheet(),
    );
    if (result == true) refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medications'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Active'), Tab(text: 'Completed'), Tab(text: 'Upcoming')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMedication,
        icon: const Icon(Icons.add),
        label: const Text('Add medication'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => refresh(),
          child: FutureBuilder<List<ApiMedication>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(children: [EmptyState(icon: Icons.cloud_off, message: "Couldn't load medications.")]);
              }
              final all = snapshot.data ?? [];
              return TabBarView(
                controller: _tabController,
                children: [
                  _MedicationList(medications: all.where((m) => m.status == MedicationStatus.active).toList()),
                  _MedicationList(medications: all.where((m) => m.status == MedicationStatus.completed).toList()),
                  _MedicationList(medications: all.where((m) => m.status == MedicationStatus.upcoming).toList()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MedicationList extends StatelessWidget {
  final List<ApiMedication> medications;
  const _MedicationList({required this.medications});

  @override
  Widget build(BuildContext context) {
    if (medications.isEmpty) {
      return ListView(children: const [EmptyState(icon: Icons.medication_outlined, message: 'No medications here yet.')]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
      itemCount: medications.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final m = medications[i];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MedicationDetailsScreen(medicationId: m.id!)),
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration:
                BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${m.dose} · ${m.frequency}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ]),
          ),
        );
      },
    );
  }
}

class _AddMedicationSheet extends StatefulWidget {
  const _AddMedicationSheet();

  @override
  State<_AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<_AddMedicationSheet> {
  final _nameController = TextEditingController();
  final _doseController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _timingController = TextEditingController();
  String _status = MedicationStatus.active;
  bool _isSaving = false;

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await apiService.createMedication(ApiMedication(
        name: _nameController.text.trim(),
        form: '',
        dose: _doseController.text.trim(),
        frequency: _frequencyController.text.trim(),
        timing: _timingController.text.trim(),
        status: _status,
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
          const Text('Add medication', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: AppSpacing.md),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Medication name')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _doseController, decoration: const InputDecoration(labelText: 'Dose')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _frequencyController, decoration: const InputDecoration(labelText: 'Frequency')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _timingController, decoration: const InputDecoration(labelText: 'Timing')),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: MedicationStatus.all
                .map((s) => DropdownMenuItem(value: s, child: Text(MedicationStatus.label(s))))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
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
