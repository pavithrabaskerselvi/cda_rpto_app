import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/cloudinary_service.dart';

/// Batch Photos — a photo gallery for the batch, mirroring the
/// "7.Batch Photos" folder in Drive. Photos are uploaded to Cloudinary
/// (same unsigned-upload path used for student documents) and referenced
/// from a `batches/{batchId}/photos` subcollection.
class BatchPhotosScreen extends StatefulWidget {
  final String batchId;
  final String batchName;

  const BatchPhotosScreen({
    super.key,
    required this.batchId,
    required this.batchName,
  });

  @override
  State<BatchPhotosScreen> createState() => _BatchPhotosScreenState();
}

class _BatchPhotosScreenState extends State<BatchPhotosScreen> {
  bool _uploading = false;
  int _uploadTotal = 0;
  int _uploadDone = 0;

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  Color _kNavy(BuildContext c) =>
      _isDark(c) ? const Color(0xFF050A14) : const Color(0xFFF7F8FA);
  Color _kSurface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF0F1B2E) : const Color(0xFFFFFFFF);
  Color _kTeal(BuildContext c) =>
      _isDark(c) ? const Color(0xFF14B8A6) : const Color(0xFF0D9488);
  Color _kTextPrimary(BuildContext c) =>
      _isDark(c) ? Colors.white : const Color(0xFF0B1220);
  Color _kTextMuted(BuildContext c) =>
      _isDark(c) ? Colors.white54 : const Color(0xFF7B8494);

  CollectionReference get _photosRef => FirebaseFirestore.instance
      .collection('batches')
      .doc(widget.batchId)
      .collection('photos');

  Future<void> _uploadPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final files = result.files.where((f) => f.bytes != null).toList();
    if (files.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadTotal = files.length;
      _uploadDone = 0;
    });

    for (final file in files) {
      try {
        final Uint8List bytes = file.bytes!;
        final url = await CloudinaryService.uploadDocument(
          bytes,
          file.name,
          folder: 'rpto_batch_photos/${widget.batchId}',
        );
        if (url != null) {
          await _photosRef.add({
            'url': url,
            'fileName': file.name,
            'uploadedAt': Timestamp.now(),
          });
        }
      } catch (_) {
        // Skip failed file, continue with the rest.
      }
      setState(() => _uploadDone++);
    }

    if (mounted) {
      setState(() => _uploading = false);
    }
  }

  Future<void> _deletePhoto(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _kSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete Photo', style: TextStyle(color: _kTextPrimary(context))),
        content: Text('Remove this photo from the batch gallery?', style: TextStyle(color: _kTextMuted(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Cancel', style: TextStyle(color: _kTextMuted(context)))),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await _photosRef.doc(docId).delete();
    }
  }

  void _openFullscreen(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNavy(context),
      appBar: AppBar(
        backgroundColor: _kNavy(context),
        elevation: 0,
        iconTheme: IconThemeData(color: _kTextPrimary(context)),
        title: Text('${widget.batchName} - Photos', style: TextStyle(color: _kTextPrimary(context), fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(Icons.add_photo_alternate_outlined, color: _kTeal(context)),
            tooltip: 'Add Photos',
            onPressed: _uploading ? null : _uploadPhotos,
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _photosRef.orderBy('uploadedAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator(color: _kTeal(context)));
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Text('No photos yet.\nTap the icon above to add some.', textAlign: TextAlign.center, style: TextStyle(color: _kTextMuted(context))),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final url = data['url'] as String? ?? '';
                  return GestureDetector(
                    onTap: () => _openFullscreen(url),
                    onLongPress: () => _deletePhoto(doc.id),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                        progress == null ? child : Container(color: _kSurface(context)),
                        errorBuilder: (context, error, stack) => Container(
                          color: _kSurface(context),
                          child: Icon(Icons.broken_image_outlined, color: _kTextMuted(context)),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (_uploading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  width: 240,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: _kSurface(context), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _kTeal(context)),
                      const SizedBox(height: 14),
                      Text('Uploading $_uploadDone of $_uploadTotal', style: TextStyle(color: _kTextPrimary(context), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
