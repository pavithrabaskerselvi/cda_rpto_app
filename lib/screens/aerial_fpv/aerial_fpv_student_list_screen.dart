import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import 'aerial_fpv_student_detail_screen.dart';
import 'aerial_fpv_bulk_add_screen.dart';

const String kAerialFpvCollection = 'aerial_fpv_students';

/// Cloudinary route in FileUploadRouter handles <= 10 MB, so the same
/// limit is applied here.
const int kAerialFpvMaxDocBytes = 10 * 1024 * 1024;

/// Course status choices (also used as the 5 filter buttons on the list).
const List<String> kAerialFpvStatuses = [
  'Long Term Pending',
  'Ongoing',
  'Completed',
  'Partially Completed',
  'Dropped',
];

Color aerialFpvStatusColor(String status) {
  switch (status) {
    case 'Long Term Pending':
      return const Color(0xFFE67E22);
    case 'Ongoing':
      return const Color(0xFF1D6FD8);
    case 'Completed':
      return const Color(0xFF16A34A);
    case 'Partially Completed':
      return const Color(0xFF0D9488);
    case 'Dropped':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF6B7280);
  }
}

/// First year of the Aerial / FPV records. Year cards start here and keep
/// continuing up to the current year automatically.
const int kAerialFpvStartYear = 2022;

/// 2022 and continuing: runs up to 4 years past the current year (so it
/// never stops at the current year), or [extra] if a record is later.
List<int> aerialFpvYearOptions({int? extra}) {
  var last = DateTime.now().year + 4;
  if (extra != null && extra > last) last = extra;
  return [for (var y = kAerialFpvStartYear; y <= last; y++) y];
}

/// Firestore Timestamp / DateTime -> dd-MM-yyyy ('' when empty).
String aerialFpvFmtDate(dynamic v) {
  DateTime? d;
  if (v is Timestamp) d = v.toDate();
  if (v is DateTime) d = v;
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)}-${d.year}';
}

/// YES / NO selector. Tap the selected one again to clear it.
Widget aerialFpvYesNo({
  required CompanyColors c,
  required Color accent,
  required String label,
  required String value,
  required ValueChanged<String> onChanged,
}) {
  Widget chip(String v) {
    final on = value == v;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onChanged(on ? '' : v),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: on ? accent : accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: on ? 1 : 0.35)),
        ),
        child: Text(v,
            style: GoogleFonts.plusJakartaSans(
                color: on ? Colors.white : accent,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      ),
    );
  }

  return Row(
    children: [
      SizedBox(
        width: 90,
        child: Text(label,
            style: GoogleFonts.plusJakartaSans(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5)),
      ),
      chip('YES'),
      const SizedBox(width: 8),
      chip('NO'),
    ],
  );
}

/// Year saved on a student; 0 = old record saved before years existed.
/// "1. ARUN K" / "01) ARUN K" -> "ARUN K" (the list numbers rows itself).
String aerialFpvCleanName(String name) {
  final out = name.trim().replaceFirst(RegExp(r'^\d+\s*[\.\)\-]\s*'), '').trim();
  return out.isEmpty ? name.trim() : out;
}

int aerialFpvYearOf(Map<String, dynamic> data) =>
    data['year'] is int ? data['year'] as int : 0;

Color aerialFpvColor(String category) =>
    category == 'aerial' ? const Color(0xFF1D6FD8) : const Color(0xFF6D28D9);

String aerialFpvLabel(String category) => category == 'aerial' ? 'Aerial' : 'FPV';

/// Same collapsing teal-gradient header the RPTO Vault uses.
SliverAppBar aerialFpvSliverAppBar({
  required CompanyColors c,
  required String title,
  List<Widget>? actions,
}) {
  return SliverAppBar(
    backgroundColor: c.background,
    pinned: true,
    expandedHeight: 130,
    elevation: 0,
    iconTheme: IconThemeData(color: c.textPrimary),
    actions: actions,
    flexibleSpace: FlexibleSpaceBar(
      titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: c.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
      background: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.accent.withValues(alpha: 0.35), c.background],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    ),
  );
}

Widget aerialFpvThemed(BuildContext context, Widget child) {
  final jakarta = GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme);
  return Theme(
    data: Theme.of(context).copyWith(textTheme: jakarta, primaryTextTheme: jakarta),
    child: child,
  );
}

