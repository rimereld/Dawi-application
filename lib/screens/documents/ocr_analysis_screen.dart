import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/api_models.dart';
import '../../models/medication.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/medication_card.dart';

/// Shows the AI-extracted info from a just-scanned document (spec section
/// 9: "OCR / Document Analysis") so the user can review/edit before it's
/// saved. Low-confidence fields aren't separately flagged here since the
/// backend doesn't yet return per-field confidence — everything shown is
/// editable, which serves the same "verify before you trust it" purpose.
class OcrAnalysisScreen extends StatefulWidget {
  final ScanResult scanResult;
  const OcrAnalysisScreen({super.key, required this.scanResult});

  @override
  State<OcrAnalysisScreen> createState() => _OcrAnalysisScreenState();
}

class _OcrAnalysisScreenState extends State<OcrAnalysisScreen> {
  late List<Medication> _medications;
  late TextEditingController _doctorController;
  late TextEditingController _clinicController;
  late TextEditingController _dateController;
  late String _documentType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _medications = widget.scanResult.medications.map(Medication.fromApi).toList();
    _doctorController = TextEditingController(text: widget.scanResult.doctorName);
    _clinicController = TextEditingController(text: widget.scanResult.clinicName);
    _dateController = TextEditingController();
    _documentType = widget.scanResult.documentType;
  }

  @override
  void dispose() {
    _doctorController.dispose();
    _clinicController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await apiService.confirmDocument(
        documentId: widget.scanResult.documentId,
        documentType: _documentType,
        doctorName: _doctorController.text.trim(),
        clinicName: _clinicController.text.trim(),
        documentDate: _dateController.text.trim(),
        medications: _medications
            .map((m) => ApiMedication(
                  name: m.name,
                  form: m.form,
                  dose: m.dose,
                  frequency: m.frequency,
                  timing: m.timing,
                  confirmed: m.confirmed,
                ))
            .toList(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: ${e.message}'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = apiService.resolveImageUrl(widget.scanResult.fileUrl);

    return Scaffold(
      appBar: AppBar(title: const Text('Analyzing your document')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            height: 180,
                            color: AppColors.chipBackground,
                            child: const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
                          )),
                ),
              const SizedBox(height: AppSpacing.md),
              if (widget.scanResult.aiSummary.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: Text(widget.scanResult.aiSummary, style: const TextStyle(fontSize: 13.5, height: 1.4))),
                  ]),
                ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: _documentType,
                decoration: const InputDecoration(labelText: 'Document type'),
                items: DocumentTypes.all
                    .map((t) => DropdownMenuItem(value: t, child: Text(DocumentTypes.label(t))))
                    .toList(),
                onChanged: (v) => setState(() => _documentType = v ?? _documentType),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _doctorController,
                decoration: const InputDecoration(labelText: 'Doctor', prefixIcon: Icon(Icons.badge_outlined)),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _clinicController,
                decoration:
                    const InputDecoration(labelText: 'Clinic / hospital', prefixIcon: Icon(Icons.local_hospital_outlined)),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _dateController,
                decoration:
                    const InputDecoration(labelText: 'Date (optional, YYYY-MM-DD)', prefixIcon: Icon(Icons.calendar_today_outlined)),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_medications.isNotEmpty) ...[
                const Text('Extracted medications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: AppSpacing.md),
                ..._medications.map(
                  (m) => MedicationCard(medication: m, onConfirmChanged: (val) => setState(() => m.confirmed = val)),
                ),
              ] else
                const Text(
                  'No medications were detected in this document. You can still save it.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirm information'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
