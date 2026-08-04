import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/student_model.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final StudentModel student;

  const StudentAttendanceScreen({super.key, required this.student});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceRecords = []; // {date, present}
  int _presentCount = 0;
  int _totalCount = 0;

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
  Color _kTextMuted(BuildContext c) =>
      _isDark(c) ? Colors.white54 : const Color(0xFF7B8494);
  Color _kTrack(BuildContext c) =>
      _isDark(c) ? Colors.white12 : const Color(0xFFE9EBEF);

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  Future<void> _loadAttendanceHistory() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('attendance')
          .where('batchId', isEqualTo: widget.student.batchId)
          .orderBy('date', descending: true)
          .get();

      List<Map<String, dynamic>> records = [];
      int present = 0;
      int total = 0;

      for (var doc in snap.docs) {
        final data = doc.data();
        final recordsMap = data['records'] as Map<String, dynamic>? ?? {};

        if (recordsMap.containsKey(widget.student.id)) {
          final isPresent = recordsMap[widget.student.id] as bool;
          final date = (data['date'] as Timestamp).toDate();

          records.add({'date': date, 'present': isPresent});
          total++;
          if (isPresent) present++;
        }
      }

      setState(() {
        _attendanceRecords = records;
        _presentCount = present;
        _totalCount = total;
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

  @override
  Widget build(BuildContext context) {
    final percentage = _totalCount == 0 ? 0.0 : (_presentCount / _totalCount) * 100;
    final percentColor = percentage >= 75
        ? _kGreen(context)
        : (percentage >= 50 ? _kAmber(context) : _kCoral(context));

    return Scaffold(
      backgroundColor: _kNavy(context),
      appBar: AppBar(
        backgroundColor: _kNavy(context),
        title: Text(widget.student.name, style: TextStyle(color: _kTextPrimary(context))),
        iconTheme: IconThemeData(color: _kTextPrimary(context)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _kTeal(context)))
          : Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: percentColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _totalCount == 0 ? 0 : _presentCount / _totalCount,
                        strokeWidth: 6,
                        backgroundColor: _kTrack(context),
                        valueColor: AlwaysStoppedAnimation(percentColor),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(color: percentColor, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Attendance Summary',
                          style: TextStyle(color: _kTextMuted(context), fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '$_presentCount / $_totalCount days present',
                        style: TextStyle(
                            color: _kTextPrimary(context), fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_totalCount - _presentCount} days absent',
                        style: TextStyle(color: _kTextMuted(context), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _attendanceRecords.isEmpty
                ? Center(
              child: Text('No attendance records found',
                  style: TextStyle(color: _kTextMuted(context))),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _attendanceRecords.length,
              itemBuilder: (context, index) {
                final record = _attendanceRecords[index];
                final date = record['date'] as DateTime;
                final present = record['present'] as bool;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _kSurface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: present ? _kGreen(context).withValues(alpha: 0.3) : _kCoral(context).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        present ? Icons.check_circle : Icons.cancel,
                        color: present ? _kGreen(context) : _kCoral(context),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: TextStyle(color: _kTextPrimary(context), fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        present ? 'Present' : 'Absent',
                        style: TextStyle(
                          color: present ? _kGreen(context) : _kCoral(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

