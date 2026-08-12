// lib/services/pdf_compressor_service.dart
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// One render/quality pass to try. Passes are attempted in order, each
/// one more aggressive (lower DPI, lower JPEG quality) than the last,
/// until the file fits under budget or we run out of passes.
class _PdfCompressionPass {
  final double dpi;
  final int jpegQuality;
  const _PdfCompressionPass(this.dpi, this.jpegQuality);
}

/// PdfCompressorService
/// ----------------------------
/// Scanned textbooks / manuals routinely land above Cloudinary's raw
/// file cap (10 MB on the free plan) because every page is a
/// full-resolution photo. Unlike PPTX/DOCX/XLSX (plain zips of PNG/JPEG
/// that can be recompressed in place — see OfficeFileCompressorService),
/// a PDF's embedded images live inside content streams that Syncfusion's
/// Flutter PDF library doesn't expose for in-place recompression (that
/// API only exists on the .NET version of the library).
///
/// So instead this renders each page to a raster image at a reduced
/// DPI, re-encodes it as a lower-quality JPEG, and rebuilds a brand new
/// single-image-per-page PDF from those — the same thing a desktop PDF
/// compressor does for scanned documents. Rendering uses the `printing`
/// package, which works cross-platform including Flutter Web (via
/// pdf.js).
///
/// Deliberately conservative:
///   - Only touches .pdf files.
///   - Falls back to the previous best attempt (or the original bytes)
///     at every step it can't safely improve on, so a compression bug
///     never blocks an upload that would otherwise have gone through.
///   - Bails out of a pass early (rather than hanging the browser tab)
///     if the document has an unreasonable number of pages to rasterize
///     client-side.
class PdfCompressorService {
  static const _maxPagesToRasterize = 400;

  /// Escalating passes: try the mildest shrink first, only go further
  /// if the file is still over budget afterwards.
  static const _passes = [
    _PdfCompressionPass(150, 70),
    _PdfCompressionPass(120, 55),
    _PdfCompressionPass(96, 40),
  ];

  bool canCompress(String fileName) =>
      fileName.toLowerCase().endsWith('.pdf');

  /// Compresses [bytes] only if it's a PDF already over [targetBytes],
  /// trying progressively more aggressive passes until it fits (or
  /// passes run out). Always returns *some* usable bytes — worst case,
  /// the untouched original.
  Future<Uint8List> compressToBudget(
      Uint8List bytes,
      String fileName, {
        int targetBytes = 9 * 1024 * 1024, // stay under Cloudinary's 10 MB cap
      }) async {
    if (!canCompress(fileName) || bytes.length <= targetBytes) return bytes;

    var best = bytes;
    for (final pass in _passes) {
      final rebuilt = await _rebuildAtDpi(
        bytes,
        dpi: pass.dpi,
        jpegQuality: pass.jpegQuality,
      );
      if (rebuilt != null && rebuilt.length < best.length) {
        best = rebuilt;
      }
      if (best.length <= targetBytes) break;
    }
    return best;
  }

  /// Renders every page of [bytes] at [dpi], re-encodes each as JPEG at
  /// [jpegQuality], and rebuilds a new PDF from those images. Returns
  /// null if rendering fails or the document is too large to safely
  /// rasterize client-side — callers should keep using the previous
  /// bytes in that case.
  Future<Uint8List?> _rebuildAtDpi(
      Uint8List bytes, {
        required double dpi,
        required int jpegQuality,
      }) async {
    try {
      final document = pw.Document(compress: true);
      var pageCount = 0;

      await for (final page in Printing.raster(bytes, dpi: dpi)) {
        pageCount++;
        if (pageCount > _maxPagesToRasterize) {
          // Too many pages to safely render client-side — abandon this
          // pass rather than risk hanging the tab.
          return null;
        }

        final png = await page.toPng();
        final decoded = img.decodeImage(png);
        if (decoded == null) return null;

        final jpg = img.encodeJpg(decoded, quality: jpegQuality);

        // Points = pixels * 72 / dpi, so the rebuilt page keeps the
        // original page's real-world size instead of shrinking it.
        final widthPt = decoded.width * 72.0 / dpi;
        final heightPt = decoded.height * 72.0 / dpi;

        document.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(widthPt, heightPt, marginAll: 0),
            build: (context) => pw.Image(
              pw.MemoryImage(jpg),
              fit: pw.BoxFit.fill,
            ),
          ),
        );
      }

      if (pageCount == 0) return null; // nothing rendered — leave alone

      final saved = await document.save();
      final result = Uint8List.fromList(saved);
      // Rebuilding has its own overhead — only hand back the new copy
      // if it actually ended up smaller than the original.
      return result.length < bytes.length ? result : null;
    } catch (_) {
      // Corrupt/encrypted/unsupported PDF — leave it alone rather than
      // fail the whole import over this step.
      return null;
    }
  }
}