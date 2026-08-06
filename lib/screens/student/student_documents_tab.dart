import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme_colors.dart';

const Color _pAccent = Color(0xFF2DD4BF);

/// Outcome of one file in a bulk upload run — shown in the results
/// summary sheet after [StudentDocumentsTab._bulkUploadDocuments]
/// finishes.
class _BulkUploadResult {
  final String fileName;
  final String title;
  final bool success;
  final String? errorMessage;

  _BulkUploadResult({
    required this.fileName,
    required this.title,
    required this.success,
    this.errorMessage,
  });
}

class StudentDocumentsTab extends StatefulWidget {
  final String studentId;
  final String? studentName;
  const StudentDocumentsTab({super.key, required this.studentId, this.studentName});

  @override
  State<StudentDocumentsTab> createState() => _StudentDocumentsTabState();
}

class _StudentDocumentsTabState extends State<StudentDocumentsTab> {
  bool _uploading = false;
  bool _exporting = false;

  bool _bulkUploading = false;
  int _bulkTotal = 0;
  int _bulkProcessed = 0;
  String? _bulkCurrentFileName;

  static const String _cloudName = 'vmi67fhz';
  static const String _uploadPreset = 'rpto_unsigned';

  CollectionReference get _docsRef => FirebaseFirestore.instance
      .collection('students')
      .doc(widget.studentId)
      .collection('documents');

  // ---------------- Core upload (Cloudinary + Firestore) ----------------