class AerialFpvStudentListScreen extends StatefulWidget {
  final String category; // 'aerial' | 'fpv'
  final int year; // selected year, 0 = records without a year
  const AerialFpvStudentListScreen(
      {super.key, required this.category, required this.year});

  @override
  State<AerialFpvStudentListScreen> createState() =>
      _AerialFpvStudentListScreenState();
}

class _AerialFpvStudentListScreenState
    extends State<AerialFpvStudentListScreen> {
  String _query = '';
  String _status = ''; // '' = All

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final c = CompanyColors.of(isDark);
    final accent = aerialFpvColor(widget.category);
    final label = aerialFpvLabel(widget.category);
    final yearLabel = widget.year == 0 ? 'No year' : '${widget.year}';

    return aerialFpvThemed(
      context,
      Scaffold(
        backgroundColor: c.background,
        floatingActionButton: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              heroTag: 'bulkAddStudents',
              backgroundColor: c.surface,
              foregroundColor: accent,
              elevation: 2,
              shape: StadiumBorder(side: BorderSide(color: accent)),
              icon: const Icon(Icons.playlist_add),
              label: Text('Bulk Add',
                  style:
                  GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AerialFpvBulkAddScreen(
                          category: widget.category,
                          year: widget.year == 0 ? null : widget.year),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FloatingActionButton.extended(
              heroTag: 'addStudent',
              backgroundColor: accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text('Add Student',
                  style:
                  GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
              onPressed: () => showStudentForm(context,
                  category: widget.category,
                  year: widget.year == 0 ? null : widget.year),
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(kAerialFpvCollection)
              .where('category', isEqualTo: widget.category)
              .snapshots(),
          builder: (context, snap) {
            Widget content;
            Widget filterBar = const SizedBox.shrink();
            if (snap.hasError) {
              content = Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('Error: ${snap.error}',
                      style: TextStyle(color: c.danger)),
                ),
              );
            } else if (!snap.hasData) {
              content = const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            } else {
              final all = snap.data!.docs
                  .where((d) => aerialFpvYearOf(d.data()) == widget.year)
                  .toList();
              // counts for the filter buttons (ignores the search box)
              final counts = <String, int>{
                for (final st in kAerialFpvStatuses) st: 0,
              };
              for (final d in all) {
                final st = (d.data()['status'] ?? '').toString();
                if (counts.containsKey(st)) counts[st] = counts[st]! + 1;
              }

              final docs = all.where((d) {
                final data = d.data();
                final n = (data['name'] ?? '').toString().toLowerCase();
                final p = (data['phone'] ?? '').toString().toLowerCase();
                final r = (data['regNo'] ?? '').toString().toLowerCase();
                final matchQuery = _query.isEmpty ||
                    n.contains(_query) ||
                    p.contains(_query) ||
                    r.contains(_query);
                final matchStatus = _status.isEmpty ||
                    (data['status'] ?? '').toString() == _status;
                return matchQuery && matchStatus;
              }).toList()
                ..sort((a, b) => (a.data()['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .compareTo((b.data()['name'] ?? '').toString().toLowerCase()));

              filterBar = _StatusFilterBar(
                c: c,
                selected: _status,
                total: all.length,
                counts: counts,
                onSelect: (v) => setState(() => _status = v),
              );

              if (docs.isEmpty) {
                content = Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      _status.isNotEmpty
                          ? 'No $label students with status "$_status".'
                          : 'No $label students in $yearLabel yet.\nTap "Add Student".',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(color: c.textSecondary),
                    ),
                  ),
                );
              } else {
                content = Column(
                  children: [
                    for (var i = 0; i < docs.length; i++) ...[
                      _StudentTile(
                        index: i + 1,
                        data: docs[i].data(),
                        c: c,
                        accent: accent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AerialFpvStudentDetailScreen(
                              docId: docs[i].id,
                              category: widget.category,
                            ),
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
                aerialFpvSliverAppBar(
                    c: c, title: '$label Students - $yearLabel'),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: TextField(
                      onChanged: (v) =>
                          setState(() => _query = v.trim().toLowerCase()),
                      style: GoogleFonts.plusJakartaSans(color: c.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search $label students',
                        hintStyle:
                        GoogleFonts.plusJakartaSans(color: c.textSecondary),
                        prefixIcon: Icon(Icons.search, color: c.textSecondary),
                        filled: true,
                        fillColor: c.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: accent.withValues(alpha: 0.25)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: accent.withValues(alpha: 0.25)),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: filterBar),
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

/// "All" + the 5 status buttons. Tap a status to show only those students;
/// tap it again (or "All") to clear the filter.
class _StatusFilterBar extends StatelessWidget {
  final CompanyColors c;
  final String selected;
  final int total;
  final Map<String, int> counts;
  final ValueChanged<String> onSelect;

  const _StatusFilterBar({
    required this.c,
    required this.selected,
    required this.total,
    required this.counts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String value, int count, Color color) {
      final on = selected == value;
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onSelect(on && value.isNotEmpty ? '' : value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: on ? color : color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: on ? 1 : 0.35)),
          ),
          child: Text(
            '$label  $count',
            style: GoogleFonts.plusJakartaSans(
              color: on ? Colors.white : color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('All', '', total, c.textSecondary),
          for (final st in kAerialFpvStatuses)
            chip(st, st, counts[st] ?? 0, aerialFpvStatusColor(st)),
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> data;
  final CompanyColors c;
  final Color accent;
  final VoidCallback onTap;

  const _StudentTile({
    required this.index,
    required this.data,
    required this.c,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // old records saved names like "1. ARUN K" - drop that typed number
    final name = aerialFpvCleanName((data['name'] ?? 'Unnamed').toString());
    final phone = (data['phone'] ?? '').toString();
    final regNo = (data['regNo'] ?? '').toString();
    // older records saved the course in "batch"
    final course = ((data['courseName'] ?? data['batch']) ?? '').toString();
    final status = (data['status'] ?? '').toString();
    final docCount = ((data['documents'] as List?) ?? []).length;
    final sub = [
      if (course.isNotEmpty) course,
      if (regNo.isNotEmpty) 'Reg: $regNo',
      if (phone.isNotEmpty) phone,
    ].join('  •  ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
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
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.person_outline, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$index. $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(sub.isEmpty ? 'No details' : sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                          color: c.textSecondary, fontSize: 11.5)),
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: aerialFpvStatusColor(status)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(status,
                          style: GoogleFonts.plusJakartaSans(
                              color: aerialFpvStatusColor(status),
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5)),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.attach_file, size: 15, color: accent),
            const SizedBox(width: 2),
            Text('$docCount',
                style: GoogleFonts.plusJakartaSans(
                    color: accent, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Direct Cloudinary unsigned upload (same cloud + preset as
/// CloudinaryUploadService). Has a timeout so it can never hang forever,
/// and throws the real Cloudinary error message so it can be shown.
Future<String> _aerialFpvUpload({
  required Uint8List bytes,
  required String fileName,
  required String category,
}) async {
  final uri = Uri.parse('https://api.cloudinary.com/v1_1/vmi67fhz/auto/upload');

  Future<http.Response> attempt({required bool withFolder}) async {
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = 'rpto_unsigned'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    if (withFolder) req.fields['folder'] = 'rpto_uploads/aerial_fpv/$category';
    final streamed = await req.send().timeout(const Duration(seconds: 90));
    return http.Response.fromStream(streamed);
  }

  var res = await attempt(withFolder: true);
  if (res.statusCode != 200) {
    // Some unsigned presets reject a custom folder - retry without it.
    res = await attempt(withFolder: false);
  }
  if (res.statusCode != 200) {
    String msg = 'status ${res.statusCode}';
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['error'] is Map) msg = j['error']['message'].toString();
    } catch (_) {}
    throw Exception(msg);
  }
  final url = (jsonDecode(res.body) as Map)['secure_url'];
  if (url is! String || url.isEmpty) {
    throw Exception('Cloudinary did not return a URL');
  }
  return url;
}

class _PendingUpload {
  final String name;
  double progress = 0;
  _PendingUpload(this.name);
}

InputDecoration _dec(CompanyColors c, Color accent, String label) {
  OutlineInputBorder b(Color col) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: col),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 13),
    filled: true,
    fillColor: c.surfaceElevated,
    isDense: true,
    border: b(accent.withValues(alpha: 0.2)),
    enabledBorder: b(accent.withValues(alpha: 0.2)),
    focusedBorder: b(accent),
  );
}

/// Add (doc == null) or edit a student. Includes document upload
/// (PDF / image / Word, up to 10 MB each) via Cloudinary.
Future<void> showStudentForm(
    BuildContext context, {
      required String category,
      int? year,
      DocumentSnapshot<Map<String, dynamic>>? doc,
    }) async {
  final c = CompanyColors.of(context.read<ThemeProvider>().isDarkMode);
  final accent = aerialFpvColor(category);
  final data = doc?.data() ?? {};

  final name = TextEditingController(text: data['name']?.toString() ?? '');
  final phone = TextEditingController(text: data['phone']?.toString() ?? '');
  final email = TextEditingController(text: data['email']?.toString() ?? '');
  final regNo = TextEditingController(text: data['regNo']?.toString() ?? '');
  final address =
  TextEditingController(text: data['address']?.toString() ?? '');
  // older records saved the course in "batch" - show it as the course name
  final courseName = TextEditingController(
      text: (data['courseName'] ?? data['batch'])?.toString() ?? '');
  final batchAllocated =
  TextEditingController(text: data['batchAllocated']?.toString() ?? '');
  final batchCompleted =
  TextEditingController(text: data['batchCompleted']?.toString() ?? '');
  DateTime? enrolled =
  data['enrolledDate'] is Timestamp ? (data['enrolledDate'] as Timestamp).toDate() : null;
  var certificate = (data['certificate'] ?? '').toString();
  var reviews = (data['reviews'] ?? '').toString();
  // 0 = "No year". An old record without a year stays in "No year" until a
  // year is picked; a new student takes the year of the list it was added from.
  var selYear = data['year'] is int ? data['year'] as int : (year ?? 0);
  var status = kAerialFpvStatuses.contains(data['status'])
      ? data['status'].toString()
      : 'Ongoing';
  final notes = TextEditingController(text: data['notes']?.toString() ?? '');
  final formKey = GlobalKey<FormState>();

  final docs = ((data['documents'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final pending = <_PendingUpload>[];
  var saving = false;

  final messenger = ScaffoldMessenger.of(context);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        Future<void> pickAndUpload() async {
          final res = await FilePicker.platform.pickFiles(
            allowMultiple: true,
            withData: true,
            type: FileType.custom,
            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
          );
          if (res == null) return;

          for (final f in res.files) {
            final bytes = f.bytes;
            if (bytes == null) continue;
            if (bytes.length > kAerialFpvMaxDocBytes) {
              messenger.showSnackBar(SnackBar(
                  content: Text('"${f.name}" 10 MB-ku mela irukku, skip pannirukken')));
              continue;
            }
            final p = _PendingUpload(f.name);
            pending.add(p);
            if (ctx.mounted) setS(() {});
            try {
              final url = await _aerialFpvUpload(
                bytes: bytes,
                fileName: f.name,
                category: category,
              );
              docs.add({
                'title': f.name,
                'url': url,
                'size': bytes.length,
                'uploadedAt': DateTime.now().toIso8601String(),
              });
            } catch (e) {
              messenger.showSnackBar(SnackBar(
                  duration: const Duration(seconds: 6),
                  content: Text('Upload failed (${f.name}): $e')));
            } finally {
              pending.remove(p);
              if (ctx.mounted) setS(() {});
            }
          }
        }

        final busy = pending.isNotEmpty || saving;

        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      doc == null
                          ? 'Add ${aerialFpvLabel(category)} Student'
                          : 'Edit Student',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: name,
                    style: TextStyle(color: c.textPrimary),
                    decoration: _dec(c, accent, 'Name *'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: regNo,
                    style: TextStyle(color: c.textPrimary),
                    decoration: _dec(c, accent, 'Reg No (optional)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: c.textPrimary),
                    decoration: _dec(c, accent, 'Phone (optional)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: c.textPrimary),
                    decoration: _dec(c, accent, 'Email (optional)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: address,
                    maxLines: 2,
                    style: TextStyle(color: c.textPrimary),
                    decoration: _dec(c, accent, 'Address (optional)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: courseName,
                    style: TextStyle(color: c.textPrimary),
                    decoration: _dec(c, accent, 'Course Name (optional)'),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: enrolled ?? now,
                        firstDate: DateTime(2015),
                        lastDate: DateTime(now.year + 5),
                      );
                      if (picked != null) setS(() => enrolled = picked);
                    },
                    child: InputDecorator(
                      decoration: _dec(c, accent, 'Enrolled Date (optional)')
                          .copyWith(
                        suffixIcon: enrolled == null
                            ? Icon(Icons.calendar_today_outlined,
                            size: 18, color: c.textSecondary)
                            : IconButton(
                          icon: Icon(Icons.close,
                              size: 18, color: c.textSecondary),
                          onPressed: () => setS(() => enrolled = null),
                        ),
                      ),
                      child: Text(
                        enrolled == null
                            ? 'Select date'
                            : aerialFpvFmtDate(enrolled),
                        style: TextStyle(
                            color: enrolled == null
                                ? c.textSecondary
                                : c.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: batchAllocated,
                    style: TextStyle(color: c.textPrimary),
                    decoration:
                    _dec(c, accent, 'Batch Allocated (e.g. Jan-23)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: batchCompleted,
                    style: TextStyle(color: c.textPrimary),
                    decoration: _dec(c, accent, 'Batch Completed (optional)'),
                  ),
                  const SizedBox(height: 12),
                  aerialFpvYesNo(
                    c: c,
                    accent: accent,
                    label: 'Certificate',
                    value: certificate,
                    onChanged: (v) => setS(() => certificate = v),
                  ),
                  const SizedBox(height: 8),
                  aerialFpvYesNo(
                    c: c,
                    accent: accent,
                    label: 'Reviews',
                    value: reviews,
                    onChanged: (v) => setS(() => reviews = v),
                  ),
                  const SizedBox(height: 12),
                  Text('STATUS',
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
                          onTap: () => setS(() => status = st),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: status == st
                                  ? aerialFpvStatusColor(st)
                                  : aerialFpvStatusColor(st)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: aerialFpvStatusColor(st).withValues(
                                      alpha: status == st ? 1 : 0.35)),
                            ),
                            child: Text(st,
                                style: GoogleFonts.plusJakartaSans(
                                    color: status == st
                                        ? Colors.white
                                        : aerialFpvStatusColor(st),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: selYear,
                    dropdownColor: c.surface,
                    style: TextStyle(color: c.textPrimary),
                    decoration: _dec(c, accent, 'Year'),
                    items: [
                      const DropdownMenuItem(value: 0, child: Text('No year')),
                      for (final y in aerialFpvYearOptions(extra: selYear))
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (v) => setS(() => selYear = v ?? selYear),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: notes,
                    maxLines: 2,
                    style: TextStyle(color: c.textPrimary),
                    decoration: _dec(c, accent, 'Notes (optional)'),
                  ),
                  const SizedBox(height: 18),

                  // ---------- Documents upload ----------
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
                      Text('DOCUMENTS (${docs.length}) - OPTIONAL',
                          style: GoogleFonts.plusJakartaSans(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              letterSpacing: 1.0)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < docs.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border:
                        Border.all(color: accent.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 18, color: c.success),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              docs[i]['title']?.toString() ?? 'Document',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                  color: c.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          InkWell(
                            onTap: busy ? null : () => setS(() => docs.removeAt(i)),
                            child: Icon(Icons.close, size: 18, color: c.danger),
                          ),
                        ],
                      ),
                    ),
                  for (final p in pending)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border:
                        Border.all(color: accent.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Uploading ${p.name}...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                  color: c.textSecondary, fontSize: 12)),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                              value: p.progress == 0 ? null : p.progress,
                              color: accent),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : pickAndUpload,
                      icon: Icon(Icons.upload_file, color: accent),
                      label: Text('Upload Documents',
                          style: GoogleFonts.plusJakartaSans(
                              color: accent, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accent.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('PDF, JPG, PNG, DOC, DOCX (max 10 MB each)',
                        style: GoogleFonts.plusJakartaSans(
                            color: c.textSecondary, fontSize: 11)),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: busy
                          ? null
                          : () async {
                        if (!formKey.currentState!.validate()) return;
                        setS(() => saving = true);
                        try {
                          final payload = {
                            'name': name.text.trim(),
                            'phone': phone.text.trim(),
                            'email': email.text.trim(),
                            'regNo': regNo.text.trim(),
                            'address': address.text.trim(),
                            'courseName': courseName.text.trim(),
                            'status': status,
                            'year': selYear,
                            'enrolledDate': enrolled != null
                                ? Timestamp.fromDate(enrolled!)
                                : null,
                            'batchAllocated': batchAllocated.text.trim(),
                            'batchCompleted': batchCompleted.text.trim(),
                            'certificate': certificate,
                            'reviews': reviews,
                            'notes': notes.text.trim(),
                            'documents': docs,
                          };
                          final col = FirebaseFirestore.instance
                              .collection(kAerialFpvCollection);
                          if (doc == null) {
                            await col.add({
                              ...payload,
                              'category': category,
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
                        saving
                            ? 'Saving...'
                            : pending.isNotEmpty
                            ? 'Uploading...'
                            : (doc == null ? 'Save' : 'Update'),
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}