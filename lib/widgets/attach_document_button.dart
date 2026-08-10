import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/theme_colors.dart';
import '../screens/document/document_viewer_screen.dart';

/// A single attached document.
/// [key] links it to a [DocumentRequirement.key] when it fulfils a named,
/// possibly-mandatory slot (e.g. "insurance"). [key] is null for freeform /
/// optional documents added via the generic "Attach Document" button.
class AttachedDocument {
  final String? key;
  final String name;
  final String url;
  final DateTime uploadedAt;

  AttachedDocument({
    this.key,
    required this.name,
    required this.url,
    DateTime? uploadedAt,
  }) : uploadedAt = uploadedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'key': key,
    'name': name,
    'url': url,
    'uploadedAt': uploadedAt.toIso8601String(),
  };

  factory AttachedDocument.fromMap(Map<String, dynamic> map) =>
      AttachedDocument(
        key: map['key'] as String?,
        name: map['name'] ?? '',
        url: map['url'] ?? '',
        uploadedAt: map['uploadedAt'] != null
            ? DateTime.tryParse(map['uploadedAt'])
            : null,
      );
}

/// Defines a named document slot, e.g.
/// DocumentRequirement(key: 'insurance', label: 'Insurance Certificate', required: true)
///
/// Pass an empty list to [AttachDocumentButton.requirements] to fall back to
/// the old plain "attach anything" behaviour with no validation.
class DocumentRequirement {
  final String key;
  final String label;
  final bool required;

  /// When false (default), attaching a new file to this slot REPLACES
  /// whatever was there before — the original single-document-per-slot
  /// behaviour (e.g. "Registration Certificate").
  ///
  /// When true, the slot behaves like a mini folder: every file you
  /// attach is kept, and the "Attach" button becomes "Add" — useful for
  /// slots like "Photos" or "Invoice" that naturally hold more than one
  /// file (this is how bulk-imported drone document categories work).
  final bool allowMultiple;

  const DocumentRequirement({
    required this.key,
    required this.label,
    this.required = true,
    this.allowMultiple = false,
  });
}

class AttachDocumentButton extends StatefulWidget {
  /// Existing documents (e.g. when editing a record that already has docs)
  final List<AttachedDocument> initialDocuments;

  /// Called every time the list of documents changes.
  final ValueChanged<List<AttachedDocument>> onDocumentsChanged;

  /// Optional named/required document slots. Leave empty for a plain flat
  /// list with no validation.
  final List<DocumentRequirement> requirements;

  /// Fired whenever validity (all required slots filled) changes.
  final ValueChanged<bool>? onValidityChanged;

  /// If provided, every change is written straight to this Firestore
  /// document, e.g. 'companies/abc123' or 'drones/${drone.id}'.
  final String? firestorePath;
  final String firestoreField;

  /// Allow attaching extra, non-required documents alongside the required
  /// slots above (ignored if [requirements] is empty — extra is then the
  /// only mode).
  final bool allowExtraDocuments;

  const AttachDocumentButton({
    super.key,
    this.initialDocuments = const [],
    required this.onDocumentsChanged,
    this.requirements = const [],
    this.onValidityChanged,
    this.firestorePath,
    this.firestoreField = 'documents',
    this.allowExtraDocuments = true,
  });

  @override
  State<AttachDocumentButton> createState() => AttachDocumentButtonState();
}

class AttachDocumentButtonState extends State<AttachDocumentButton> {
  late List<AttachedDocument> _documents;
  bool _uploading = false;
  String? _uploadingKey; // '' = extra-doc upload, 'req.key' = slot upload, 'replace:<url>' = replace
  bool _showValidationErrors = false;

  // --- Cloudinary config: same as your other modules ---
  static const String _cloudName = 'vmi67fhz';
  static const String _uploadPreset = 'rpto_unsigned';

