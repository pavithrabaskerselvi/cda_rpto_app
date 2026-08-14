import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Reports overall progress. [progress] is null while the total page
/// count isn't known yet (page count only becomes known as pages
/// stream in) — treat null as "indeterminate" in the UI.
typedef PdfProgressCallback = void Function(double? progress, String label);

class _PdfCompressionPass {
  final double dpi;
  final int jpegQuality;
  const _PdfCompressionPass(this.dpi, this.jpegQuality);
}

/// PdfCompressorService
/// ----------------------------
/// Renders each page to a raster image at a reduced DPI, re-encodes it
/// as a lower-quality JPEG, and rebuilds a new single-image-per-page
/// PDF — the same thing a desktop PDF compressor does for scans.
/// Rendering uses `printing`, which works on Flutter Web via pdf.js.
///
/// Deliberately conservative: only touches .pdf files, falls back to
/// the previous best attempt at every step, and bails out of a pass
/// early rather than hanging the tab on documents with too many pages.
class PdfCompressorService {
  static const _maxPagesToRasterize = 400;

  static const _passes = [
    _PdfCompressionPass(150, 70),
    _PdfCompressionPass(120, 55),
    _PdfCompressionPass(96, 40),
  ];

  bool canCompress(String fileName) => fileName.toLowerCase().endsWith('.pdf');

  /// Compresses [bytes] only if it's a PDF already over [targetBytes].
  /// [onProgress] fires as each page renders — page totals aren't
  /// known up front, so progress is reported as "page N" rather than
  /// a percentage until the pass actually completes.
  Future<Uint8List> compressToBudget(
      Uint8List bytes,
      String fileName, {
        int targetBytes = 9 * 1024 * 1024,
        PdfProgressCallback? onProgress,
      }) async {
    if (!canCompress(fileName) || bytes.length <= targetBytes) return bytes;

    onProgress?.call(null, 'Preparing…');

    var best = bytes;
    for (var i = 0; i < _passes.length; i++) {
      final pass = _passes[i];
      final rebuilt = await _rebuildAtDpi(
        bytes,
        dpi: pass.dpi,
        jpegQuality: pass.jpegQuality,
        onPageRendered: (pageNum) {
          onProgress?.call(
            null,
            'Compressing (pass ${i + 1}/${_passes.length}) — page $pageNum',
          );
        },
      );
      if (rebuilt != null && rebuilt.length < best.length) {
        best = rebuilt;
      }
      if (best.length <= targetBytes) break;
    }
    return best;
  }

  Future<Uint8List?> _rebuildAtDpi(
      Uint8List bytes, {
        required double dpi,
        required int jpegQuality,
        void Function(int pageNum)? onPageRendered,
      }) async {
    try {
      final document = pw.Document(compress: true);
      var pageCount = 0;

      await for (final page in Printing.raster(bytes, dpi: dpi)) {
        pageCount++;
        onPageRendered?.call(pageCount);

        if (pageCount > _maxPagesToRasterize) return null;

        final png = await page.toPng();
        final decoded = img.decodeImage(png);
        if (decoded == null) return null;

        final jpg = img.encodeJpg(decoded, quality: jpegQuality);

        final widthPt = decoded.width * 72.0 / dpi;
        final heightPt = decoded.height * 72.0 / dpi;

        document.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(widthPt, heightPt, marginAll: 0),
            build: (context) => pw.Image(pw.MemoryImage(jpg), fit: pw.BoxFit.fill),
          ),
        );
      }

      if (pageCount == 0) return null;

      final saved = await document.save();
      final result = Uint8List.fromList(saved);
      return result.length < bytes.length ? result : null;
    } catch (_) {
      return null;
    }
  }
}