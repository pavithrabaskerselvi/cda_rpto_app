import 'package:flutter/material.dart';
import '../../document/documents_screen.dart';

/// Attendance — mirrors the "3.Attendance" folder in Drive, which splits
/// into "Online Class" and "Offline Class" subfolders. Each is a
/// folder-style slot here (upload as many files as you like) instead of
/// a per-student daily attendance form.
class AttendanceScreen extends StatelessWidget {
  final String batchId;
  final String batchName;

  const AttendanceScreen({
    super.key,
    required this.batchId,
    required this.batchName,
  });

  @override
  Widget build(BuildContext context) {
    return DocumentsScreen(
      title: '$batchName - Attendance',
      firestorePath: 'batches/$batchId',
      firestoreField: 'attendanceDocuments',
      requirements: const [
        DocumentRequirement(key: 'online_class', label: 'Online Class', required: false, allowMultiple: true),
        DocumentRequirement(key: 'offline_class', label: 'Offline Class', required: false, allowMultiple: true),
      ],
      allowExtraDocuments: true,
    );
  }
}