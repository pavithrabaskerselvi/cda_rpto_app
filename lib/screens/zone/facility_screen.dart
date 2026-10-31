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
import 'zone_home_screen.dart' show kZoneColor;

const String kFacilityCollection = 'zone_facilities';

InputDecoration _dec(CompanyColors c, String label) {
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

/// Add (doc == null) or edit a facility's name / notes.
/// Documents are uploaded from the facility detail screen, where every
/// upload is saved to Firestore the moment it finishes.
Future<void> showFacilityForm(BuildContext context,
    {DocumentSnapshot<Map<String, dynamic>>? doc}) async {
  final c = CompanyColors.of(context.read<ThemeProvider>().isDarkMode);
  final data = doc?.data() ?? {};
  final name = TextEditingController(text: data['name']?.toString() ?? '');
  final notes = TextEditingController(text: data['notes']?.toString() ?? '');
  final formKey = GlobalKey<FormState>();
  final messenger = ScaffoldMessenger.of(context);
  var saving = false;

  await showModalBottomSheet(
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
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(doc == null ? 'Add Facility' : 'Edit Facility',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  style: TextStyle(color: c.textPrimary),
                  decoration: _dec(c, 'Facility name *'),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: notes,
                  maxLines: 3,
                  style: TextStyle(color: c.textPrimary),
                  decoration: _dec(c, 'Notes (optional)'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kZoneColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => saving = true);
                      try {
                        final col = FirebaseFirestore.instance
                            .collection(kFacilityCollection);
                        final payload = {
                          'name': name.text.trim(),
                          'notes': notes.text.trim(),
                        };
                        if (doc == null) {
                          await col.add({
                            ...payload,
                            'documents': <Map<String, dynamic>>[],
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        } else {
                          await col.doc(doc.id).update(payload);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        messenger.showSnackBar(
                            SnackBar(content: Text('Save failed: $e')));
                        if (ctx.mounted) setS(() => saving = false);
                      }
                    },
                    child: Text(
                        saving ? 'Saving...' : (doc == null ? 'Save' : 'Update'),
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------
// Facility list
// ---------------------------------------------------------------------
class FacilityScreen extends StatefulWidget {
  const FacilityScreen({super.key});

  @override
  State<FacilityScreen> createState() => _FacilityScreenState();
}

class _FacilityScreenState extends State<FacilityScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = CompanyColors.of(context.watch<ThemeProvider>().isDarkMode);

    return aerialFpvThemed(
      context,
      Scaffold(
        backgroundColor: c.background,
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: kZoneColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_business),
          label: Text('Add Facility',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          onPressed: () => showFacilityForm(context),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(kFacilityCollection)
              .snapshots(),
          builder: (context, snap) {
            Widget content;
            if (snap.hasError) {
              content = Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                    child: Text('Error: ${snap.error}',
                        style: TextStyle(color: c.danger))),
              );
            } else if (!snap.hasData) {
              content = const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            } else {
              final docs = snap.data!.docs.where((d) {
                final n = (d.data()['name'] ?? '').toString().toLowerCase();
                return _query.isEmpty || n.contains(_query);
              }).toList()
                ..sort((a, b) => (a.data()['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .compareTo((b.data()['name'] ?? '').toString().toLowerCase()));

              if (docs.isEmpty) {
                content = Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text('No facilities yet.\nTap "Add Facility".',
                        textAlign: TextAlign.center,
                        style:
                        GoogleFonts.plusJakartaSans(color: c.textSecondary)),
                  ),
                );
              } else {
                content = Column(
                  children: [
                    for (var i = 0; i < docs.length; i++) ...[
                      _FacilityTile(
                        index: i + 1,
                        data: docs[i].data(),
                        c: c,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                FacilityDetailScreen(docId: docs[i].id),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }
            }

            return CustomScrollView(
              slivers: [
                aerialFpvSliverAppBar(c: c, title: 'Facility'),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: TextField(
                      onChanged: (v) =>
                          setState(() => _query = v.trim().toLowerCase()),
                      style: GoogleFonts.plusJakartaSans(color: c.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search facility',
                        hintStyle:
                        GoogleFonts.plusJakartaSans(color: c.textSecondary),
                        prefixIcon: Icon(Icons.search, color: c.textSecondary),
                        filled: true,
                        fillColor: c.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: kZoneColor.withValues(alpha: 0.25)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: kZoneColor.withValues(alpha: 0.25)),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                    child: content,
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

class _FacilityTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> data;
  final CompanyColors c;
  final VoidCallback onTap;

  const _FacilityTile({
    required this.index,
    required this.data,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Unnamed').toString();
    final notes = (data['notes'] ?? '').toString();
    final docCount = ((data['documents'] as List?) ?? []).length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kZoneColor.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kZoneColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$index',
                  style: GoogleFonts.plusJakartaSans(
                      color: kZoneColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(notes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                            color: c.textSecondary, fontSize: 11.5)),
                  ],
                ],
              ),
            ),
            Icon(Icons.attach_file, size: 15, color: kZoneColor),
            const SizedBox(width: 2),
            Text('$docCount',
                style: GoogleFonts.plusJakartaSans(
                    color: kZoneColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Facility detail + document upload
// ---------------------------------------------------------------------
class FacilityDetailScreen extends StatefulWidget {
  final String docId;
  const FacilityDetailScreen({super.key, required this.docId});

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  final List<String> _uploading = []; // file names currently uploading

  DocumentReference<Map<String, dynamic>> get _ref => FirebaseFirestore
      .instance
      .collection(kFacilityCollection)
      .doc(widget.docId);

  Future<void> _pickAndUpload() async {
    final messenger = ScaffoldMessenger.of(context);
    final files = await DocUploadHelper.pickFiles();
    if (files.isEmpty) return;

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
          folder: 'rpto_uploads/zone/facility',
        );
        // Saved straight to Firestore, so the document is never lost
        // even if the person closes the screen right after.
        await _ref.update({
          'documents': FieldValue.arrayUnion([
            {
              'title': f.name,
              'url': url,
              'size': bytes.length,
              'uploadedAt': DateTime.now().toIso8601String(),
            }
          ]),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open document')));
    }
  }

  Future<void> _removeDoc(Map<String, dynamic> e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove document?'),
        content: Text('"${e['title'] ?? 'Document'}" will be removed.'),
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
    if (yes == true) {
      await _ref.update({
        'documents': FieldValue.arrayRemove([e]),
      });
    }
  }

  Future<void> _deleteFacility() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete facility?'),
        content: const Text('The facility and its documents will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (yes == true) {
      await _ref.delete();
      if (mounted) Navigator.pop(context);
    }
  }

  String _size(dynamic bytes) {
    if (bytes is! int) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return Scaffold(
              backgroundColor: c.background,
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (!snap.data!.exists) {
            return Scaffold(
              backgroundColor: c.background,
              appBar: AppBar(backgroundColor: c.background),
              body: Center(
                  child: Text('Facility not found',
                      style: TextStyle(color: c.textSecondary))),
            );
          }
          final doc = snap.data!;
          final d = doc.data()!;
          final docs = ((d['documents'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final notes = (d['notes'] ?? '').toString();

          return Scaffold(
            backgroundColor: c.background,
            body: CustomScrollView(
              slivers: [
                aerialFpvSliverAppBar(
                  c: c,
                  title: (d['name'] ?? 'Facility').toString(),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit facility',
                      onPressed: () => showFacilityForm(context, doc: doc),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: c.danger),
                      tooltip: 'Delete facility',
                      onPressed: _deleteFacility,
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (notes.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: kZoneColor.withValues(alpha: 0.25)),
                            ),
                            child: Text(notes,
                                style: GoogleFonts.plusJakartaSans(
                                    color: c.textPrimary, fontSize: 13)),
                          ),
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
                            icon: const Icon(Icons.upload_file,
                                color: kZoneColor),
                            label: Text('Upload Documents',
                                style: GoogleFonts.plusJakartaSans(
                                    color: kZoneColor,
                                    fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: kZoneColor.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 10),
                          child: Text('PDF, JPG, PNG, DOC, DOCX (max 10 MB each)',
                              style: GoogleFonts.plusJakartaSans(
                                  color: c.textSecondary, fontSize: 11)),
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
                        if (docs.isEmpty && _uploading.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text('No documents yet.',
                                  style: GoogleFonts.plusJakartaSans(
                                      color: c.textSecondary, fontSize: 12.5)),
                            ),
                          ),
                        for (final e in docs)
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
                                    _iconFor(e['title']?.toString() ?? ''),
                                    color: kZoneColor,
                                    size: 19),
                              ),
                              title: Text(e['title']?.toString() ?? 'Document',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                      color: c.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5)),
                              subtitle: _size(e['size']).isEmpty
                                  ? null
                                  : Text(_size(e['size']),
                                  style: GoogleFonts.plusJakartaSans(
                                      color: c.textSecondary,
                                      fontSize: 11.5)),
                              onTap: () => _open((e['url'] ?? '').toString()),
                              trailing: IconButton(
                                icon: Icon(Icons.close, color: c.danger),
                                onPressed: () => _removeDoc(e),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
