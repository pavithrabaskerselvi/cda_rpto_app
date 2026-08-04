import 'package:file_picker/file_picker.dart';

class StudentDocument {
  /// Batch folder name, if the picked structure has one
  /// ("Batch/Student/File.pdf"). Null for a flat "Student/File.pdf"
  /// structure like your "6.Student wise folder" — nothing downstream
  /// requires it anymore.
  final String? batchName;
  final String studentName;
  final String studentFolder;
  final String documentName;
  final String documentType;
  final PlatformFile localFile;
  final int size;
  final String extension;

  const StudentDocument({
    this.batchName,
    required this.studentName,
    required this.studentFolder,
    required this.documentName,
    required this.documentType,
    required this.localFile,
    required this.size,
    required this.extension,
  });
}