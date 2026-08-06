import 'package:flutter/material.dart';
import '../../document/documents_screen.dart';

/// Logbook — mirrors the "5.logbook" folder in Drive, which splits into
/// RPTO / Battery / RPAS / Instructor logbooks plus a "sheets" folder of
/// xlsx files. Each is its own folder-style slot (upload as many files as
/// you like) instead of per-student logbook entries.
class LogbookScreen extends StatelessWidget {
  final String batchId;
  final String batchName;

  const LogbookScreen({
    super.key,
    required this.batchId,
    required this.batchName,
  });

  @override
  Widget build(BuildContext context) {
    return DocumentsScreen(
      title: '$batchName - Flight Logbook',
      firestorePath: 'batches/$batchId',
      firestoreField: 'logbookDocuments',
      requirements: const [
        DocumentRequirement(key: 'rpto_logbook', label: 'RPTO Logbook', required: false, allowMultiple: true),
        DocumentRequirement(key: 'battery_logbook', label: 'Battery Logbook', required: false, allowMultiple: true),
        DocumentRequirement(key: 'rpas_logbook', label: 'RPAS Logbook', required: false, allowMultiple: true),
        DocumentRequirement(key: 'instructor_logbook', label: 'Instructor Logbook', required: false, allowMultiple: true),
        DocumentRequirement(key: 'sheets', label: 'Sheets', required: false, allowMultiple: true),
      ],
      allowExtraDocuments: true,
    );
  }
}