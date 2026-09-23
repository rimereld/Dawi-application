import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/api_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../ai/ai_assistant_screen.dart';
import '../appointments/appointments_screen.dart';
import '../documents/document_details_screen.dart';
import '../documents/ocr_analysis_screen.dart';
import '../medications/medications_screen.dart';

class _DashboardData {
  final List<ApiMedication> activeMedications;
  final List<ApiAppointment> upcomingAppointments;
  final List<ApiDocument> recentDocuments;
  _DashboardData({required this.activeMedications, required this.upcomingAppointments, required this.recentDocuments});
}

/// Main Home / Health Dashboard (spec section 5).
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => HomeDashboardScreenState();
}

class HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final ImagePicker _picker = ImagePicker();
  late Future<_DashboardData> _future;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final results = await Future.wait([
      apiService.listMedications(status: 'active'),
      apiService.listAppointments(status: 'upcoming'),
      apiService.listDocuments(),
    ]);
    return _DashboardData(
      activeMedications: results[0] as List<ApiMedication>,
      upcomingAppointments: results[1] as List<ApiAppointment>,
      recentDocuments: (results[2] as List<ApiDocument>).take(3).toList(),
    );
  }

  void refresh() => setState(() => _future = _load());

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(source: source, imageQuality: 90, maxWidth: 2000);
      if (picked == null) return;
      setState(() => _isUploading = true);
      final result = await apiService.scanDocument(picked);
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => OcrAnalysisScreen(scanResult: result)),
      );
      if (saved == true) refresh();
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Could not access camera/gallery: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  void _showScanUploadSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
            title: const Text('Scan document'),
            onTap: () {
              Navigator.pop(context);
              _pickAndScan(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined, color: AppColors.primary),
            title: const Text('Upload from gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickAndScan(ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final firstName = user?.firstName.isNotEmpty == true ? user!.firstName : 'there';
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');

    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          RefreshIndicator(
            onRefresh: () async => refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$greeting, $firstName', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.lg),
                  FutureBuilder<_DashboardData>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: Text("Couldn't load your dashboard.\n${snapshot.error}",
                              style: const TextStyle(color: AppColors.textSecondary)),
                        );
                      }
                      final data = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Health overview cards
                          Row(children: [
                            Expanded(child: _OverviewCard(icon: Icons.medication_outlined, label: 'Active treatments', value: '${data.activeMedications.length}')),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: _OverviewCard(icon: Icons.event_outlined, label: 'Upcoming appointments', value: '${data.upcomingAppointments.length}')),
                          ]),
                          const SizedBox(height: AppSpacing.sm),
                          Row(children: [
                            Expanded(child: _OverviewCard(icon: Icons.description_outlined, label: 'Recent documents', value: '${data.recentDocuments.length}')),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: _OverviewCard(icon: Icons.science_outlined, label: 'Recent analyses', value: '—')),
                          ]),
                          const SizedBox(height: AppSpacing.lg),

                          // Health alerts (only from validated data)
                          if (data.upcomingAppointments.isNotEmpty) ...[
                            _AlertBanner(
                              text: 'Your ${data.upcomingAppointments.first.specialty.isEmpty ? 'appointment' : data.upcomingAppointments.first.specialty} '
                                  'is on ${data.upcomingAppointments.first.date} at ${data.upcomingAppointments.first.time}.',
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],

                          // Quick actions
                          const Text('Quick actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                            _QuickAction(icon: Icons.photo_camera_outlined, label: 'Scan document', onTap: _isUploading ? null : _showScanUploadSheet),
                            _QuickAction(
                              icon: Icons.smart_toy_outlined,
                              label: 'Ask AI',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantScreen())),
                            ),
                            _QuickAction(
                              icon: Icons.medication_outlined,
                              label: 'Add medication',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicationsScreen())),
                            ),
                            _QuickAction(
                              icon: Icons.event_outlined,
                              label: 'Add appointment',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentsScreen())),
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.lg),

                          // Today's reminders (derived from active meds / upcoming appts)
                          const Text("Today's reminders", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: AppSpacing.sm),
                          if (data.activeMedications.isEmpty && data.upcomingAppointments.isEmpty)
                            const Text('Nothing scheduled for today.', style: TextStyle(color: AppColors.textSecondary))
                          else ...[
                            ...data.activeMedications.take(3).map((m) => _ReminderTile(
                                  icon: Icons.medication_outlined,
                                  title: m.name,
                                  subtitle: '${m.timing} · ${m.frequency}',
                                )),
                            ...data.upcomingAppointments.take(2).map((a) => _ReminderTile(
                                  icon: Icons.event_outlined,
                                  title: a.specialty.isEmpty ? 'Appointment' : a.specialty,
                                  subtitle: '${a.date} ${a.time}',
                                )),
                          ],
                          const SizedBox(height: AppSpacing.lg),

                          // Recent activity (recent documents)
                          const Text('Recent activity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: AppSpacing.sm),
                          if (data.recentDocuments.isEmpty)
                            const Text('No recent activity yet — scan your first document to get started.',
                                style: TextStyle(color: AppColors.textSecondary))
                          else
                            ...data.recentDocuments.map((d) => InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => DocumentDetailsScreen(documentId: d.id)),
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    decoration: BoxDecoration(
                                        color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
                                    child: Row(children: [
                                      const Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          d.aiSummary.isNotEmpty ? d.aiSummary : '${d.documentType} added',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ]),
                                  ),
                                )),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.35),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(),
                      SizedBox(height: AppSpacing.md),
                      Text('Analyzing your document...'),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _OverviewCard({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        ]),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ]),
        ),
      );
}

class _ReminderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _ReminderTile({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
      );
}

class _AlertBanner extends StatelessWidget {
  final String text;
  const _AlertBanner({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.notifications_active_outlined, color: Color(0xFFE7A23B), size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
        ]),
      );
}
