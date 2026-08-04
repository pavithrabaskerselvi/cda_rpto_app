// This file is only ever compiled in for Flutter Web builds — see
// web_folder_picker.dart's `export ... if (dart.library.html)`. The
// `avoid_web_libraries_in_flutter` lint doesn't know that, so it's
// suppressed here rather than in the whole project's analysis_options.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

/// Opens the browser's native folder picker
/// (`<input type="file" webkitdirectory>`) and returns every PDF inside
/// it as a [PlatformFile], with `identifier` set to the file's path
/// relative to the picked folder (e.g.
/// "Batch 1/01. JAGANATHAN/CC.pdf") so
/// `FolderScannerService.scanWebFiles` can rebuild the Batch/Student
/// structure.
///
/// Returns an empty list if the user cancels the picker (no `change`
/// event fires, so we just time out quietly rather than hanging
/// forever).
Future<List<PlatformFile>> pickWebFolderFiles() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = true;
  input.setAttribute('webkitdirectory', 'true');
  input.setAttribute('directory', 'true');

  final changed = Completer<void>();
  input.onchange = (web.Event _) {
    if (!changed.isCompleted) changed.complete();
  }.toJS;

  input.click();

  await changed.future.timeout(
    const Duration(minutes: 30),
    onTimeout: () {},
  );

  final fileList = input.files;
  if (fileList == null || fileList.length == 0) return [];

  final result = <PlatformFile>[];

  for (var i = 0; i < fileList.length; i++) {
    final file = fileList.item(i);
    if (file == null) continue;

    final relativePath = _relativePathOf(file);
    if (!relativePath.toLowerCase().endsWith('.pdf')) continue;

    final bytes = await _readAsBytes(file);

    result.add(
      PlatformFile(
        name: file.name,
        size: bytes.length,
        bytes: bytes,
        identifier: relativePath,
      ),
    );
  }

  return result;
}

/// `package:web`'s [web.File] doesn't declare `webkitRelativePath` (it's
/// a non-standard Chromium/Firefox property), so it's read via untyped
/// JS interop. Falls back to the bare file name (which makes
/// FolderScannerService skip the file as "wrong depth") if a browser
/// somehow doesn't expose it.
String _relativePathOf(web.File file) {
  final jsFile = file as JSObject;
  if (jsFile.has('webkitRelativePath')) {
    final value = jsFile.getProperty('webkitRelativePath'.toJS);
    if (value.isA<JSString>()) {
      final relativePath = (value as JSString).toDart;
      if (relativePath.isNotEmpty) return relativePath;
    }
  }
  return file.name;
}

Future<Uint8List> _readAsBytes(web.File file) async {
  final buffer = await file.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}