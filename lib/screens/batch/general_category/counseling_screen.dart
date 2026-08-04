import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/student_model.dart';

class CounselingScreen extends StatefulWidget {
  final String batchId;
  final String batchName;

  const CounselingScreen({
    super.key,
    required this.batchId,
    required this.batchName,
  });

  @override
  State<CounselingScreen> createState() => _CounselingScreenState();
}

class _CounselingScreenState extends State<CounselingScreen> {
  bool _isLoading = true;
  List<StudentModel> _students = [];

  // ---- Theme-aware colors: flip between dark/light based on current
  // Theme brightness instead of hardcoded dark-only constants. ----
  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  Color _kNavy(BuildContext c) =>
      _isDark(c) ? const Color(0xFF050A14) : const Color(0xFFF7F8FA);
  Color _kSurface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF0F1B2E) : const Color(0xFFFFFFFF);
  Color _kTeal(BuildContext c) =>
      _isDark(c) ? const Color(0xFF14B8A6) : const Color(0xFF0D9488);
  Color _kCoral(BuildContext c) =>
      _isDark(c) ? const Color(0xFFFF6B6B) : const Color(0xFFD64545);
  Color _kAmber(BuildContext c) =>
      _isDark(c) ? const Color(0xFFF59E0B) : const Color(0xFFB77400);
  Color _kGreen(BuildContext c) =>
      _isDark(c) ? const Color(0xFF22C55E) : const Color(0xFF1F9D5A);
  Color _kPurple(BuildContext c) =>
      _isDark(c) ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED);
  Color _kTextPrimary(BuildContext c) =>
      _isDark(c) ? Colors.white : const Color(0xFF0B1220);
  Color _kTextSecondary(BuildContext c) =>
      _isDark(c) ? Colors.white70 : const Color(0xFF5B6472);
  Color _kTextMuted(BuildContext c) =>
      _isDark(c) ? Colors.white54 : const Color(0xFF7B8494);
  Color _kTextFaint(BuildContext c) =>
      _isDark(c) ? Colors.white38 : const Color(0xFF9AA3B2);
  Color _kBorder(BuildContext c) =>
      _isDark(c) ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E5EA);

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('batchId', isEqualTo: widget.batchId)
          .get();
      setState(() {
        _students = snap.docs.map((d) => StudentModel.fromDocument(d)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e'), backgroundColor: _kCoral(context)),
        );
      }
    }
  }

  void _openStudentSessions(StudentModel student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentCounselingSessionsScreen(student: student),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNavy(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: _kNavy(context),
            pinned: true,
            expandedHeight: 130,
            iconTheme: IconThemeData(color: _kTextPrimary(context)),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                '${widget.batchName} - Counseling',
                style: TextStyle(color: _kTextPrimary(context), fontSize: 16, fontWeight: FontWeight.w600),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kPurple(context).withValues(alpha: 0.25), _kNavy(context)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _kTeal(context))),
            )
          else if (_students.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text('No students found in this batch', style: TextStyle(color: _kTextMuted(context))),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final student = _students[index];
                  return _buildStudentTile(student);
                },
                childCount: _students.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildStudentTile(StudentModel student) {
    return InkWell(
      onTap: () => _openStudentSessions(student),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kSurface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder(context)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _kPurple(context).withValues(alpha: 0.2),
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                style: TextStyle(color: _kPurple(context), fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name,
                      style: TextStyle(color: _kTextPrimary(context), fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(student.phone, style: TextStyle(color: _kTextMuted(context), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _kTextFaint(context)),
          ],
        ),
      ),
    );
  }
}

// ---------------- Student Counseling Sessions ----------------

class StudentCounselingSessionsScreen extends StatefulWidget {
  final StudentModel student;

  const StudentCounselingSessionsScreen({super.key, required this.student});

  @override
  State<StudentCounselingSessionsScreen> createState() =>
      _StudentCounselingSessionsScreenState();
}

