import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/api_models.dart';
import '../../models/medication.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/medication_card.dart';
import '../ai/ai_assistant_screen.dart';
import '../ai/ai_explanation_screen.dart';

/// Full detail view for one document (spec section 10): preview, type,
/// date, doctor, extracted info, and entry points into the AI Explanation
/// and AI Assistant (grounded in this document).
class DocumentDetailsScreen extends StatefulWidget {
  final String documentId;
  const DocumentDetailsScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  late Future<ApiDocument> _future;

  @override
  void initState() {
    super.initState();
    _future = apiService.getDocument(widget.documentId);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text('This will remove the document and its extracted medications.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await apiService.deleteDocument(widget.documentId);
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
        title: const Text('Document details'),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<ApiDocument>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text("Couldn't load this document.\n${snapshot.error ?? ''}",
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                ),
              );
            }

            final d = snapshot.data!;
            final imageUrl = apiService.resolveImageUrl(d.fileUrl);
            final medications = d.medications.map(Medication.fromApi).toList();
            final dateStr = d.documentDate.isNotEmpty
                ? d.documentDate
                : DateFormat('d MMMM yyyy').format(d.createdAt);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                                height: 200,
                                color: AppColors.chipBackground,
                                child: const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
                              )),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _DetailRow(icon: Icons.description_outlined, label: 'Type', value: DocumentTypes.label(d.documentType)),
                      const SizedBox(height: 10),
                      _DetailRow(icon: Icons.badge_outlined, label: 'Doctor', value: d.doctorName.isEmpty ? 'Unknown' : d.doctorName),
                      const SizedBox(height: 10),
                      _DetailRow(icon: Icons.local_hospital_outlined, label: 'Clinic', value: d.clinicName.isEmpty ? 'Unknown' : d.clinicName),
                      const SizedBox(height: 10),
                      _DetailRow(icon: Icons.calendar_today_outlined, label: 'Date', value: dateStr),
                    ]),
                  ),
                  if (d.aiSummary.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(d.aiSummary, style: const TextStyle(fontSize: 13.5, height: 1.4))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                        label: const Text('AI Explanation'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AiExplanationScreen(document: d)),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.smart_toy_outlined, size: 18),
                        label: const Text('Ask AI'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AiAssistantScreen(documentId: d.id)),
                        ),
                      ),
                    ),
                  ]),
                  if (medications.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Medications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: AppSpacing.md),
                    ...medications.map((m) => MedicationCard(medication: m)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
      const SizedBox(width: AppSpacing.sm),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
      const Spacer(),
      Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
    ]);
  }
}
