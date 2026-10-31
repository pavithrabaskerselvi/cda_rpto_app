import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../utils/doc_upload_helper.dart';
import '../../utils/document_launcher.dart';
import '../aerial_fpv/aerial_fpv_student_list_screen.dart'
    show aerialFpvSliverAppBar, aerialFpvThemed;

const Color kZoneColor = Color(0xFFE67E22);

/// Firestore collection: one document per uploaded file.
const String kZoneDocsCollection = 'zone_documents';

/// Optional tags for an upload (all optional - can be skipped).
const List<String> kZoneCategories = [
  'Certificate',
  'License',
  'Permission',
  'Agreement',
  'Other',
];

class _ZoneDetails {
  final String name;
  final String? category;
  final String note;
  const _ZoneDetails({this.name = '', this.category, this.note = ''});
}

/// Zone = a simple document upload screen. Upload PDF / JPG / PNG / DOC /
/// DOCX (max 10 MB each); every file is saved the moment it finishes.
class ZoneHomeScreen extends StatefulWidget {
  const ZoneHomeScreen({super.key});

  @override
  State<ZoneHomeScreen> createState() => _ZoneHomeScreenState();
}

class _ZoneHomeScreenState extends State<ZoneHomeScreen> {
  final List<String> _uploading = [];

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(kZoneDocsCollection);