class _StudentCounselingSessionsScreenState
    extends State<StudentCounselingSessionsScreen> {
  bool _isSaving = false;

  // ---- Theme-aware colors: flip between dark/light based on current
  // Theme brightness instead of hardcoded dark-only constants. ----
  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  Color _kNavy(BuildContext c) =>
      _isDark(c) ? const Color(0xFF050A14) : const Color(0xFFF7F8FA);
  Color _kSurface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF0F1B2E) : const Color(0xFFFFFFFF);
  Color _kTeal(BuildContext c) =>
      _isDark(c) ? const Color(0xFF14B8A6) : const Color(0xFF0D9488);
  Color _kCoral(BuildContext c) =>
      _isDark(c) ? const Color(0xFFFF6B6B) : const Color(0xFFD64545);
  Color _kAmber(BuildContext c) =>
      _isDark(c) ? const Color(0xFFF59E0B) : const Color(0xFFB77400);
  Color _kGreen(BuildContext c) =>
      _isDark(c) ? const Color(0xFF22C55E) : const Color(0xFF1F9D5A);
  Color _kTextPrimary(BuildContext c) =>
      _isDark(c) ? Colors.white : const Color(0xFF0B1220);
  Color _kTextSecondary(BuildContext c) =>
      _isDark(c) ? Colors.white70 : const Color(0xFF5B6472);
  Color _kTextMuted(BuildContext c) =>
      _isDark(c) ? Colors.white54 : const Color(0xFF7B8494);
  Color _kBorder(BuildContext c) =>
      _isDark(c) ? Colors.white24 : const Color(0xFFD8DBE2);
  Color _kBorderSoft(BuildContext c) =>
      _isDark(c) ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E5EA);

  Stream<QuerySnapshot> _sessionsStream() {
    return FirebaseFirestore.instance
        .collection('counseling_sessions')
        .where('studentId', isEqualTo: widget.student.id)
        .orderBy('sessionDate', descending: true)
        .snapshots();
  }

  Future<void> _addSessionDialog() async {
    final notesController = TextEditingController();
    final counselorController = TextEditingController();
    DateTime sessionDate = DateTime.now();
    bool followUpRequired = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Counseling Session',
                      style: TextStyle(color: _kTextPrimary(context), fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: counselorController,
                    style: TextStyle(color: _kTextPrimary(context)),
                    decoration: _fieldDecoration(context, 'Counselor Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 4,
                    style: TextStyle(color: _kTextPrimary(context)),
                    decoration: _fieldDecoration(context, 'Session Notes / Remarks'),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: sessionDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: _isDark(context)
                                ? ColorScheme.dark(primary: _kTeal(context), surface: _kSurface(context))
                                : ColorScheme.light(primary: _kTeal(context), surface: _kSurface(context)),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setModalState(() => sessionDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: _kBorder(context)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: _kTextMuted(context), size: 18),
                          const SizedBox(width: 10),
                          Text(
                            '${sessionDate.day}/${sessionDate.month}/${sessionDate.year}',
                            style: TextStyle(color: _kTextPrimary(context)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: followUpRequired,
                        activeColor: _kAmber(context),
                        onChanged: (val) => setModalState(() => followUpRequired = val ?? false),
                      ),
                      Text('Follow-up required', style: TextStyle(color: _kTextSecondary(context))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () async {
                        if (counselorController.text.trim().isEmpty ||
                            notesController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: const Text('Fill all fields'), backgroundColor: _kCoral(context)),
                          );
                          return;
                        }
                        setState(() => _isSaving = true);
                        try {
                          await FirebaseFirestore.instance.collection('counseling_sessions').add({
                            'studentId': widget.student.id,
                            'studentName': widget.student.name,
                            'batchId': widget.student.batchId,
                            'counselorName': counselorController.text.trim(),
                            'notes': notesController.text.trim(),
                            'sessionDate': Timestamp.fromDate(sessionDate),
                            'followUpRequired': followUpRequired,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('Session saved'), backgroundColor: _kGreen(context)),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: _kCoral(context)),
                            );
                          }
                        } finally {
                          setState(() => _isSaving = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kTeal(context),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Text('Save Session',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _fieldDecoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _kTextMuted(context)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _kBorder(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _kTeal(context)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNavy(context),
      appBar: AppBar(
        backgroundColor: _kNavy(context),
        title: Text(widget.student.name, style: TextStyle(color: _kTextPrimary(context))),
        iconTheme: IconThemeData(color: _kTextPrimary(context)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kTeal(context),
        onPressed: _addSessionDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _sessionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _kTeal(context)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('No counseling sessions yet', style: TextStyle(color: _kTextMuted(context))),
            );
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final date = (data['sessionDate'] as Timestamp).toDate();
              final followUp = data['followUpRequired'] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: followUp ? _kAmber(context).withValues(alpha: 0.4) : _kBorderSoft(context),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['counselorName'] ?? '',
                            style: TextStyle(color: _kTextPrimary(context), fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${date.day}/${date.month}/${date.year}',
                          style: TextStyle(color: _kTextMuted(context), fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['notes'] ?? '',
                      style: TextStyle(color: _kTextSecondary(context), fontSize: 13),
                    ),
                    if (followUp) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.flag, color: _kAmber(context), size: 14),
                          const SizedBox(width: 4),
                          Text('Follow-up required',
                              style: TextStyle(color: _kAmber(context), fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
