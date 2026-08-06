import 'package:flutter/material.dart';
import '../../document/documents_screen.dart';

/// Schedule — mirrors the "2.Schedule" folder in Drive. Just attach the
/// schedule file(s) (xlsx/pdf) for the batch instead of building a
/// day-by-day session planner.
class ScheduleScreen extends StatelessWidget {
  final String batchId;
  final String batchName;

  const ScheduleScreen({
    super.key,
    required this.batchId,
    required this.batchName,
  });

  @override
  Widget build(BuildContext context) {
    return DocumentsScreen(
      title: '$batchName - Schedule',
      firestorePath: 'batches/$batchId',
      firestoreField: 'scheduleDocuments',
      requirements: const [],
      allowExtraDocuments: true,
    );
  }
}