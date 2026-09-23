import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

/// Dedicated "AI Explanation" page (spec section 11): plain-language
/// explanation, medical term glossary, per-medication explanation,
/// important information, and suggested questions for the doctor.
class AiExplanationScreen extends StatefulWidget {
  final ApiDocument document;
  const AiExplanationScreen({super.key, required this.document});

  @override
  State<AiExplanationScreen> createState() => _AiExplanationScreenState();
}

class _AiExplanationScreenState extends State<AiExplanationScreen> {
  late Future<AiExplanationResult> _future;

  @override
  void initState() {
    super.initState();
    _future = apiService.explainDocument(widget.document.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Explanation')),
      body: SafeArea(
        child: FutureBuilder<AiExplanationResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(),
                    SizedBox(height: AppSpacing.md),
                    Text('Reading your document...'),
                  ]),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text("The AI assistant is temporarily unavailable.\n${snapshot.error}",
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                ),
              );
            }
            final result = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (result.simpleExplanation.isNotEmpty) ...[
                    _SectionTitle('Simple explanation'),
                    Text(result.simpleExplanation, style: const TextStyle(fontSize: 15, height: 1.5)),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (result.medicalTerms.isNotEmpty) ...[
                    _SectionTitle('Medical terms'),
                    ...result.medicalTerms.map((t) => _TermTile(term: t.term, explanation: t.explanation)),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (result.medicationExplanations.isNotEmpty) ...[
                    _SectionTitle('Medications'),
                    ...result.medicationExplanations.map((m) => Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (m.dosage.isNotEmpty || m.frequency.isNotEmpty || m.duration.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text([m.dosage, m.frequency, m.duration].where((s) => s.isNotEmpty).join(' · '),
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              ),
                            if (m.purpose.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(m.purpose, style: const TextStyle(fontSize: 13.5, height: 1.4)),
                              ),
                          ]),
                        )),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (result.importantInformation.isNotEmpty) ...[
                    _SectionTitle('Important information'),
                    ...result.importantInformation.map((s) => _BulletLine(text: s)),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (result.questionsForDoctor.isNotEmpty) ...[
                    _SectionTitle('Questions for your doctor'),
                    ...result.questionsForDoctor.map((s) => _BulletLine(text: s, icon: Icons.help_outline)),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: AppColors.chipBackground, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          result.disclaimer,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ]),
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      );
}

class _TermTile extends StatelessWidget {
  final String term;
  final String explanation;
  const _TermTile({required this.term, required this.explanation});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(term, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text(explanation, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4)),
        ]),
      );
}

class _BulletLine extends StatelessWidget {
  final String text;
  final IconData icon;
  const _BulletLine({required this.text, this.icon = Icons.priority_high});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.4))),
        ]),
      );
}
