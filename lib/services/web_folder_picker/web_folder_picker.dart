/// Conditional export: picks the real dart:html implementation when
/// compiling for web, and a stub (that throws) everywhere else, so this
/// package still compiles for Desktop/Mobile builds even though folder
/// picking there goes through `FilePicker.platform.getDirectoryPath()`
/// instead (see bulk_import_screen.dart).
export 'web_folder_picker_stub.dart'
if (dart.library.html) 'web_folder_picker_web.dart';