  @override
  void initState() {
    super.initState();
    _documents = List.of(widget.initialDocuments);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportValidity());
  }

  // ---------------- validation ----------------

  /// True when every required slot in [widget.requirements] has a document.
  bool get isValid {
    for (final req in widget.requirements) {
      if (req.required && !_documents.any((d) => d.key == req.key)) {
        return false;
      }
    }
    return true;
  }

  /// Call this from the parent form (via a GlobalKey<AttachDocumentButtonState>)
  /// right before saving, to force-highlight any missing required documents.
  /// Returns true if valid.
  bool validate() {
    setState(() => _showValidationErrors = true);
    return isValid;
  }

  void _reportValidity() => widget.onValidityChanged?.call(isValid);

  // ---------------- persistence ----------------

  Future<void> _persist() async {
    widget.onDocumentsChanged(_documents);
    _reportValidity();

    final path = widget.firestorePath;
    if (path == null) return;
    try {
      await FirebaseFirestore.instance.doc(path).set(
        {widget.firestoreField: _documents.map((d) => d.toMap()).toList()},
        SetOptions(merge: true),
      );
    } catch (e) {
      _showError('Could not save documents: $e');
    }
  }

  // ---------------- upload / replace / delete ----------------

  // File types accepted everywhere documents are attached — includes
  // spreadsheets (xlsx/xls/csv) alongside pdf/images/word docs so the
  // batch-module screens (Schedule, Logbook, Master Sheet, etc.) can
  // actually take the Excel files they're meant to hold.
  static const List<String> _acceptedExtensions = [
    'pdf', 'jpg', 'jpeg', 'png', 'webp', 'doc', 'docx', 'HEIC',
    'xls', 'xlsx', 'csv',
  ];

  Future<void> _pickAndUpload({String? key, bool allowMultiple = false}) async {
    // Bulk import: let the user select several files in one go. A
    // single-value slot (key != null && !allowMultiple) still only keeps
    // one document, but freeform "Attach Document" and folder-style
    // ("Add") slots can take a whole batch of files at once.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _acceptedExtensions,
      withData: true, // important for Flutter Web
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    var picked = result.files.where((f) => f.bytes != null).toList();
    if (picked.isEmpty) return;

    // A single-value slot can only ever hold one document, so uploading
    // more than one selected file to it would just mean the extras get
    // discarded after being uploaded — keep only the first instead.
    if (key != null && !allowMultiple && picked.length > 1) {
      picked = [picked.first];
    }

    setState(() {
      _uploading = true;
      _uploadingKey = key ?? '';
    });

    var uploadedAny = false;
    for (final file in picked) {
      final Uint8List bytes = file.bytes!;
      try {
        final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload',
        );
        final request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = _uploadPreset
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: file.name),
          );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final url = RegExp(r'"secure_url":"([^"]+)"')
              .firstMatch(response.body)
              ?.group(1)
              ?.replaceAll(r'\/', '/');

          if (url != null) {
            final doc = AttachedDocument(key: key, name: file.name, url: url);
            setState(() {
              // a single-value slot can only ever hold one document —
              // replace it. A multi-value slot (allowMultiple) just grows.
              if (key != null && !allowMultiple) {
                _documents.removeWhere((d) => d.key == key);
              }
              _documents.add(doc);
            });
            uploadedAny = true;
          }
        } else {
          _showError('Upload failed for ${file.name}: ${response.statusCode}');
        }
      } catch (e) {
        _showError('Upload error for ${file.name}: $e');
      }
    }

    if (uploadedAny) await _persist();

    if (mounted) {
      setState(() {
        _uploading = false;
        _uploadingKey = null;
      });
    }
  }

  Future<void> _removeDocument(AttachedDocument doc) async {
    setState(() => _documents.remove(doc));
    await _persist();
  }

  /// Shows a themed confirmation dialog before permanently removing a
  /// document — deleting used to happen instantly on tap, which was an
  /// easy way to lose a file by accident.
  Future<void> _confirmDelete(AttachedDocument doc, CompanyColors c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Document',
            style: GoogleFonts.plusJakartaSans(
                color: c.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Delete "${doc.name}"? This cannot be undone.',
          style: GoogleFonts.plusJakartaSans(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Delete',
                style: GoogleFonts.plusJakartaSans(
                    color: c.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _removeDocument(doc);
  }

  /// Replaces [oldDoc] with a newly picked file, keeping the same slot
  /// key and position in the list. Works for a required-slot document,
  /// a folder-style (multi) document, or a freeform extra document —
  /// [oldDoc.key] already carries whichever of those it is.
  Future<void> _replaceDocument(AttachedDocument oldDoc) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _acceptedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return;

    setState(() {
      _uploading = true;
      _uploadingKey = 'replace:${oldDoc.url}';
    });

    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload',
      );
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: file.name),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final url = RegExp(r'"secure_url":"([^"]+)"')
            .firstMatch(response.body)
            ?.group(1)
            ?.replaceAll(r'\/', '/');

        if (url != null) {
          final newDoc = AttachedDocument(key: oldDoc.key, name: file.name, url: url);
          setState(() {
            final index = _documents.indexOf(oldDoc);
            if (index != -1) {
              _documents[index] = newDoc;
            } else {
              _documents.add(newDoc);
            }
          });
          await _persist();
        }
      } else {
        _showError('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Upload error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadingKey = null;
        });
      }
    }
  }

  /// Opens the document right inside the app (PDF / image preview) —
  /// no more getting bounced out to the browser.
  void _openDocument(AttachedDocument doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(name: doc.name, url: doc.url),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp')) {
      return Icons.image_outlined;
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description_outlined;
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || lower.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final c = CompanyColors.of(false);
    final extraDocs = _documents.where((d) => d.key == null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.requirements.isNotEmpty) ...[
          ...widget.requirements.map((req) => _buildRequirementRow(req, c)),
          const SizedBox(height: 12),
        ],
        if (widget.allowExtraDocuments || widget.requirements.isEmpty) ...[
          _buildAttachButton(
            c: c,
            label: 'Attach Documents',
            uploading: _uploading && _uploadingKey == '',
            onTap: _uploading ? null : () => _pickAndUpload(),
          ),
          const SizedBox(height: 10),
          ...extraDocs.map((doc) => _buildExtraDocRow(doc, c)),
        ],
      ],
    );
  }

  /// Small pill of View / Edit / Delete icon buttons used consistently
  /// across every document row (single-slot, folder/multi-slot, and
  /// freeform extra documents) so the whole page reads the same way.
  Widget _actionIcons(
      AttachedDocument doc,
      CompanyColors c, {
        bool busy = false,
      }) {
    if (busy) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          icon: Icon(Icons.visibility_outlined, color: c.accent, size: 18),
          tooltip: 'View',
          onPressed: () => _openDocument(doc),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          icon: Icon(Icons.edit_outlined, color: c.accent, size: 18),
          tooltip: 'Replace',
          onPressed: _uploading ? null : () => _replaceDocument(doc),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          icon: Icon(Icons.delete_outline, color: c.danger, size: 18),
          tooltip: 'Delete',
          onPressed: () => _confirmDelete(doc, c),
        ),
      ],
    );
  }

  Widget _buildRequirementRow(DocumentRequirement req, CompanyColors c) {
    if (req.allowMultiple) return _buildMultiRequirementRow(req, c);

    AttachedDocument? doc;
    for (final d in _documents) {
      if (d.key == req.key) {
        doc = d;
        break;
      }
    }
    final missing = req.required && doc == null;
    final showError = _showValidationErrors && missing;
    final busy = _uploading &&
        (_uploadingKey == req.key || _uploadingKey == 'replace:${doc?.url}');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: showError ? c.danger : c.borderSubtle.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accent.withValues(alpha: 0.12),
            ),
            child: Icon(
              doc != null ? _fileIcon(doc.name) : Icons.folder_outlined,
              color: c.accent,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      req.label,
                      style: GoogleFonts.plusJakartaSans(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    if (req.required) ...[
                      const SizedBox(width: 4),
                      Text('*',
                          style: GoogleFonts.plusJakartaSans(
                              color: c.danger, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  doc != null ? doc.name : (showError ? 'Required — not attached' : 'Not attached'),
                  style: GoogleFonts.plusJakartaSans(
                    color: doc != null
                        ? c.textSecondary
                        : (showError ? c.danger : c.textSecondary.withValues(alpha: 0.6)),
                    fontSize: 12.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (doc != null)
            _actionIcons(doc, c, busy: busy)
          else if (busy)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
            )
          else
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              icon: Icon(Icons.attach_file, color: c.accent, size: 18),
              tooltip: 'Attach',
              onPressed: _uploading ? null : () => _pickAndUpload(key: req.key),
            ),
        ],
      ),
    );
  }

  /// A "folder-style" requirement slot that can hold more than one file
  /// (e.g. Photos, Invoice, Warranty for a drone). Shows every attached
  /// document for [req.key] as its own row — each with View / Edit /
  /// Delete icons — plus an "Add" affordance for the folder itself.
  Widget _buildMultiRequirementRow(DocumentRequirement req, CompanyColors c) {
    final docs = _documents.where((d) => d.key == req.key).toList();
    final missing = req.required && docs.isEmpty;
    final showError = _showValidationErrors && missing;
    final uploadingHere = _uploading && _uploadingKey == req.key;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: showError ? c.danger : c.borderSubtle.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.folder_outlined, color: c.accent, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      req.label,
                      style: GoogleFonts.plusJakartaSans(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${docs.length}',
                        style: GoogleFonts.plusJakartaSans(
                            color: c.accent, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (req.required) ...[
                      const SizedBox(width: 4),
                      Text('*',
                          style: GoogleFonts.plusJakartaSans(
                              color: c.danger, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              if (uploadingHere)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                )
              else
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  icon: Icon(Icons.add_circle_outline, color: c.accent, size: 20),
                  tooltip: 'Add',
                  onPressed: _uploading
                      ? null
                      : () => _pickAndUpload(key: req.key, allowMultiple: true),
                ),
            ],
          ),
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 46),
              child: Text(
                showError ? 'Required — not attached' : 'Not attached',
                style: GoogleFonts.plusJakartaSans(
                  color: showError ? c.danger : c.textSecondary.withValues(alpha: 0.6),
                  fontSize: 12.5,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 46),
              child: Column(
                children: docs.map((d) {
                  final busy = _uploading && _uploadingKey == 'replace:${d.url}';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.background.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: c.borderSubtle.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      children: [
                        Icon(_fileIcon(d.name), color: c.textSecondary, size: 15),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            d.name,
                            style: GoogleFonts.plusJakartaSans(
                                color: c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _actionIcons(d, c, busy: busy),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachButton({
    required CompanyColors c,
    required String label,
    required bool uploading,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            uploading
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
            )
                : Icon(Icons.attach_file, color: c.accent, size: 18),
            const SizedBox(width: 8),
            Text(
              uploading ? 'Uploading...' : label,
              style: GoogleFonts.plusJakartaSans(color: c.accent, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraDocRow(AttachedDocument doc, CompanyColors c) {
    final busy = _uploading && _uploadingKey == 'replace:${doc.url}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderSubtle.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accent.withValues(alpha: 0.12),
            ),
            child: Icon(_fileIcon(doc.name), color: c.accent, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              doc.name,
              style: GoogleFonts.plusJakartaSans(
                  color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _actionIcons(doc, c, busy: busy),
        ],
      ),
    );
  }
}