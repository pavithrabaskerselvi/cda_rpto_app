import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/constants.dart';
import '../../config/theme_colors.dart';
import '../../models/student_model.dart';
import 'student_edit_screen.dart';
import 'student_info_tab.dart';
import 'student_documents_tab.dart';
import 'student_batch_history.dart';

class StudentDetailScreen extends StatelessWidget {
  final StudentModel student;
  const StudentDetailScreen({super.key, required this.student});

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ThemeColors.surface(context),
        title: Text('Delete Student',
            style: TextStyle(color: ThemeColors.textPrimary(context))),
        content: Text('Delete ${student.name}? This cannot be undone.',
            style: TextStyle(color: ThemeColors.textSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: ThemeColors.textSecondary(context))),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('students')
                  .doc(student.id)
                  .delete();
              if (context.mounted) {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // back to list
              }
            },
            child: const Text('Delete', style: TextStyle(color: kCoral)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: ThemeColors.bg(context),
        appBar: AppBar(
          backgroundColor: ThemeColors.bg(context),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: ThemeColors.textPrimary(context)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(student.name,
              style: TextStyle(color: ThemeColors.textPrimary(context))),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, color: kTeal),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => StudentEditScreen(student: student)),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: kCoral),
              onPressed: () => _confirmDelete(context),
            ),
          ],
          bottom: TabBar(
            indicatorColor: kTeal,
            labelColor: kTeal,
            unselectedLabelColor: ThemeColors.textSecondary(context),
            tabs: const [
              Tab(text: 'Info'),
              Tab(text: 'Documents'),
              Tab(text: 'Batch History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            StudentInfoTab(student: student),
            StudentDocumentsTab(studentId: student.id),
            StudentBatchHistory(student: student),
          ],
        ),
      ),
    );
  }
}