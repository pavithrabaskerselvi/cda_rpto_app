import 'package:file_picker/file_picker.dart';

/// Non-web fallback. Desktop/Mobile use
/// `FilePicker.platform.getDirectoryPath()` directly instead — this
/// only exists so the app compiles outside web builds.
Future<List<PlatformFile>> pickWebFolderFiles() async {
  throw UnsupportedError(
    'pickWebFolderFiles() is web-only. Use '
        'FilePicker.platform.getDirectoryPath() on Desktop/Mobile instead.',
  );
}