  /// Uploads [bytes] to Cloudinary and writes/updates the Firestore doc
  /// record under [title]. Shared by both the single-file "+" upload and
  /// the bulk multi-file upload below. Throws on failure — callers
  /// decide how to surface that (SnackBar for single, per-item result
  /// for bulk).
  Future<void> _performUpload({
    required String title,
    required String fileName,
    required Uint8List bytes,
    String? existingDocId,
  }) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/auto/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode}');
    }

    final url = RegExp(r'"secure_url":"([^"]+)"')
        .firstMatch(response.body)
        ?.group(1)
        ?.replaceAll(r'\/', '/');

    if (url == null) {
      throw Exception('Upload succeeded but no URL was returned');
    }

    final data = {
      'title': title,
      'fileName': fileName,
      'url': url,
      'uploadedAt': Timestamp.now(),
    };

    if (existingDocId != null) {
      await _docsRef.doc(existingDocId).update(data);
    } else {
      await _docsRef.add(data);
    }
  }

  Future<void> _uploadDocument({required String title, String? existingDocId}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final Uint8List? bytes = picked.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected file'), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    setState(() => _uploading = true);
    try {
      await _performUpload(
        title: title,
        fileName: picked.name,
        bytes: bytes,
        existingDocId: existingDocId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ---------------- Bulk upload (multiple files at once) ----------------

  /// Every file picked in bulk is added as its own document, titled
  /// after the file's own name (extension stripped) — no attempt to
  /// match it to the fixed Aadhar/Medical/Photo slots. Those three
  /// still work individually via the "+" button on each row; bulk is
  /// purely "add everything I selected" for a student, same as
  /// Additional Documents.
  String _titleFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final nameOnly = dot == -1 ? fileName : fileName.substring(0, dot);
    return nameOnly.trim().isEmpty ? fileName : nameOnly.trim();
  }

  Future<void> _bulkUploadDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final pickedFiles = result.files.where((f) => f.bytes != null).toList();
    if (pickedFiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected files'), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    setState(() {
      _bulkUploading = true;
      _bulkTotal = pickedFiles.length;
      _bulkProcessed = 0;
      _bulkCurrentFileName = null;
    });

    final results = <_BulkUploadResult>[];

    for (final file in pickedFiles) {
      final title = _titleFromFileName(file.name);
      setState(() => _bulkCurrentFileName = file.name);

      try {
        // Always added as a new document — bulk import never overwrites
        // an existing record, even if the title happens to match one.
        await _performUpload(
          title: title,
          fileName: file.name,
          bytes: file.bytes!,
          existingDocId: null,
        );
        results.add(_BulkUploadResult(fileName: file.name, title: title, success: true));
      } catch (e) {
        results.add(
          _BulkUploadResult(fileName: file.name, title: title, success: false, errorMessage: '$e'),
        );
      }

      setState(() => _bulkProcessed++);
    }

    if (mounted) {
      setState(() {
        _bulkUploading = false;
        _bulkCurrentFileName = null;
      });
      _showBulkResultsSheet(results);
    }
  }

  void _showBulkResultsSheet(List<_BulkUploadResult> results) {
    final succeeded = results.where((r) => r.success).length;
    final failed = results.length - succeeded;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final maxSheetHeight = MediaQuery.of(sheetContext).size.height * 0.85;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: ThemeColors.textMuted(sheetContext),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Bulk Import Complete',
                    style: GoogleFonts.plusJakartaSans(
                      color: ThemeColors.textPrimary(sheetContext),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$succeeded succeeded'
                        '${failed > 0 ? ' • $failed failed' : ''}',
                    style: GoogleFonts.plusJakartaSans(
                      color: failed > 0 ? Colors.redAccent : ThemeColors.textMuted(sheetContext),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final r = results[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            r.success ? Icons.check_circle : Icons.error_outline,
                            color: r.success ? _pAccent : Colors.redAccent,
                            size: 20,
                          ),
                          title: Text(
                            r.fileName,
                            style: GoogleFonts.plusJakartaSans(
                              color: ThemeColors.textPrimary(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            r.success ? 'Saved as "${r.title}"' : (r.errorMessage ?? 'Unknown error'),
                            style: GoogleFonts.plusJakartaSans(
                              color: ThemeColors.textMuted(context),
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open document'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _addCustomDocument() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ThemeColors.surface(dialogContext),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Document',
            style: GoogleFonts.plusJakartaSans(
                color: ThemeColors.textPrimary(dialogContext), fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.plusJakartaSans(color: ThemeColors.textPrimary(dialogContext)),
          decoration: InputDecoration(
            hintText: 'Document name (e.g. Passport)',
            hintStyle: GoogleFonts.plusJakartaSans(color: ThemeColors.textMuted(dialogContext)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(color: ThemeColors.textSecondary(dialogContext))),
          ),
          TextButton(
            onPressed: () {
              final title = controller.text.trim();
              Navigator.pop(dialogContext);
              if (title.isNotEmpty) _uploadDocument(title: title);
            },
            child: Text('Upload',
                style: GoogleFonts.plusJakartaSans(color: _pAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ---------------- Export: PDF ----------------

  Future<void> _exportAsPdf(List<QueryDocumentSnapshot> docs) async {
    setState(() => _exporting = true);
    try {
      final rows = _buildExportRows(docs);
      final pdfDoc = pw.Document();

      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${widget.studentName ?? 'Student'} — Documents',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated on ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 16),
                pw.TableHelper.fromTextArray(
                  headers: const ['Document', 'Status', 'Uploaded On'],
                  data: rows,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.2),
                    1: const pw.FlexColumnWidth(1.2),
                    2: const pw.FlexColumnWidth(1.6),
                  },
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdfDoc.save();
      final fileName = '${_safeFileName(widget.studentName ?? widget.studentId)}_documents.pdf';
      await _saveAndShare(bytes, fileName);
    } catch (e) {
      _showError('PDF export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ---------------- Export: Excel ----------------

  Future<void> _exportAsExcel(List<QueryDocumentSnapshot> docs) async {
    setState(() => _exporting = true);
    try {
      final rows = _buildExportRows(docs);
      final excel = Excel.createExcel();
      final sheet = excel['Documents'];
      excel.setDefaultSheet('Documents');

      sheet.appendRow(
        const ['Document', 'Status', 'Uploaded On'].map(TextCellValue.new).toList(),
      );
      for (final row in rows) {
        sheet.appendRow(row.map(TextCellValue.new).toList());
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel file');

      final fileName = '${_safeFileName(widget.studentName ?? widget.studentId)}_documents.xlsx';
      await _saveAndShare(Uint8List.fromList(bytes), fileName);
    } catch (e) {
      _showError('Excel export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<List<String>> _buildExportRows(List<QueryDocumentSnapshot> docs) {
    return docs.map((d) => _rowFor(d['title'] as String, d)).toList();
  }

  List<String> _rowFor(String title, QueryDocumentSnapshot? doc) {
    final uploaded = doc != null && doc['uploadedAt'] != null
        ? DateFormat('dd MMM yyyy').format((doc['uploadedAt'] as Timestamp).toDate())
        : '-';
    return [title, doc != null ? 'Uploaded' : 'Not uploaded', uploaded];
  }

  String _safeFileName(String input) =>
      input.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');

  Future<void> _saveAndShare(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: fileName);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showExportMenu(List<QueryDocumentSnapshot> docs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: ThemeColors.textMuted(sheetContext),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: _pAccent),
              title: Text('Export as PDF',
                  style: GoogleFonts.plusJakartaSans(
                      color: ThemeColors.textPrimary(sheetContext), fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportAsPdf(docs);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: _pAccent),
              title: Text('Export as Excel',
                  style: GoogleFonts.plusJakartaSans(
                      color: ThemeColors.textPrimary(sheetContext), fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportAsExcel(docs);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _docsRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: _pAccent));
            }

            final allDocs = snapshot.data!.docs;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Documents',
                        style: GoogleFonts.plusJakartaSans(
                            color: ThemeColors.textPrimary(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 17)),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: (_uploading || _bulkUploading) ? null : _bulkUploadDocuments,
                          icon: const Icon(Icons.upload_file, color: _pAccent, size: 18),
                          label: Text('Bulk Import',
                              style: GoogleFonts.plusJakartaSans(
                                  color: _pAccent, fontWeight: FontWeight.w600)),
                        ),
                        TextButton.icon(
                          onPressed: _uploading ? null : _addCustomDocument,
                          icon: const Icon(Icons.add, color: _pAccent, size: 18),
                          label: Text('Add',
                              style: GoogleFonts.plusJakartaSans(
                                  color: _pAccent, fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.ios_share, color: _pAccent),
                          tooltip: 'Export',
                          onPressed: _exporting ? null : () => _showExportMenu(allDocs),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...allDocs.map((doc) => _docTile(context,
                    title: doc['title'] as String, doc: doc, onUpload: null)),
              ],
            );
          },
        ),
        if (_uploading || _exporting)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator(color: _pAccent)),
          ),
        if (_bulkUploading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Container(
                width: 260,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ThemeColors.surface(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: _pAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Uploading $_bulkProcessed of $_bulkTotal',
                      style: GoogleFonts.plusJakartaSans(
                        color: ThemeColors.textPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_bulkCurrentFileName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _bulkCurrentFileName!,
                        style: GoogleFonts.plusJakartaSans(
                          color: ThemeColors.textMuted(context),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _docTile(BuildContext context,
      {required String title, QueryDocumentSnapshot? doc, VoidCallback? onUpload}) {
    final hasFile = doc != null;
    final uploadedAt = hasFile && doc['uploadedAt'] != null
        ? (doc['uploadedAt'] as Timestamp).toDate()
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThemeColors.divider(context)),
      ),
      child: Row(
        children: [
          Icon(hasFile ? Icons.insert_drive_file : Icons.upload_file,
              color: hasFile ? _pAccent : ThemeColors.textMuted(context), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.plusJakartaSans(
                        color: ThemeColors.textPrimary(context), fontWeight: FontWeight.w600)),
                if (uploadedAt != null)
                  Text(
                    'Uploaded ${DateFormat('dd MMM yyyy').format(uploadedAt)}',
                    style: GoogleFonts.plusJakartaSans(
                        color: ThemeColors.textMuted(context), fontSize: 12),
                  )
                else
                  Text('Not uploaded',
                      style: GoogleFonts.plusJakartaSans(
                          color: ThemeColors.textMuted(context), fontSize: 12)),
              ],
            ),
          ),
          if (hasFile)
            IconButton(
              icon: const Icon(Icons.open_in_new, color: _pAccent, size: 20),
              tooltip: 'View',
              onPressed: () => _openDocument(doc['url'] as String),
            ),
          if (onUpload != null)
            IconButton(
              icon: Icon(hasFile ? Icons.refresh : Icons.add_circle_outline, color: _pAccent),
              tooltip: hasFile ? 'Replace' : 'Upload',
              onPressed: _uploading ? null : onUpload,
            ),
        ],
      ),
    );
  }
}