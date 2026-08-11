import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

/// One resize/quality pass to try. Passes are attempted in order,
/// each one more aggressive than the last, until the file fits under
/// budget or we run out of passes.
class _CompressionPass {
  final int maxDimension;
  final int jpegQuality;
  const _CompressionPass(this.maxDimension, this.jpegQuality);
}

/// OfficeFileCompressorService
/// ----------------------------
/// PPTX/DOCX/XLSX files are just ZIP archives — the images inside a
/// slide deck live as plain PNG/JPEG files under ppt/media/ (word/media/,
/// xl/media/ for Word/Excel). Course decks built from full-resolution
/// screenshots or camera photos routinely blow past Cloudinary's raw
/// file-size cap (10 MB on the free plan) even though nothing on the
/// slide actually needs that resolution.
///
/// This does client-side what PowerPoint's own "Compress Media" does:
/// decode each embedded raster image, downscale it, re-encode it at a
/// lower quality, and rezip — all before the file ever leaves the
/// device for Cloudinary.
///
/// Deliberately conservative:
///   - Only touches .pptx/.docx/.xlsx (real OOXML zips).
///   - Only recompresses plain PNG/JPEG entries under a /media/ path —
///     vector art, embedded fonts, and everything else in the zip is
///     copied through byte-for-byte untouched.
///   - Keeps each image's original format (JPEG stays JPEG, PNG stays
///     PNG) so the zip's declared content types still match — swapping
///     formats would corrupt the file for PowerPoint/Office to reopen.
///   - Falls back to the original bytes at every step it can't safely
///     improve on, so a compression bug never blocks an upload that
///     would otherwise have gone through fine.
class OfficeFileCompressorService {
  static const _compressibleExtensions = {'pptx', 'docx', 'xlsx'};

  /// Escalating passes: try the mildest shrink first, only go further
  /// if the file is still over budget afterwards.
  static const _passes = [
    _CompressionPass(1600, 72),
    _CompressionPass(1200, 60),
    _CompressionPass(1000, 45),
  ];

  bool canCompress(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return _compressibleExtensions.contains(ext);
  }

  /// Compresses [bytes] only if it's a supported Office file already
  /// over [targetBytes], trying progressively more aggressive passes
  /// until it fits (or passes run out). Always returns *some* usable
  /// bytes — worst case, the untouched original.
  Future<Uint8List> compressToBudget(
      Uint8List bytes,
      String fileName, {
        int targetBytes = 9 * 1024 * 1024, // stay under Cloudinary's 10 MB cap
      }) async {
    if (!canCompress(fileName) || bytes.length <= targetBytes) return bytes;

    var current = bytes;
    for (final pass in _passes) {
      final compressed = await _compressOnce(
        current,
        maxDimension: pass.maxDimension,
        jpegQuality: pass.jpegQuality,
      );
      if (compressed != null) current = compressed;
      if (current.length <= targetBytes) break;
    }
    return current;
  }

  /// Single compression pass over every embedded image. Returns null
  /// if the archive couldn't be read or nothing got smaller — callers
  /// should keep using the previous bytes in that case.
  Future<Uint8List?> _compressOnce(
      Uint8List bytes, {
        required int maxDimension,
        required int jpegQuality,
      }) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      // Not a readable zip (corrupt file, oddly-saved export) — leave
      // it alone rather than fail the whole import over this step.
      return null;
    }

    final newArchive = Archive();
    var shrankSomething = false;

    for (final file in archive) {
      if (!file.isFile) continue;

      if (!_isMediaImage(file.name)) {
        newArchive.addFile(ArchiveFile(file.name, file.size, file.content));
        continue;
      }

      final original = file.content as List<int>;
      final recompressed = _recompressImage(
        original,
        file.name,
        maxDimension: maxDimension,
        jpegQuality: jpegQuality,
      );

      if (recompressed != null && recompressed.length < original.length) {
        shrankSomething = true;
        newArchive.addFile(ArchiveFile(file.name, recompressed.length, recompressed));
      } else {
        newArchive.addFile(ArchiveFile(file.name, file.size, original));
      }
    }

    if (!shrankSomething) return null;

    final rezipped = ZipEncoder().encode(newArchive);
    if (rezipped == null || rezipped.isEmpty) return null;

    final result = Uint8List.fromList(rezipped);
    // Rezipping has its own overhead — only hand back the new copy if
    // it actually ended up smaller than what we started this pass with.
    return result.length < bytes.length ? result : null;
  }

  bool _isMediaImage(String entryName) {
    if (!entryName.contains('/media/')) return false;
    final ext = entryName.split('.').last.toLowerCase();
    // Deliberately excludes gif/emf/wmf/svg/tiff — animated or vector
    // formats this decode/resize/re-encode pipeline would corrupt.
    return ext == 'png' || ext == 'jpg' || ext == 'jpeg';
  }

  Uint8List? _recompressImage(
      List<int> bytes,
      String entryName, {
        required int maxDimension,
        required int jpegQuality,
      }) {
    try {
      final decoded = img.decodeImage(Uint8List.fromList(bytes));
      if (decoded == null) return null;

      var working = decoded;
      if (decoded.width > maxDimension || decoded.height > maxDimension) {
        working = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxDimension : null,
          height: decoded.height > decoded.width ? maxDimension : null,
        );
      }

      final ext = entryName.split('.').last.toLowerCase();
      if (ext == 'jpg' || ext == 'jpeg') {
        return Uint8List.fromList(img.encodeJpg(working, quality: jpegQuality));
      }

      // PNG: keep the lossless format so the zip's declared content
      // type still matches, but the resize above still shrinks
      // oversized screenshots substantially. Skip re-encoding if
      // nothing actually changed dimension-wise.
      if (identical(working, decoded)) return null;
      return Uint8List.fromList(img.encodePng(working, level: 9));
    } catch (_) {
      return null;
    }
  }
}