  /// Optional details shown after the files are picked.
  /// "Skip" uploads the files exactly as before (nothing is required).
  Future<_ZoneDetails?> _askDetails(int fileCount) async {
    final c = CompanyColors.of(context.read<ThemeProvider>().isDarkMode);
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? category;

    InputDecoration dec(String label) {
      OutlineInputBorder b(Color col) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: col),
      );
      return InputDecoration(
        labelText: label,
        labelStyle:
        GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 13),
        filled: true,
        fillColor: c.surfaceElevated,
        isDense: true,
        border: b(kZoneColor.withValues(alpha: 0.2)),
        enabledBorder: b(kZoneColor.withValues(alpha: 0.2)),
        focusedBorder: b(kZoneColor),
      );
    }

    final result = await showModalBottomSheet<_ZoneDetails>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    fileCount == 1
                        ? 'Document details'
                        : '$fileCount documents selected',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary)),
                const SizedBox(height: 2),
                Text('All optional - you can skip.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: c.textSecondary)),
                const SizedBox(height: 14),
                if (fileCount == 1) ...[
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: c.textPrimary),
                    decoration: dec('Document name (optional)'),
                  ),
                  const SizedBox(height: 10),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final cat in kZoneCategories)
                      ChoiceChip(
                        label: Text(cat),
                        selected: category == cat,
                        selectedColor: kZoneColor.withValues(alpha: 0.2),
                        onSelected: (v) =>
                            setS(() => category = v ? cat : null),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  style: TextStyle(color: c.textPrimary),
                  decoration: dec('Note (optional)'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.pop(ctx, const _ZoneDetails()),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                              color: kZoneColor.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Skip',
                            style: GoogleFonts.plusJakartaSans(
                                color: kZoneColor,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(
                          ctx,
                          _ZoneDetails(
                            name: nameCtrl.text.trim(),
                            category: category,
                            note: noteCtrl.text.trim(),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kZoneColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Upload',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return result; // null = sheet dismissed -> upload is cancelled
  }

  Future<void> _pickAndUpload() async {
    final messenger = ScaffoldMessenger.of(context);
    final files = await DocUploadHelper.pickFiles();
    if (files.isEmpty) return;
    if (!mounted) return;

    final details = await _askDetails(files.length);
    if (details == null) return; // dismissed - nothing uploaded

    for (final f in files) {
      final bytes = f.bytes;
      if (bytes == null) {
        messenger.showSnackBar(
            SnackBar(content: Text('Could not read "${f.name}"')));
        continue;
      }
      if (bytes.length > DocUploadHelper.maxBytes) {
        messenger.showSnackBar(
            SnackBar(content: Text('"${f.name}" is over 10 MB - skipped')));
        continue;
      }

      setState(() => _uploading.add(f.name));
      try {
        final url = await DocUploadHelper.upload(
          bytes: bytes,
          fileName: f.name,
          folder: 'rpto_uploads/zone',
        );
        await _col.add({
          'title': (files.length == 1 && details.name.isNotEmpty)
              ? details.name
              : f.name,
          'url': url,
          'size': bytes.length,
          'uploadedAt': DateTime.now().toIso8601String(),
          // optional - only saved when filled in
          if (details.category != null) 'category': details.category,
          if (details.note.isNotEmpty) 'note': details.note,
        });
      } catch (e) {
        messenger.showSnackBar(SnackBar(
            duration: const Duration(seconds: 6),
            content: Text('Upload failed (${f.name}): $e')));
      } finally {
        if (mounted) setState(() => _uploading.remove(f.name));
      }
    }
  }

  Future<void> _open(String url) async {
    final ok = await DocumentLauncher.open(url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document')));
    }
  }

  Future<void> _remove(DocumentSnapshot<Map<String, dynamic>> d) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove document?'),
        content: Text('"${d.data()?['title'] ?? 'Document'}" will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (yes == true) await d.reference.delete();
  }

  String _size(dynamic bytes) {
    if (bytes is! int) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// "Certificate  •  240 KB  •  note" - only the parts that exist.
  String _subtitle(Map<String, dynamic> d) {
    final parts = <String>[
      if ((d['category'] ?? '').toString().isNotEmpty) d['category'].toString(),
      if (_size(d['size']).isNotEmpty) _size(d['size']),
      if ((d['note'] ?? '').toString().isNotEmpty) d['note'].toString(),
    ];
    return parts.join('  •  ');
  }

  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png')) {
      return Icons.image_outlined;
    }
    return Icons.description_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final c = CompanyColors.of(context.watch<ThemeProvider>().isDarkMode);

    return aerialFpvThemed(
      context,
      Scaffold(
        backgroundColor: c.background,
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _col.snapshots(),
          builder: (context, snap) {
            final docs = (snap.data?.docs ?? [])
                .toList()
              ..sort((a, b) => (b.data()['uploadedAt'] ?? '')
                  .toString()
                  .compareTo((a.data()['uploadedAt'] ?? '').toString()));

            return CustomScrollView(
              slivers: [
                aerialFpvSliverAppBar(c: c, title: 'Zone'),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                                color: kZoneColor,
                                borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(width: 8),
                          Text('DOCUMENTS (${docs.length})',
                              style: GoogleFonts.plusJakartaSans(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                          _uploading.isNotEmpty ? null : _pickAndUpload,
                          icon: const Icon(Icons.upload_file, color: kZoneColor),
                          label: Text('Upload Documents',
                              style: GoogleFonts.plusJakartaSans(
                                  color: kZoneColor,
                                  fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: kZoneColor.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 12),
                        child: Text(
                            'PDF, JPG, PNG, DOC, DOCX (max 10 MB each)',
                            style: GoogleFonts.plusJakartaSans(
                                color: c.textSecondary, fontSize: 11)),
                      ),
                      if (snap.hasError)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('Error: ${snap.error}',
                              style: TextStyle(color: c.danger)),
                        ),
                      for (final name in _uploading)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: kZoneColor.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Uploading $name...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                      color: c.textSecondary, fontSize: 12)),
                              const SizedBox(height: 6),
                              const LinearProgressIndicator(color: kZoneColor),
                            ],
                          ),
                        ),
                      if (docs.isEmpty && _uploading.isEmpty && !snap.hasError)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text('No documents yet.',
                                style: GoogleFonts.plusJakartaSans(
                                    color: c.textSecondary, fontSize: 12.5)),
                          ),
                        ),
                      for (final d in docs)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: kZoneColor.withValues(alpha: 0.25)),
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: kZoneColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                  _iconFor(d.data()['title']?.toString() ?? ''),
                                  color: kZoneColor,
                                  size: 19),
                            ),
                            title: Text(
                                d.data()['title']?.toString() ?? 'Document',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5)),
                            subtitle: _subtitle(d.data()).isEmpty
                                ? null
                                : Text(_subtitle(d.data()),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                    color: c.textSecondary,
                                    fontSize: 11.5)),
                            onTap: () =>
                                _open((d.data()['url'] ?? '').toString()),
                            trailing: IconButton(
                              icon: Icon(Icons.close, color: c.danger),
                              onPressed: () => _remove(d),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}