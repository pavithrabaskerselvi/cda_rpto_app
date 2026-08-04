import 'package:flutter/material.dart';

/// A tile prompting the user to upload a required document
/// (e.g. license, certificate, ID proof).
/// Shows an "Upload" button, or a progress bar while uploading,
/// or a "Replace" state once a file exists.
///
/// This widget is presentational only — no upload logic lives here.
/// The parent screen handles picking + uploading and passes state in.
class DocumentUploadTile extends StatelessWidget {
  final String label;
  final String? fileName; // null if nothing uploaded yet
  final double? uploadProgress; // null if not currently uploading
  final bool required;
  final VoidCallback onUploadPressed;
  final VoidCallback? onRemovePressed;

  const DocumentUploadTile({
    super.key,
    required this.label,
    required this.onUploadPressed,
    this.fileName,
    this.uploadProgress,
    this.required = false,
    this.onRemovePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUploading = uploadProgress != null;
    final hasFile = fileName != null && !isUploading;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasFile ? Icons.check_circle : Icons.upload_file,
                color: hasFile ? Colors.green : theme.hintColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: label,
                    style: theme.textTheme.bodyMedium,
                    children: required
                        ? const [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: Colors.red),
                      ),
                    ]
                        : [],
                  ),
                ),
              ),
              if (!isUploading)
                TextButton(
                  onPressed: onUploadPressed,
                  child: Text(hasFile ? 'Replace' : 'Upload'),
                ),
              if (hasFile && onRemovePressed != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onRemovePressed,
                ),
            ],
          ),
          if (hasFile)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 4),
              child: Text(
                fileName!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (isUploading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(value: uploadProgress),
            ),
        ],
      ),
    );
  }
}