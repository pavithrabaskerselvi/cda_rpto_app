import 'package:flutter/material.dart';

/// Non-web stub. Native `<iframe>` embedding only exists in a browser, so
/// on mobile/desktop builds this is never actually called — see
/// [document_viewer_screen.dart]'s `isRunningOnWeb` check — but it still
/// needs to exist so the app compiles for every platform. See
/// pdf_web_frame_web.dart for the real implementation (only ever
/// compiled in for Flutter Web builds).
Widget buildPdfWebFrame(String url, String viewType) => const SizedBox.shrink();

const bool isRunningOnWeb = false;
