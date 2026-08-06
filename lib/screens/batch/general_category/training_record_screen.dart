import 'package:flutter/material.dart';
import '../../document/documents_screen.dart';

/// Training Record — mirrors the "4.Training record" folder in Drive.
/// Just attach the training record file(s) (xlsx/pdf) for the batch
/// instead of tracking flying/simulator hours per student here.
class TrainingRecordScreen extends StatelessWidget {
  final String batchId;
  final String batchName;

  const TrainingRecordScreen({
    super.key,
    required this.batchId,
    required this.batchName,
  });

  @override
  Widget build(BuildContext context) {
    return DocumentsScreen(
      title: '$batchName - Training Record',
      firestorePath: 'batches/$batchId',
      firestoreField: 'trainingRecordDocuments',
      requirements: const [],
      allowExtraDocuments: true,
    );
  }
}