import 'package:flutter/material.dart';
import '../../document/documents_screen.dart';

/// List of Candidates — mirrors the "1.list of candidates" folder in
/// Drive. Instead of re-building the roster as data-entry fields, this
/// just lets you attach the actual candidate-list file(s) (xlsx/pdf) for
/// the batch. Student records themselves still live in the Students tab —
/// this screen is untouched by that and only manages the attached file(s).
class CandidateListScreen extends StatelessWidget {
  final String batchId;
  final String batchName;

  const CandidateListScreen({
    super.key,
    required this.batchId,
    required this.batchName,
  });

  @override
  Widget build(BuildContext context) {
    return DocumentsScreen(
      title: '$batchName - List of Candidates',
      firestorePath: 'batches/$batchId',
      firestoreField: 'candidateListDocuments',
      requirements: const [],
      allowExtraDocuments: true,
    );
  }
}