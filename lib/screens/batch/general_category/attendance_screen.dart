import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/student_model.dart';

// Design tokens - match existing app theme
const Color kNavy = Color(0xFF050A14);
const Color kTeal = Color(0xFF14B8A6);
const Color kCoral = Color(0xFFFF6B6B);
const Color kAmber = Color(0xFFF59E0B);
const Color kSurface = Color(0xFF0F1B2E);
const Color kGreen = Color(0xFF22C55E);
const Color kPurple = Color(0xFF8B5CF6);

class AttendanceScreen extends StatefulWidget {
  final String batchId;
  final String batchName;

  const AttendanceScreen({
    super.key,
    required this.batchId,
    required this.batchName,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  List<StudentModel> _students = [];
  Map<String, String> _attendanceMap = {}; // studentId -> 'P'/'A'/'L'/'Lt'/'Ex'

  static const List<String> _codes = ['P', 'A', 'L', 'Lt', 'Ex'];
  static const Map<String, String> _codeLabels = {
    'P': 'Present',
    'A': 'Absent',
    'L': 'Leave',
    'Lt': 'Late',
    'Ex': 'Excused',
  };

  Color _codeColor(String code) {
    switch (code) {
      case 'P':
        return kGreen;
      case 'A':
        return kCoral;
      case 'L':
        return kAmber;
      case 'Lt':
        return const Color(0xFFFB923C); // orange, distinct from Absent's coral
      case 'Ex':
        return kTeal;
      default:
        return Colors.white54;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStudentsAndAttendance();
  }

  Future<void> _loadStudentsAndAttendance() async {
    setState(() => _isLoading = true);
    try {
      final studentsSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('batchId', isEqualTo: widget.batchId)
          .get();

      final students = studentsSnap.docs
          .map((doc) => StudentModel.fromDocument(doc))
          .toList();

      final dateKey = _formatDateKey(_selectedDate);
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('attendance')
          .doc('${widget.batchId}_$dateKey')
          .get();

      Map<String, String> attendanceMap = {};
      if (attendanceDoc.exists) {
        final data = attendanceDoc.data();
        final records = data?['records'] as Map<String, dynamic>? ?? {};
        records.forEach((studentId, value) {
          // Back-compat: older records stored a bool (present/absent).
          if (value is bool) {
            attendanceMap[studentId] = value ? 'P' : 'A';
          } else {
            attendanceMap[studentId] = value.toString();
          }
        });
      }
      for (var s in students) {
        attendanceMap[s.id] ??= 'P'; // default present for anyone not yet marked
      }

      setState(() {
        _students = students;
        _attendanceMap = attendanceMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e'), backgroundColor: kCoral),
        );
      }
    }
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: kTeal,
              surface: kSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadStudentsAndAttendance();
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isSaving = true);
    try {
      final dateKey = _formatDateKey(_selectedDate);
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc('${widget.batchId}_$dateKey')
          .set({
        'batchId': widget.batchId,
        'batchName': widget.batchName,
        'date': Timestamp.fromDate(_selectedDate),
        'records': _attendanceMap,
        'totalStudents': _students.length,
        'presentCount': _attendanceMap.values.where((v) => v == 'P').length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved'), backgroundColor: kGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: kCoral),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _markAll(String code) {
    setState(() {
      for (var s in _students) {
        _attendanceMap[s.id] = code;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = _attendanceMap.values.where((v) => v == 'P').length;
    final totalCount = _students.length;

    return Scaffold(
      backgroundColor: kNavy,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: kNavy,
            pinned: true,
            expandedHeight: 130,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                widget.batchName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kTeal.withOpacity(0.25), kNavy],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: _pickDate,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Date',
                      _formatDateKey(_selectedDate),
                      kPurple,
                      Icons.event,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Present',
                      '$presentCount / $totalCount',
                      kGreen,
                      Icons.how_to_reg,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _markAll('P'),
                        icon: const Icon(Icons.check_circle, color: kGreen, size: 18),
                        label: const Text('Mark All Present', style: TextStyle(color: kGreen)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kGreen),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _markAll('A'),
                        icon: const Icon(Icons.cancel, color: kCoral, size: 18),
                        label: const Text('Mark All Absent', style: TextStyle(color: kCoral)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kCoral),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: kTeal)),
            )
          else if (_students.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No students found in this batch',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final student = _students[index];
                  final code = _attendanceMap[student.id] ?? 'P';
                  return _buildStudentTile(student, code);
                },
                childCount: _students.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: _students.isEmpty
          ? null
          : Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: kTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text(
                'Save Attendance',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(StudentModel student, String code) {
    final color = _codeColor(code);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: kTeal.withOpacity(0.2),
                child: Text(
                  student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: kTeal, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      student.phone,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: _codes.map((c) {
              final isSelected = code == c;
              final cColor = _codeColor(c);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _attendanceMap[student.id] = c),
                    child: Tooltip(
                      message: _codeLabels[c] ?? c,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? cColor.withOpacity(0.18) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? cColor : Colors.white24),
                        ),
                        child: Text(
                          c,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? cColor : Colors.white54,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}