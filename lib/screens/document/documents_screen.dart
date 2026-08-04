import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/attach_document_button.dart';

export '../../widgets/attach_document_button.dart'
    show DocumentRequirement, AttachedDocument;

// ---- Design constants (match your app theme) ----
const Color _kNavy = Color(0xFF0B1220);
const Color _kSurface = Color(0xFF141B2D);
const Color _kTeal = Color(0xFF14B8A6);

/// Full-screen "Documents" page. Push this from any detail screen
/// (drone detail, company detail, pilot detail, etc.) by passing the
/// Firestore path for that record and the list of required doc slots.
///
/// Usage:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => DocumentsScreen(
///     title: 'fpv Documents',
///     firestorePath: 'drones/${drone.id}',
///     requirements: const [
///       DocumentRequirement(key: 'registration_certificate', label: 'Registration Certificate'),
///       DocumentRequirement(key: 'insurance', label: 'Insurance'),
///       DocumentRequirement(key: 'manual', label: 'Manual', required: false),
///     ],
///     initialDocuments: drone.documents, // List<AttachedDocument>
///   ),
/// ));
/// ```
class DocumentsScreen extends StatefulWidget {
  final String title;
  final String firestorePath;
  final String firestoreField;
  final List<DocumentRequirement> requirements;

  /// Optional — if you already have the documents loaded (e.g. from the
  /// model), pass them here to skip the initial Firestore read. If left
  /// empty, the screen fetches them itself from [firestorePath].
  final List<AttachedDocument> initialDocuments;
  final bool allowExtraDocuments;

  const DocumentsScreen({
    super.key,
    this.title = 'Documents',
    required this.firestorePath,
    this.firestoreField = 'documents',
    this.requirements = const [],
    this.initialDocuments = const [],
    this.allowExtraDocuments = true,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _docsKey = GlobalKey<AttachDocumentButtonState>();
  bool _valid = true;
  List<AttachedDocument> _current = [];
  late Future<List<AttachedDocument>> _loadFuture;

  @override
  void initState() {
    super.initState();
    _current = List.of(widget.initialDocuments);
    _loadFuture = widget.initialDocuments.isNotEmpty
        ? Future.value(widget.initialDocuments)
        : _fetchFromFirestore();
  }

  Future<List<AttachedDocument>> _fetchFromFirestore() async {
    try {
      final snap = await FirebaseFirestore.instance.doc(widget.firestorePath).get();
      final raw = snap.data()?[widget.firestoreField] as List<dynamic>?;
      if (raw == null) return [];
      return raw
          .map((m) => AttachedDocument.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNavy,
      appBar: AppBar(
        backgroundColor: _kNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Force-highlight any missing required docs before leaving,
            // but still allow navigation back either way.
            _docsKey.currentState?.validate();
            Navigator.of(context).pop(_current);
          },
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FutureBuilder<List<AttachedDocument>>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: _kTeal),
            );
          }

          final loadedDocs = snapshot.data ?? [];
          if (_current.isEmpty && loadedDocs.isNotEmpty) {
            _current = loadedDocs;
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_valid && widget.requirements.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kSurface,
                        borderRadius: BorderRadius.circular(8),
                        border:
                        Border.all(color: Colors.redAccent.withOpacity(0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Some required documents are missing.',
                              style:
                              TextStyle(color: Colors.redAccent, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  AttachDocumentButton(
                    key: _docsKey,
                    firestorePath: widget.firestorePath,
                    firestoreField: widget.firestoreField,
                    requirements: widget.requirements,
                    initialDocuments: loadedDocs,
                    allowExtraDocuments: widget.allowExtraDocuments,
                    onDocumentsChanged: (docs) =>
                        setState(() => _current = docs),
                    onValidityChanged: (valid) => setState(() => _valid = valid),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}