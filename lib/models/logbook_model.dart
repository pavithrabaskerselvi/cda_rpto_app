import 'package:cloud_firestore/cloud_firestore.dart';

/// LogbookModel
/// Firestore collection: "logbook_entries"
class LogbookModel {
  final String id;
  final String studentId;
  final String studentName;
  final String batchId;
  final String droneId;
  final String droneName;
  final String instructorId;
  final DateTime flightDate;
  final int durationMinutes;
  final String flightType; // 'training' | 'solo' | 'check_ride'
  final String sortieType;
  final String remarks;
  final bool signedOff;
  final String? signedOffBy;
  final DateTime? signedOffAt;
  final DateTime createdAt;

  LogbookModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.batchId,
    required this.droneId,
    required this.droneName,
    required this.instructorId,
    required this.flightDate,
    required this.durationMinutes,
    required this.flightType,
    required this.sortieType,
    required this.remarks,
    required this.signedOff,
    this.signedOffBy,
    this.signedOffAt,
    required this.createdAt,
  });

  factory LogbookModel.fromMap(Map<String, dynamic> map, String documentId) {
    return LogbookModel(
      id: documentId,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      batchId: map['batchId'] ?? '',
      droneId: map['droneId'] ?? '',
      droneName: map['droneName'] ?? '',
      instructorId: map['instructorId'] ?? '',
      flightDate: map['flightDate'] != null
          ? (map['flightDate'] as Timestamp).toDate()
          : DateTime.now(),
      durationMinutes: (map['durationMinutes'] ?? 0) as int,
      flightType: map['flightType'] ?? 'training',
      sortieType: map['sortieType'] ?? '',
      remarks: map['remarks'] ?? '',
      signedOff: map['signedOff'] ?? false,
      signedOffBy: map['signedOffBy'],
      signedOffAt: map['signedOffAt'] != null
          ? (map['signedOffAt'] as Timestamp).toDate()
          : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory LogbookModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LogbookModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'batchId': batchId,
      'droneId': droneId,
      'droneName': droneName,
      'instructorId': instructorId,
      'flightDate': Timestamp.fromDate(flightDate),
      'durationMinutes': durationMinutes,
      'flightType': flightType,
      'sortieType': sortieType,
      'remarks': remarks,
      'signedOff': signedOff,
      'signedOffBy': signedOffBy,
      'signedOffAt': signedOffAt != null ? Timestamp.fromDate(signedOffAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}