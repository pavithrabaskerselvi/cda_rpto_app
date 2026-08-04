import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../config/theme_colors.dart';
import '../../models/student_model.dart';

class StudentBatchHistory extends StatelessWidget {
  final StudentModel student;
  const StudentBatchHistory({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Current batch card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: ThemeColors.surface(context), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              const Icon(Icons.groups, color: kTeal, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.batchName.isEmpty ? 'No batch assigned' : student.batchName,
                        style: TextStyle(
                            color: ThemeColors.textPrimary(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    if (student.enrollmentDate != null)
                      Text(
                        'Enrolled ${DateFormat('dd MMM yyyy').format(student.enrollmentDate!)}',
                        style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 13),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Attendance summary
        Text('Attendance',
            style: TextStyle(
                color: ThemeColors.textPrimary(context),
                fontWeight: FontWeight.w600,
                fontSize: 15)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('attendance')
              .where('studentId', isEqualTo: student.id)
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: ThemeColors.surface(context), borderRadius: BorderRadius.circular(14)),
                child: Text(
                  'Error loading attendance:\n${snapshot.error}',
                  style: const TextStyle(color: kCoral, fontSize: 12),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(color: kTeal)),
              );
            }
            final records = snapshot.data?.docs ?? [];
            if (records.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: ThemeColors.surface(context), borderRadius: BorderRadius.circular(14)),
                child: Text('No attendance records yet',
                    style: TextStyle(color: ThemeColors.textSecondary(context))),
              );
            }
            final present = records.where((d) => d['status'] == 'Present').length;
            final total = records.length;

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: ThemeColors.surface(context), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statBlock(context, '$present', 'Present', kGreen),
                      _statBlock(context, '${total - present}', 'Absent', kCoral),
                      _statBlock(
                        context,
                        total > 0 ? '${((present / total) * 100).round()}%' : '0%',
                        'Rate',
                        kTeal,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ...records.take(5).map((r) {
                  final date = (r['date'] as Timestamp?)?.toDate();
                  final status = r['status'] ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: ThemeColors.surface(context), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(date != null ? DateFormat('dd MMM yyyy').format(date) : '-',
                            style: TextStyle(color: ThemeColors.textPrimary(context))),
                        Text(status,
                            style: TextStyle(
                              color: status == 'Present' ? kGreen : kCoral,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Flight logbook summary
        Text('Flight Logbook',
            style: TextStyle(
                color: ThemeColors.textPrimary(context),
                fontWeight: FontWeight.w600,
                fontSize: 15)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('flightLogbook')
              .where('studentId', isEqualTo: student.id)
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: ThemeColors.surface(context), borderRadius: BorderRadius.circular(14)),
                child: Text(
                  'Error loading logbook:\n${snapshot.error}',
                  style: const TextStyle(color: kCoral, fontSize: 12),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(color: kTeal)),
              );
            }
            final logs = snapshot.data?.docs ?? [];
            if (logs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: ThemeColors.surface(context), borderRadius: BorderRadius.circular(14)),
                child: Text('No flight logs yet',
                    style: TextStyle(color: ThemeColors.textSecondary(context))),
              );
            }
            final totalMinutes = logs.fold<int>(
                0, (sum, l) => sum + ((l['duration'] ?? 0) as num).toInt());

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: ThemeColors.surface(context), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statBlock(context, '${logs.length}', 'Flights', kPurple),
                      _statBlock(context, '${(totalMinutes / 60).toStringAsFixed(1)}h', 'Total Hours', kTeal),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ...logs.take(5).map((l) {
                  final date = (l['date'] as Timestamp?)?.toDate();
                  final duration = l['duration'] ?? 0;
                  final notes = l['notes'] ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: ThemeColors.surface(context), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(date != null ? DateFormat('dd MMM yyyy').format(date) : '-',
                                  style: TextStyle(color: ThemeColors.textPrimary(context))),
                              if (notes.toString().isNotEmpty)
                                Text(notes,
                                    style: TextStyle(color: ThemeColors.textMuted(context), fontSize: 12)),
                            ],
                          ),
                        ),
                        Text('$duration min',
                            style: const TextStyle(color: kTeal, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _statBlock(BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12)),
      ],
    );
  }
}