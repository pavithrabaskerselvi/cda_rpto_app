import 'package:url_launcher/url_launcher.dart';

/// DocumentLauncher
/// -----------------
/// Opens Cloudinary-hosted documents (PDFs, images) from their secureUrl,
/// e.g. when a user taps a document_list_tile / document_upload_tile.
///
/// Returns false instead of throwing if the URL can't be launched
/// (no matching app, invalid URL, etc), so callers can show a snackbar
/// like "Couldn't open document" without a try/catch at every call site.
class DocumentLauncher {
  /// Opens the given Cloudinary secureUrl in the device's default handler
  /// (browser for PDFs/images, unless a native viewer is registered).
  static Future<bool> open(String secureUrl) async {
    final uri = Uri.tryParse(secureUrl);
    if (uri == null) return false;

    if (!await canLaunchUrl(uri)) return false;

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens a document record's URL directly from the Map returned by
  /// DocumentService.getDocument() / streamDocuments().
  static Future<bool> openDocument(Map<String, dynamic> document) {
    final url = document['secureUrl'] as String?;
    if (url == null || url.isEmpty) {
      return Future.value(false);
    }
    return open(url);
  }
}