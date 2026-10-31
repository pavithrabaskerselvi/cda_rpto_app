import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../models/student_model.dart';
import '../../services/overall_export_service.dart';
import '../../services/student_service.dart';
import '../student/student_edit_screen.dart';
import '../aerial_fpv/aerial_fpv_student_detail_screen.dart';
import '../aerial_fpv/aerial_fpv_student_list_screen.dart';
import '../aerial_fpv/aerial_fpv_year_screen.dart';

const Color kOverallBatchColor = Color(0xFF1D6FD8);
const Color kOverallMediumColor = Color(0xFF6D28D9);

// ---------------------------------------------------------------------
// Overall List home: Batch | Aerial | FPV
// ---------------------------------------------------------------------
class OverallListHomeScreen extends StatelessWidget {
  const OverallListHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CompanyColors.of(context.watch<ThemeProvider>().isDarkMode);

    return aerialFpvThemed(
      context,
      Scaffold(
        backgroundColor: c.background,
        body: CustomScrollView(
          slivers: [
            aerialFpvSliverAppBar(c: c, title: 'Overall List'),
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection(kAerialFpvCollection)
                    .snapshots(),
                builder: (context, aSnap) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('batches')
                        .snapshots(),
                    builder: (context, bSnap) {
                      var aerial = 0, fpv = 0;
                      for (final d in aSnap.data?.docs ?? const []) {
                        if (d.data()['category'] == 'aerial') aerial++;
                        if (d.data()['category'] == 'fpv') fpv++;
                      }
                      final batches = (bSnap.data?.docs ?? const [])
                          .where((d) => _isRpc(d.data()))
                          .length;

                      String st(int n) => '$n student${n == 1 ? '' : 's'}';

                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: OverallTile(
                                c: c,
                                label: 'RPC',
                                icon: Icons.groups,
                                color: kOverallBatchColor,
                                subtitle:
                                '$batches batch${batches == 1 ? '' : 'es'}',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const OverallBatchSizeScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OverallTile(
                                c: c,
                                label: 'Aerial',
                                icon: Icons.flight,
                                color: aerialFpvColor('aerial'),
                                subtitle: st(aerial),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const AerialFpvYearScreen(
                                          category: 'aerial', overall: true)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OverallTile(
                                c: c,
                                label: 'FPV',
                                icon: Icons.vrpano_outlined,
                                color: aerialFpvColor('fpv'),
                                subtitle: st(fpv),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const AerialFpvYearScreen(
                                          category: 'fpv', overall: true)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OverallTile extends StatelessWidget {
  final CompanyColors c;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const OverallTile({
    super.key,
    required this.c,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary)),
            const SizedBox(height: 3),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Shared table (spreadsheet-style columns)
// ---------------------------------------------------------------------
class OverallRow {
  /// 11 cells in [kOverallColumns] order. Cell 0 (S NO) is filled in by
  /// the table itself.
  final List<String> cells;
  final VoidCallback? onTap;

  /// Firestore student id (only set for the RPC Small / Medium tables).
  final String? id;
  const OverallRow(this.cells, {this.onTap, this.id});
}

class OverallTableScreen extends StatefulWidget {
  final String title;
  final Color accent;
  final bool loading;
  final String? error;
  final List<OverallRow> rows;

  /// true only for RPC Small / Medium: shows Edit, Delete, PDF, Excel.
  final bool batchTools;

  /// Excel tab that opens first when the workbook is exported.
  final String? exportSheet;

  const OverallTableScreen({
    super.key,
    required this.title,
    required this.accent,
    required this.rows,
    this.loading = false,
    this.error,
    this.batchTools = false,
    this.exportSheet,
  });

  @override
  State<OverallTableScreen> createState() => _OverallTableScreenState();
}

enum _TableMode { none, edit, delete }

class _OverallTableScreenState extends State<OverallTableScreen> {
  final _scroll = ScrollController();
  String _query = '';
  _TableMode _mode = _TableMode.none;
  final Set<String> _selected = {};
  bool _busy = false;

  void _setMode(_TableMode m) => setState(() {
    _mode = _mode == m ? _TableMode.none : m;
    _selected.clear();
  });

  Future<void> _editStudent(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .doc(id)
          .get();
      if (!snap.exists) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Student not found')));
        return;
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                StudentEditScreen(student: StudentModel.fromDocument(snap))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open: $e')));
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final n = _selected.length;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $n student${n == 1 ? '' : 's'}?'),
        content: const Text('This cannot be undone.'),
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
    if (yes != true) return;

    setState(() => _busy = true);
    var failed = 0;
    for (final id in _selected.toList()) {
      final err = await StudentService.deleteStudent(id);
      if (err != null) failed++;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _selected.clear();
    });
    messenger.showSnackBar(SnackBar(
        content: Text(failed == 0
            ? 'Deleted $n student${n == 1 ? '' : 's'}'
            : '$failed could not be deleted')));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CompanyColors.of(context.watch<ThemeProvider>().isDarkMode);
    final accent = widget.accent;

    final rows = widget.rows
        .where((r) =>
    _query.isEmpty || r.cells.join(' ').toLowerCase().contains(_query))
        .toList();

    TextStyle head() => GoogleFonts.plusJakartaSans(
        color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 12);
    TextStyle body() => GoogleFonts.plusJakartaSans(
        color: c.textPrimary, fontWeight: FontWeight.w500, fontSize: 12.5);

    Widget content;
    if (widget.error != null) {
      content = Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
            child: Text('Error: ${widget.error}',
                style: TextStyle(color: c.danger))),
      );
    } else if (widget.loading) {
      content = const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (rows.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text('No students found.',
              style: GoogleFonts.plusJakartaSans(color: c.textSecondary)),
        ),
      );
    } else {
      content = Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            child: DataTable(
              showCheckboxColumn: _mode == _TableMode.delete,
              columnSpacing: 26,
              horizontalMargin: 14,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 52,
              headingRowColor:
              WidgetStatePropertyAll(accent.withValues(alpha: 0.15)),
              columns: [
                for (final t in kOverallColumns)
                  DataColumn(label: Text(t, style: head())),
              ],
              rows: [
                for (var i = 0; i < rows.length; i++)
                  DataRow(
                    selected: rows[i].id != null &&
                        _selected.contains(rows[i].id),
                    onSelectChanged: (_) {
                      final id = rows[i].id;
                      if (widget.batchTools && id != null) {
                        if (_mode == _TableMode.delete) {
                          setState(() {
                            if (!_selected.remove(id)) _selected.add(id);
                          });
                          return;
                        }
                        if (_mode == _TableMode.edit) {
                          _editStudent(id);
                          return;
                        }
                      }
                      rows[i].onTap?.call();
                    },
                    cells: [
                      DataCell(Text('${i + 1}', style: body())),
                      for (var k = 1; k < kOverallColumns.length; k++)
                        DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            rows[i].cells[k],
                            overflow: TextOverflow.ellipsis,
                            style: k == 1
                                ? body().copyWith(fontWeight: FontWeight.w700)
                                : body(),
                          ),
                        )),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return aerialFpvThemed(
      context,
      Scaffold(
        backgroundColor: c.background,
        body: CustomScrollView(
          slivers: [
            aerialFpvSliverAppBar(
              c: c,
              title: widget.title,
              actions: widget.batchTools
                  ? [
                IconButton(
                  tooltip: 'Edit',
                  icon: Icon(Icons.edit_outlined,
                      color: _mode == _TableMode.edit ? accent : null),
                  onPressed: () => _setMode(_TableMode.edit),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: Icon(Icons.delete_outline,
                      color: _mode == _TableMode.delete
                          ? c.danger
                          : null),
                  onPressed: () => _setMode(_TableMode.delete),
                ),
                IconButton(
                  tooltip: 'Export PDF',
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () => OverallExport.exportAll(
                      context, OverallExportType.pdf,
                      activeSheet: widget.exportSheet),
                ),
                IconButton(
                  tooltip: 'Export Excel',
                  icon: const Icon(Icons.table_chart_outlined),
                  onPressed: () => OverallExport.exportAll(
                      context, OverallExportType.excel,
                      activeSheet: widget.exportSheet),
                ),
              ]
                  : null,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: TextField(
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  style: GoogleFonts.plusJakartaSans(color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search name, phone, email, batch...',
                    hintStyle:
                    GoogleFonts.plusJakartaSans(color: c.textSecondary),
                    prefixIcon: Icon(Icons.search, color: c.textSecondary),
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      BorderSide(color: accent.withValues(alpha: 0.25)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      BorderSide(color: accent.withValues(alpha: 0.25)),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Text(
                  '${rows.length} student${rows.length == 1 ? '' : 's'}',
                  style: GoogleFonts.plusJakartaSans(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
            ),
            if (widget.batchTools && _mode != _TableMode.none)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_mode == _TableMode.delete ? c.danger : accent)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _mode == _TableMode.edit
                        ? Text('Edit mode: tap a student to edit',
                        style: GoogleFonts.plusJakartaSans(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5))
                        : Row(
                      children: [
                        Expanded(
                          child: Text(
                              _selected.isEmpty
                                  ? 'Delete mode: tick the students to delete'
                                  : '${_selected.length} selected',
                              style: GoogleFonts.plusJakartaSans(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5)),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                            _selected
                              ..clear()
                              ..addAll([
                                for (final r in rows)
                                  if (r.id != null) r.id!
                              ]);
                          }),
                          child: const Text('Select all'),
                        ),
                        TextButton(
                          onPressed: (_selected.isEmpty || _busy)
                              ? null
                              : _deleteSelected,
                          child: Text(_busy ? 'Deleting...' : 'Delete',
                              style: TextStyle(color: c.danger)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 40),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Aerial / FPV table for one year
// ---------------------------------------------------------------------
class OverallAerialFpvTableScreen extends StatelessWidget {
  final String category; // 'aerial' | 'fpv'
  final int year; // 0 = students without a year
  const OverallAerialFpvTableScreen(
      {super.key, required this.category, required this.year});

  @override
  Widget build(BuildContext context) {
    final label = aerialFpvLabel(category);
    final title = '$label - ${year == 0 ? 'No year' : year}';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(kAerialFpvCollection)
          .where('category', isEqualTo: category)
          .snapshots(),
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? [])
            .where((d) => aerialFpvYearOf(d.data()) == year)
            .toList()
          ..sort((a, b) {
            final ta = a.data()['createdAt'];
            final tb = b.data()['createdAt'];
            if (ta is Timestamp && tb is Timestamp) return ta.compareTo(tb);
            if (ta is Timestamp) return -1;
            if (tb is Timestamp) return 1;
            return (a.data()['name'] ?? '')
                .toString()
                .toLowerCase()
                .compareTo((b.data()['name'] ?? '').toString().toLowerCase());
          });

        final rows = [
          for (final d in docs)
            OverallRow(
              overallAerialFpvCells(d.data()),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AerialFpvStudentDetailScreen(
                      docId: d.id, category: category),
                ),
              ),
            ),
        ];

        return OverallTableScreen(
          title: title,
          accent: aerialFpvColor(category),
          rows: rows,
          loading: !snap.hasData && !snap.hasError,
          error: snap.hasError ? '${snap.error}' : null,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// Batch (RPC): Small Batch | Medium Batch
// ---------------------------------------------------------------------
bool _isMedium(Map<String, dynamic> data) => overallIsMedium(data);

bool _isRpc(Map<String, dynamic> data) => overallIsRpc(data);

class OverallBatchSizeScreen extends StatelessWidget {
  const OverallBatchSizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CompanyColors.of(context.watch<ThemeProvider>().isDarkMode);

    return aerialFpvThemed(
      context,
      Scaffold(
        backgroundColor: c.background,
        body: CustomScrollView(
          slivers: [
            aerialFpvSliverAppBar(c: c, title: 'RPC'),
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('batches')
                    .snapshots(),
                builder: (context, bSnap) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('students')
                        .snapshots(),
                    builder: (context, sSnap) {
                      final small = <String>{};
                      final medium = <String>{};
                      for (final d in bSnap.data?.docs ?? const []) {
                        if (!_isRpc(d.data())) continue;
                        (_isMedium(d.data()) ? medium : small).add(d.id);
                      }
                      var smallStudents = 0, mediumStudents = 0;
                      for (final d in sSnap.data?.docs ?? const []) {
                        final id = (d.data()['batchId'] ?? '').toString();
                        if (small.contains(id)) smallStudents++;
                        if (medium.contains(id)) mediumStudents++;
                      }

                      String sub(int b, int s) =>
                          '$b batch${b == 1 ? '' : 'es'}  •  $s student${s == 1 ? '' : 's'}';

                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: OverallTile(
                                c: c,
                                label: 'Small Batch',
                                icon: Icons.groups_outlined,
                                color: kOverallBatchColor,
                                subtitle: sub(small.length, smallStudents),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const OverallBatchTableScreen(
                                          medium: false)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OverallTile(
                                c: c,
                                label: 'Medium Batch',
                                icon: Icons.groups,
                                color: kOverallMediumColor,
                                subtitle: sub(medium.length, mediumStudents),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const OverallBatchTableScreen(
                                          medium: true)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every student of the RPC batches of one size, with the sheet columns.
/// Tap a row to open that student's batch.
class OverallBatchTableScreen extends StatelessWidget {
  final bool medium;
  const OverallBatchTableScreen({super.key, required this.medium});

  @override
  Widget build(BuildContext context) {
    final accent = medium ? kOverallMediumColor : kOverallBatchColor;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('batches').snapshots(),
      builder: (context, bSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('students').snapshots(),
          builder: (context, sSnap) {
            final batches = <String, Map<String, dynamic>>{};
            for (final d in bSnap.data?.docs ?? const []) {
              final data = d.data();
              if (_isRpc(data) && _isMedium(data) == medium) {
                batches[d.id] = data;
              }
            }

            final students = (sSnap.data?.docs ?? [])
                .where((d) => batches.containsKey(d.data()['batchId']))
                .toList()
              ..sort((a, b) {
                final ba = (a.data()['batchName'] ?? '').toString();
                final bb = (b.data()['batchName'] ?? '').toString();
                final cmp = ba.toLowerCase().compareTo(bb.toLowerCase());
                if (cmp != 0) return cmp;
                return (a.data()['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .compareTo(
                    (b.data()['name'] ?? '').toString().toLowerCase());
              });

            final rows = [
              for (final d in students)
                    () {
                  final s = d.data();
                  final batch = batches[s['batchId']] ?? const {};
                  return OverallRow(
                    overallBatchCells(s, batch),
                    id: d.id,
                    onTap: () => Navigator.of(context).pushNamed(
                        AppRoutes.batchDetail,
                        arguments: (s['batchId'] ?? '').toString()),
                  );
                }(),
            ];

            return OverallTableScreen(
              title: medium ? 'Medium Batch' : 'Small Batch',
              accent: accent,
              rows: rows,
              batchTools: true,
              exportSheet: medium ? 'RPC MED' : 'RPC SMALL',
              loading: (!bSnap.hasData || !sSnap.hasData) &&
                  !bSnap.hasError &&
                  !sSnap.hasError,
              error: bSnap.hasError
                  ? '${bSnap.error}'
                  : (sSnap.hasError ? '${sSnap.error}' : null),
            );
          },
        );
      },
    );
  }
}