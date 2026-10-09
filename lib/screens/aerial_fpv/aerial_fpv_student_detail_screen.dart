import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../utils/document_launcher.dart';
import 'aerial_fpv_student_list_screen.dart';

class AerialFpvStudentDetailScreen extends StatelessWidget {
  final String docId;
  final String category; // 'aerial' | 'fpv'
  const AerialFpvStudentDetailScreen({
    super.key,
    required this.docId,
    required this.category,
  });

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection(kAerialFpvCollection).doc(docId);

  Future<void> _open(BuildContext context, String url) async {
    final ok = await DocumentLauncher.open(url);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Document open aagala')));
    }
  }

  Future<void> _removeDoc(BuildContext context, Map<String, dynamic> e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove document?'),
        content: Text('"${e['title'] ?? 'Document'}" remove aagidum.'),
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

  Future<void> _deleteStudent(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete student?'),
        content:
        const Text('Student details + documents ellam delete aagidum.'),
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
      if (context.mounted) Navigator.pop(context);
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
    final accent = aerialFpvColor(category);

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
                  child: Text('Student not found',
                      style: TextStyle(color: c.textSecondary))),
            );
          }
          final doc = snap.data!;
          final d = doc.data()!;
          final docs = ((d['documents'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          Widget row(IconData icon, String label, String? value) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 17, color: accent),
                const SizedBox(width: 10),
                SizedBox(
                  width: 78,
                  child: Text(label,
                      style: GoogleFonts.plusJakartaSans(
                          color: c.textSecondary, fontSize: 12.5)),
                ),
                Expanded(
                  child: Text(
                    (value == null || value.isEmpty) ? '-' : value,
                    style: GoogleFonts.plusJakartaSans(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          );

          return Scaffold(
            backgroundColor: c.background,
            body: CustomScrollView(
              slivers: [
                aerialFpvSliverAppBar(
                  c: c,
                  title: (d['name'] ?? 'Student').toString(),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit / upload documents',
                      onPressed: () => showStudentForm(context,
                          category: category, doc: doc),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: c.danger),
                      tooltip: 'Delete student',
                      onPressed: () => _deleteStudent(context),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ---------- Student details ----------
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.25)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              row(Icons.person_outline, 'Name',
                                  d['name']?.toString()),
                              row(Icons.phone_outlined, 'Phone',
                                  d['phone']?.toString()),
                              row(Icons.email_outlined, 'Email',
                                  d['email']?.toString()),
                              row(Icons.groups_outlined, 'Batch',
                                  d['batch']?.toString()),
                              row(Icons.notes, 'Notes', d['notes']?.toString()),
                              row(Icons.category_outlined, 'Category',
                                  aerialFpvLabel(category)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ---------- Documents ----------
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 16,
                              decoration: BoxDecoration(
                                  color: accent,
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
                        if (docs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'Documents illa. Top-la edit icon tap panni upload pannunga.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                    color: c.textSecondary, fontSize: 12.5),
                              ),
                            ),
                          ),
                        for (final e in docs)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.25)),
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(
                                    _iconFor(e['title']?.toString() ?? ''),
                                    color: accent,
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
                              onTap: () =>
                                  _open(context, (e['url'] ?? '').toString()),
                              trailing: IconButton(
                                icon: Icon(Icons.close, color: c.danger),
                                onPressed: () => _removeDoc(context, e),
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