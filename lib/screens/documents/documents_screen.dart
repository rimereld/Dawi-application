import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import 'document_details_screen.dart';
import 'ocr_analysis_screen.dart';

/// Central document management page (spec section 6): categorized list,
/// search-free filter chips, and a scan/upload entry point.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => DocumentsScreenState();
}

class DocumentsScreenState extends State<DocumentsScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _typeFilter;
  late Future<List<ApiDocument>> _future;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _future = apiService.listDocuments();
  }

  /// Public so other screens (e.g. the home dashboard's quick actions) can
  /// trigger the same scan/upload flow via a GlobalKey, if desired.
  void refresh() => setState(() => _future = apiService.listDocuments(documentType: _typeFilter));

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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  void _showScanUploadSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Scan document'),
              subtitle: const Text('Use your camera'),
              onTap: () {
                Navigator.pop(context);
                _pickAndScan(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: AppColors.primary),
              title: const Text('Upload from gallery'),
              subtitle: const Text('Photos, JPG or PNG'),
              onTap: () {
                Navigator.pop(context);
                _pickAndScan(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _showScanUploadSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add document'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    children: [
                      _FilterChip(label: 'All', selected: _typeFilter == null, onTap: () {
                        setState(() => _typeFilter = null);
                        refresh();
                      }),
                      ...DocumentTypes.all.map((t) => Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.sm),
                            child: _FilterChip(
                              label: DocumentTypes.label(t),
                              selected: _typeFilter == t,
                              onTap: () {
                                setState(() => _typeFilter = t);
                                refresh();
                              },
                            ),
                          )),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => refresh(),
                    child: FutureBuilder<List<ApiDocument>>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return ListView(children: [
                            EmptyState(icon: Icons.cloud_off, message: "Couldn't load documents.\n${snapshot.error}"),
                          ]);
                        }
                        final docs = snapshot.data ?? [];
                        if (docs.isEmpty) {
                          return ListView(children: const [
                            EmptyState(icon: Icons.folder_open_outlined, message: 'No medical documents yet.'),
                          ]);
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) => _DocumentCard(document: docs[i]),
                        );
                      },
                    ),
                  ),
                ),
              ],
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
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryLight,
      labelStyle: TextStyle(color: selected ? AppColors.primary : AppColors.textPrimary, fontWeight: FontWeight.w600),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final ApiDocument document;
  const _DocumentCard({required this.document});

  @override
  Widget build(BuildContext context) {
    final imageUrl = apiService.resolveImageUrl(document.fileUrl);
    final dateStr = document.documentDate.isNotEmpty
        ? document.documentDate
        : DateFormat('d MMM yyyy').format(document.createdAt);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DocumentDetailsScreen(documentId: document.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: imageUrl.isEmpty
                    ? Container(color: AppColors.chipBackground, child: const Icon(Icons.description_outlined))
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.chipBackground,
                          child: const Icon(Icons.description_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DocumentTypes.label(document.documentType),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    document.doctorName.isEmpty ? dateStr : '${document.doctorName} · $dateStr',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
