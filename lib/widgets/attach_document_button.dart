import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---- Design constants (match these to your existing _kNavy/_kTeal etc.) ----
const Color _kNavy = Color(0xFF0B1220);
const Color _kSurface = Color(0xFF141B2D);
const Color _kTeal = Color(0xFF14B8A6);
const Color _kDanger = Color(0xFFEF4444);

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

  const DocumentRequirement({
    required this.key,
    required this.label,
    this.required = true,
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
  String? _uploadingKey; // '' = extra-doc upload, else requirement.key
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

  Future<void> _pickAndUpload({String? key}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: true, // important for Flutter Web
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return;

    setState(() {
      _uploading = true;
      _uploadingKey = key ?? '';
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
          final doc = AttachedDocument(key: key, name: file.name, url: url);
          setState(() {
            // a required slot can only ever hold one document — replace it
            if (key != null) {
              _documents.removeWhere((d) => d.key == key);
            }
            _documents.add(doc);
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

  Future<void> _removeDocument(AttachedDocument doc) async {
    setState(() => _documents.remove(doc));
    await _persist();
  }

  /// Replace an existing extra/optional document with a newly picked file,
  /// keeping the same position in the list.
  Future<void> _replaceExtraDocument(AttachedDocument oldDoc) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
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
          final newDoc = AttachedDocument(name: file.name, url: url);
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

  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    final launched =
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) _showError('Could not open document');
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final extraDocs = _documents.where((d) => d.key == null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.requirements.isNotEmpty) ...[
          ...widget.requirements.map(_buildRequirementRow),
          const SizedBox(height: 12),
        ],
        if (widget.allowExtraDocuments || widget.requirements.isEmpty) ...[
          _buildAttachButton(
            label: 'Attach Document',
            uploading: _uploading && _uploadingKey == '',
            onTap: _uploading ? null : () => _pickAndUpload(),
          ),
          const SizedBox(height: 10),
          ...extraDocs.map(_buildExtraDocRow),
        ],
      ],
    );
  }

  Widget _buildRequirementRow(DocumentRequirement req) {
    AttachedDocument? doc;
    for (final d in _documents) {
      if (d.key == req.key) {
        doc = d;
        break;
      }
    }
    final missing = req.required && doc == null;
    final showError = _showValidationErrors && missing;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: showError ? _kDanger : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      req.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (req.required) ...[
                      const SizedBox(width: 4),
                      const Text('*',
                          style: TextStyle(
                              color: _kDanger, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (doc != null)
                  InkWell(
                    onTap: () => _openDocument(doc!.url),
                    child: Text(
                      doc.name,
                      style: const TextStyle(
                        color: _kTeal,
                        decoration: TextDecoration.underline,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  Text(
                    showError ? 'Required — not attached' : 'Not attached',
                    style: TextStyle(
                      color: showError ? _kDanger : Colors.white38,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          if (_uploading && _uploadingKey == req.key)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kTeal),
            )
          else ...[
            IconButton(
              icon: Icon(
                doc == null ? Icons.attach_file : Icons.edit_outlined,
                color: _kTeal,
                size: 18,
              ),
              tooltip: doc == null ? 'Attach' : 'Replace',
              onPressed:
              _uploading ? null : () => _pickAndUpload(key: req.key),
            ),
            if (doc != null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                tooltip: 'Delete',
                onPressed: () => _removeDocument(doc!),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachButton({
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
          color: _kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kTeal.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            uploading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _kTeal),
            )
                : const Icon(Icons.attach_file, color: _kTeal, size: 18),
            const SizedBox(width: 8),
            Text(
              uploading ? 'Uploading...' : label,
              style:
              const TextStyle(color: _kTeal, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraDocRow(AttachedDocument doc) {
    final isReplacing = _uploading && _uploadingKey == 'replace:${doc.url}';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file,
                color: Colors.white54, size: 18),
            const SizedBox(width: 8),
            Expanded(
              // View — tap the file name to open it
              child: InkWell(
                onTap: () => _openDocument(doc.url),
                child: Text(
                  doc.name,
                  style: const TextStyle(
                    color: _kTeal,
                    decoration: TextDecoration.underline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (isReplacing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kTeal),
                ),
              )
            else
            // Update — replace this file with a newly picked one
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: _kTeal, size: 18),
                tooltip: 'Replace',
                onPressed: _uploading ? null : () => _replaceExtraDocument(doc),
              ),
            // Delete
            IconButton(
              icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
              tooltip: 'Delete document',
              onPressed: () => _removeDocument(doc),
            ),
          ],
        ),
      ),
    );
  }
}