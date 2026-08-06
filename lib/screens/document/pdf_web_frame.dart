/// Conditional export: picks the real browser-`<iframe>` implementation
/// when compiling for web, and a no-op stub everywhere else — same
/// pattern as `services/web_folder_picker/web_folder_picker.dart`.
export 'pdf_web_frame_stub.dart' if (dart.library.html) 'pdf_web_frame_web.dart';
