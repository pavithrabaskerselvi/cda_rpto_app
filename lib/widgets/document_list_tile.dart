import 'package:flutter/material.dart';
import 'form_status_badge.dart';
import 'package:cda_rpto/utils/document_launcher.dart';

/// A list tile for showing an uploaded document (name, type, date, status).
/// Pairs with document_model.dart / document_upload_tile.dart.
///
/// ASSUMPTIONS (rename fields to match your actual DocumentModel):
/// - status is a String: 'pending' | 'approved' | 'rejected'
/// - fileType is used to pick an icon (pdf/image/other)
class DocumentListTile extends StatelessWidget {
  final String documentName;
  final String fileType; // e.g. 'pdf', 'image', 'doc'
  final String status; // 'pending' | 'approved' | 'rejected'
  final DateTime uploadedDate;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const DocumentListTile({
    super.key,
    required this.documentName,
    required this.fileType,
    required this.status,
    required this.uploadedDate,
    this.onTap,
    this.onDelete,
  });

  IconData get _fileIcon {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
      case 'jpg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
        child: Icon(_fileIcon, color: theme.colorScheme.primary),
      ),
      title: Text(documentName, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${uploadedDate.day}/${uploadedDate.month}/${uploadedDate.year}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FormStatusBadge(status: status),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}