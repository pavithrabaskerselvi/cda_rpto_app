// This file is only ever compiled in for Flutter Web builds — see
// pdf_web_frame.dart's `export ... if (dart.library.html)`.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final Set<String> _registeredViewTypes = {};

/// Renders [url] inside a plain `<iframe>`, letting the browser's own
/// built-in PDF engine do the work — the same engine that already opens
/// these documents fine when "Open in Browser" is used. Syncfusion's own
/// PDF parser rejects a handful of real-world PDFs (odd encoding,
/// non-standard cross-reference tables, etc) that every browser renders
/// without complaint, so on web we skip Syncfusion entirely and use this
/// instead.
Widget buildPdfWebFrame(String url, String viewType) {
  if (!_registeredViewTypes.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
    _registeredViewTypes.add(viewType);
  }
  return HtmlElementView(viewType: viewType);
}

const bool isRunningOnWeb = true;
