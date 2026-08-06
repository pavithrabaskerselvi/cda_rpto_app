import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/attach_document_button.dart';

export '../../widgets/attach_document_button.dart'
    show DocumentRequirement, AttachedDocument;

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

  void _goBack() {
    _docsKey.currentState?.validate();
    Navigator.of(context).pop(_current);
  }

  Widget _buildThemeToggle(bool isDark, CompanyColors c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wb_sunny_outlined,
            size: 18, color: isDark ? c.textSecondary : c.accent),
        Switch(
          value: isDark,
          activeColor: c.accent,
          onChanged: (val) => context.read<ThemeProvider>().toggleTheme(val),
        ),
        Icon(Icons.nightlight_round,
            size: 18, color: isDark ? c.accent : c.textSecondary),
      ],
    );
  }

  // ---- gradient hero header, matching the Drone Details premium style ----
  Widget _header(BuildContext context, bool isDark, CompanyColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.gold.withValues(alpha: 0.18),
            c.accent.withValues(alpha: 0.12),
            c.background,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back, color: c.textPrimary),
                onPressed: _goBack,
              ),
              const Spacer(),
              _buildThemeToggle(isDark, c),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.title,
            style: GoogleFonts.plusJakartaSans(
              color: c.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 15, color: c.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${_current.length} file${_current.length == 1 ? '' : 's'} attached',
                style: GoogleFonts.plusJakartaSans(
                  color: c.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final c = CompanyColors.of(isDark);

    return WillPopScope(
      onWillPop: () async {
        _goBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, isDark, c),
            Expanded(
              child: FutureBuilder<List<AttachedDocument>>(
                future: _loadFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(
                      child: CircularProgressIndicator(color: c.accent),
                    );
                  }

                  final loadedDocs = snapshot.data ?? [];
                  if (_current.isEmpty && loadedDocs.isNotEmpty) {
                    _current = loadedDocs;
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      if (!_valid && widget.requirements.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.danger.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: c.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Some required documents are missing.',
                                  style: GoogleFonts.plusJakartaSans(
                                      color: c.danger, fontSize: 13, fontWeight: FontWeight.w500),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
