import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

/// Reports overall progress (0.0–1.0, combined across all passes) and a
/// human-readable label for the current step.
typedef CompressionProgressCallback = void Function(double progress, String label);

class _CompressionPass {
  final int maxDimension;
  final int jpegQuality;
  const _CompressionPass(this.maxDimension, this.jpegQuality);
}

/// OfficeFileCompressorService
/// ----------------------------
/// PPTX/DOCX/XLSX files are just ZIP archives — the images inside a
/// slide deck live as plain PNG/JPEG files under ppt/media/ (word/media/,
/// xl/media/ for Word/Excel). This decodes each embedded raster image,
/// downscales it, re-encodes it at a lower quality, and rezips — before
/// the file ever leaves the device for Cloudinary.
///
/// Deliberately conservative:
///   - Only touches .pptx/.docx/.xlsx.
///   - Only recompresses plain PNG/JPEG entries under a /media/ path.
///   - Keeps each image's original format.
///   - Falls back to the original bytes at every step it can't safely
///     improve on.
///   - Yields to the event loop every few images so this doesn't
///     freeze the UI thread on decks with lots of embedded images.
class OfficeFileCompressorService {
  static const _compressibleExtensions = {'pptx', 'docx', 'xlsx'};
  static const _yieldEveryNImages = 3;

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
  /// over [targetBytes]. [onProgress] fires repeatedly with overall
  /// progress across all passes and a label like
  /// "Compressing (pass 2/3) — 14/40 images".
  Future<Uint8List> compressToBudget(
      Uint8List bytes,
      String fileName, {
        int targetBytes = 9 * 1024 * 1024,
        CompressionProgressCallback? onProgress,
      }) async {
    if (!canCompress(fileName) || bytes.length <= targetBytes) return bytes;

    // Let the caller's setState (status -> compressing) actually paint
    // before the heavy synchronous work below starts.
    onProgress?.call(0.0, 'Preparing…');
    await Future.delayed(Duration.zero);

    var current = bytes;
    for (var i = 0; i < _passes.length; i++) {
      final pass = _passes[i];
      final compressed = await _compressOnce(
        current,
        maxDimension: pass.maxDimension,
        jpegQuality: pass.jpegQuality,
        onImageProgress: (done, total) {
          final passFraction = total == 0 ? 0.0 : done / total;
          final overall = (i + passFraction) / _passes.length;
          onProgress?.call(
            overall.clamp(0.0, 1.0),
            'Compressing (pass ${i + 1}/${_passes.length}) — $done/$total images',
          );
        },
      );
      if (compressed != null) current = compressed;
      if (current.length <= targetBytes) break;
    }
    return current;
  }

  Future<Uint8List?> _compressOnce(
      Uint8List bytes, {
        required int maxDimension,
        required int jpegQuality,
        void Function(int done, int total)? onImageProgress,
      }) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return null;
    }

    final imageEntries =
        archive.files.where((f) => f.isFile && _isMediaImage(f.name)).length;

    final newArchive = Archive();
    var shrankSomething = false;
    var imagesProcessed = 0;

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

      imagesProcessed++;
      onImageProgress?.call(imagesProcessed, imageEntries);

      if (imagesProcessed % _yieldEveryNImages == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    if (!shrankSomething) return null;

    final rezipped = ZipEncoder().encode(newArchive);
    if (rezipped == null || rezipped.isEmpty) return null;

    final result = Uint8List.fromList(rezipped);
    return result.length < bytes.length ? result : null;
  }

  bool _isMediaImage(String entryName) {
    if (!entryName.contains('/media/')) return false;
    final ext = entryName.split('.').last.toLowerCase();
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

      if (identical(working, decoded)) return null;
      return Uint8List.fromList(img.encodePng(working, level: 9));
    } catch (_) {
      return null;
    }
  }
}