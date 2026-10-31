import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import 'aerial_fpv_student_list_screen.dart';

/// Bulk add students for Aerial or FPV (same idea as Bulk Batch Setup).
///
/// Enter Course Name + Status once, paste every student name (one per
/// line, e.g. straight from a Drive folder listing like "01. ARUN K"),
/// then Save. One student document is created per line.
class AerialFpvBulkAddScreen extends StatefulWidget {
  final String category; // 'aerial' | 'fpv'
  final int? year; // year chosen before; null = No year
  const AerialFpvBulkAddScreen({super.key, required this.category, this.year});

  @override
  State<AerialFpvBulkAddScreen> createState() => _AerialFpvBulkAddScreenState();
}

class _AerialFpvBulkAddScreenState extends State<AerialFpvBulkAddScreen> {
  final _courseName = TextEditingController();
  final _names = TextEditingController();
  String _status = 'Ongoing';
  bool _saving = false;

  int get _year => widget.year ?? 0;

  @override
  void dispose() {
    _courseName.dispose();
    _names.dispose();
    super.dispose();
  }

  /// One name per non-empty line; leading "01. " / "1) " / "1 - "
  /// numbering is stripped. Duplicates inside the paste are removed.
  List<String> get _parsedNames {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in _names.text.split('\n')) {
      final line = raw
          .trim()
          .replaceFirst(RegExp(r'^\d+\s*[\.\)\-]\s*'), '')
          .trim();
      if (line.isEmpty) continue;
      if (seen.add(line.toLowerCase())) out.add(line);
    }
    return out;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final names = _parsedNames;
    if (names.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Paste at least one student name')));
      return;
    }

    setState(() => _saving = true);
    try {
      final fs = FirebaseFirestore.instance;
      final col = fs.collection(kAerialFpvCollection);

      // Skip students that already exist in this category + year.
      final existing = await col
          .where('category', isEqualTo: widget.category)
          .get();
      final existingNames = existing.docs
          .where((d) => aerialFpvYearOf(d.data()) == _year)
          .map((d) => (d.data()['name'] ?? '').toString().trim().toLowerCase())
          .toSet();
      final toAdd =
      names.where((n) => !existingNames.contains(n.toLowerCase())).toList();
      final skipped = names.length - toAdd.length;

      var added = 0;
      var failed = 0;
      const chunkSize = 400; // Firestore batch limit is 500
      for (var i = 0; i < toAdd.length; i += chunkSize) {
        final chunk = toAdd.skip(i).take(chunkSize).toList();
        final wb = fs.batch();
        for (final name in chunk) {
          wb.set(col.doc(), {
            'name': name,
            'regNo': '',
            'phone': '',
            'email': '',
            'address': '',
            'courseName': _courseName.text.trim(),
            'status': _status,
            'year': _year,
            'notes': '',
            'documents': <Map<String, dynamic>>[],
            'category': widget.category,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        try {
          await wb.commit();
          added += chunk.length;
        } catch (_) {
          failed += chunk.length;
        }
      }

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bulk add finished'),
          content: Text(
            '$added student${added == 1 ? '' : 's'} added'
                '${skipped > 0 ? '\n$skipped skipped (already in the list)' : ''}'
                '${failed > 0 ? '\n$failed failed - try again for those' : ''}',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      );
      if (mounted && failed == 0) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Bulk add failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = CompanyColors.of(context.watch<ThemeProvider>().isDarkMode);
    final accent = aerialFpvColor(widget.category);
    final label = aerialFpvLabel(widget.category);
    final names = _parsedNames;

    OutlineInputBorder b(Color col) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: col),
    );
    InputDecoration dec(String l, {String? hint}) => InputDecoration(
      labelText: l,
      hintText: hint,
      alignLabelWithHint: true,
      labelStyle:
      GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 13),
      hintStyle:
      GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 12),
      filled: true,
      fillColor: c.surfaceElevated,
      border: b(accent.withValues(alpha: 0.2)),
      enabledBorder: b(accent.withValues(alpha: 0.2)),
      focusedBorder: b(accent),
    );

    return aerialFpvThemed(
      context,
      Scaffold(
        backgroundColor: c.background,
        body: CustomScrollView(
          slivers: [
            aerialFpvSliverAppBar(c: c, title: 'Bulk Add $label Students'),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Year: ${_year == 0 ? 'No year' : _year}. Set Course Name and Status once, paste every '
                                'student name (one per line), then Save. Reg No, '
                                'phone and address can be filled later by editing '
                                'each student.',
                            style: GoogleFonts.plusJakartaSans(
                                color: c.textSecondary, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _courseName,
                    style: TextStyle(color: c.textPrimary),
                    decoration: dec('Course Name (applied to all)'),
                  ),
                  const SizedBox(height: 14),
                  Text('STATUS (applied to all)',
                      style: GoogleFonts.plusJakartaSans(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final st in kAerialFpvStatuses)
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => setState(() => _status = st),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _status == st
                                  ? aerialFpvStatusColor(st)
                                  : aerialFpvStatusColor(st)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: aerialFpvStatusColor(st).withValues(
                                      alpha: _status == st ? 1 : 0.35)),
                            ),
                            child: Text(st,
                                style: GoogleFonts.plusJakartaSans(
                                    color: _status == st
                                        ? Colors.white
                                        : aerialFpvStatusColor(st),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.groups_2_outlined, color: accent, size: 18),
                      const SizedBox(width: 6),
                      Text('Student Names',
                          style: GoogleFonts.plusJakartaSans(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      const Spacer(),
                      Text('${names.length} detected',
                          style: GoogleFonts.plusJakartaSans(
                              color:
                              names.isEmpty ? c.textSecondary : accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _names,
                    minLines: 8,
                    maxLines: 14,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: c.textPrimary),
                    decoration: dec('Paste one name per line',
                        hint: '01. ARUN K\n02. KASIMANI KALIDAS\n03. JAGATH KISHORE\n...'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Leading numbers like "01. " or "1) " are removed automatically. '
                        'Names already in the $label ${_year == 0 ? 'No year' : _year} list are skipped.',
                    style: GoogleFonts.plusJakartaSans(
                        color: c.textSecondary, fontSize: 11.5),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                          : Text(
                          names.isEmpty
                              ? 'Save Students'
                              : 'Save ${names.length} Student${names.length == 1 ? '' : 's'}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}