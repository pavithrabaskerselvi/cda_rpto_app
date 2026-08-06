import 'package:flutter/material.dart';
import '../../document/documents_screen.dart';

/// Counseling — just attach the counseling record file(s) (xlsx/pdf) for
/// the batch instead of tracking per-student counseling notes here.
class CounselingScreen extends StatelessWidget {
  final String batchId;
  final String batchName;

  const CounselingScreen({
    super.key,
    required this.batchId,
    required this.batchName,
  });

  @override
  Widget build(BuildContext context) {
    return DocumentsScreen(
      title: '$batchName - Counseling',
      firestorePath: 'batches/$batchId',
      firestoreField: 'counselingDocuments',
      requirements: const [],
      allowExtraDocuments: true,
    );
  }
}