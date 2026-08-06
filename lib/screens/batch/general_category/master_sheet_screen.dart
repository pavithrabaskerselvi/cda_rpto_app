import 'package:flutter/material.dart';
import '../../document/documents_screen.dart';

/// Master Sheet — mirrors the "8.Master sheet" folder in Drive. Just
/// attach the master sheet file (xlsx/pdf) for the batch instead of
/// building a read-only rollup view here.
class MasterSheetScreen extends StatelessWidget {
  final String batchId;
  final String batchName;

  const MasterSheetScreen({
    super.key,
    required this.batchId,
    required this.batchName,
  });

  @override
  Widget build(BuildContext context) {
    return DocumentsScreen(
      title: '$batchName - Master Sheet',
      firestorePath: 'batches/$batchId',
      firestoreField: 'masterSheetDocuments',
      requirements: const [],
      allowExtraDocuments: true,
    );
  }
}