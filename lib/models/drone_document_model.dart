import 'package:file_picker/file_picker.dart';

/// One file discovered while bulk-scanning a drone's document folder.
///
/// [droneFolder] is the raw folder name identifying which drone this
/// file belongs to — only set in multi-drone imports (see
/// DroneFolderScannerService). [category] is the raw Drive folder name
/// ("2.INSURANCE", "Model T Manuals"...) and [categoryKey] is what
/// DroneDocCategories.classify() resolved it to (e.g. "insurance").
class DroneDocument {
  final String? droneFolder;
  final String category;
  final String categoryKey;
  final String documentName;
  final PlatformFile localFile;
  final int size;
  final String extension;

  const DroneDocument({
    this.droneFolder,
    required this.category,
    required this.categoryKey,
    required this.documentName,
    required this.localFile,
    required this.size,
    required this.extension,
  });
}