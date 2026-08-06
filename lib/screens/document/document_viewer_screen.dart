import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import 'pdf_web_frame.dart';

enum _ViewerKind { pdf, image, unsupported }

/// Full-screen, in-app viewer for a single attached document.
///
/// PDFs are downloaded as bytes with the same `http` client the rest of
/// this app already uses successfully against Cloudinary (uploads,
/// exports, etc.) and handed to Syncfusion's viewer via
/// [SfPdfViewer.memory] — letting Syncfusion fetch the URL itself with
/// [SfPdfViewer.network] turned out to fail silently for some Cloudinary
/// URLs (CORS / redirect quirks), so we do the fetch ourselves and get a
/// real error message if it fails.
///
/// Images get an [InteractiveViewer] for pinch-zoom. Anything else
/// (doc/docx, etc.) falls back to a friendly "can't preview this" card
/// with an explicit "Open in Browser" button, so nothing is a dead end.
///
/// Usage:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => DocumentViewerScreen(name: doc.name, url: doc.url),
/// ));
/// ```
class DocumentViewerScreen extends StatefulWidget {
  final String name;
  final String url;

  const DocumentViewerScreen({super.key, required this.name, required this.url});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  late Future<Uint8List> _pdfBytesFuture;
  int _pdfCurrentPage = 0;
  int _pdfTotalPages = 0;

  // Set by onDocumentLoadFailed — the bytes downloaded fine, but Syncfusion
  // couldn't parse/render them as a PDF (corrupted export, unsupported
  // encryption, etc). We flip the body over to the proper error card
  // instead of leaving a blank viewer with just a passing SnackBar.
  String? _pdfRenderError;

  static const _imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'];

  @override
  void initState() {
    super.initState();
    // On web the iframe embed (see pdf_web_frame.dart) hands the URL
    // straight to the browser's own PDF engine, so there's no need to
    // download bytes ourselves there — only the mobile/desktop path
    // (Syncfusion-from-memory) needs them.
    if (_kind == _ViewerKind.pdf && !isRunningOnWeb) {
      _pdfBytesFuture = _fetchPdfBytes();
    }
  }

  Future<Uint8List> _fetchPdfBytes() async {
    final response = await http.get(Uri.parse(widget.url));
    if (response.statusCode != 200) {
      throw Exception('Server returned ${response.statusCode}');
    }
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw Exception('Empty file received');
    }
    // A real PDF always starts with the "%PDF-" magic header. If it
    // doesn't, the URL served something else — an HTML error/login page,
    // a CORS-blocked stub, etc — so fail fast with a clear reason instead
    // of handing garbage to the renderer.
    final looksLikePdf = bytes.length > 5 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46 && // F
        bytes[4] == 0x2D; // -
    if (!looksLikePdf) {
      throw Exception('The server did not return a valid PDF file');
    }
    return bytes;
  }

  _ViewerKind get _kind {
    final urlLower = widget.url.toLowerCase().split('?').first;
    final nameLower = widget.name.toLowerCase();

    if (urlLower.endsWith('.pdf') || nameLower.endsWith('.pdf')) {
      return _ViewerKind.pdf;
    }
    if (_imageExtensions.any((ext) => urlLower.endsWith(ext)) ||
        _imageExtensions.any((ext) => nameLower.endsWith(ext))) {
      return _ViewerKind.image;
    }
    return _ViewerKind.unsupported;
  }

  IconData get _fileIcon {
    switch (_kind) {
      case _ViewerKind.pdf:
        return Icons.picture_as_pdf_outlined;
      case _ViewerKind.image:
        return Icons.image_outlined;
      case _ViewerKind.unsupported:
        return Icons.insert_drive_file_outlined;
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _retryPdf() {
    setState(() {
      _pdfRenderError = null;
      _pdfBytesFuture = _fetchPdfBytes();
    });
  }

  Widget _header(BuildContext context, bool isDark, CompanyColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 50, 12, 16),
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
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: c.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          Icon(_fileIcon, color: c.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.name,
                  style: GoogleFonts.plusJakartaSans(
                    color: c.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_kind == _ViewerKind.pdf && _pdfTotalPages > 0)
                  Text(
                    'Page $_pdfCurrentPage of $_pdfTotalPages',
                    style: GoogleFonts.plusJakartaSans(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open in browser',
            icon: Icon(Icons.open_in_new, color: c.textPrimary, size: 20),
            onPressed: _openExternally,
          ),
        ],
      ),
    );
  }

  Widget _errorState(CompanyColors c, {required String message, VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: c.danger, size: 42),
            const SizedBox(height: 12),
            Text(
              'Couldn\'t preview this file',
              style: GoogleFonts.plusJakartaSans(
                  color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRetry != null) ...[
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textPrimary,
                      side: BorderSide(color: c.borderSubtle.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text('Retry', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                ],
                ElevatedButton.icon(
                  onPressed: _openExternally,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.background,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text('Open in Browser',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Mobile/desktop PDF path — download bytes ourselves, render with
  /// Syncfusion. See [buildPdfWebFrame] for the web path, which is used
  /// instead on Flutter Web (no browser to embed there, but no
  /// Syncfusion-compatibility gaps to work around either).
  Widget _buildNativePdfBody(CompanyColors c) {
    return FutureBuilder<Uint8List>(
      future: _pdfBytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: c.accent));
        }
        if (snapshot.hasError) {
          return _errorState(
            c,
            message: 'This PDF couldn\'t be downloaded (${snapshot.error}).',
            onRetry: _retryPdf,
          );
        }
        if (_pdfRenderError != null) {
          return _errorState(
            c,
            message: _pdfRenderError!,
            onRetry: _retryPdf,
          );
        }
        final bytes = snapshot.data!;
        return SfPdfViewer.memory(
          bytes,
          controller: _pdfController,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          onDocumentLoadFailed: (details) {
            // Bytes downloaded and looked like a PDF, but Syncfusion still
            // couldn't parse/render it (corrupted export, unsupported
            // encryption/features, etc). Swap to the full error card
            // instead of leaving a blank viewer behind a passing SnackBar.
            if (mounted) {
              setState(() => _pdfRenderError =
              details.description.isNotEmpty
                  ? details.description
                  : 'This PDF could not be opened for preview.');
            }
          },
          onDocumentLoaded: (details) {
            if (mounted) {
              setState(() {
                _pdfTotalPages = details.document.pages.count;
                _pdfCurrentPage = 1;
              });
            }
          },
          onPageChanged: (details) {
            if (mounted) setState(() => _pdfCurrentPage = details.newPageNumber);
          },
        );
      },
    );
  }

  Widget _body(BuildContext context, CompanyColors c) {
    switch (_kind) {
      case _ViewerKind.pdf:
        if (isRunningOnWeb) {
          return buildPdfWebFrame(widget.url, 'pdf-frame-${widget.url.hashCode}');
        }
        return _buildNativePdfBody(c);
      case _ViewerKind.image:
        return Container(
          color: c.background,
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 6,
            child: Center(
              child: Image.network(
                widget.url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(child: CircularProgressIndicator(color: c.accent));
                },
                errorBuilder: (context, error, stack) =>
                    _errorState(c, message: 'This image couldn\'t be loaded for preview.'),
              ),
            ),
          ),
        );
      case _ViewerKind.unsupported:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file_outlined, color: c.accent, size: 46),
                const SizedBox(height: 14),
                Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  'This file type can\'t be previewed in-app yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _openExternally,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.background,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text('Open in Browser',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final c = CompanyColors.of(isDark);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _header(context, isDark, c),
            Expanded(child: _body(context, c)),
          ],
        ),
      ),
    );
  }
}
