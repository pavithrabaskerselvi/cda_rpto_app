import 'package:cloud_firestore/cloud_firestore.dart';

class BatchModel {
  final String id;
  final String batchName;
  final String courseType; // e.g. "RPAS Basic", "RPAS Advanced"
  final String instructorId;
  final String instructorName;
  final String companyId;
  final String companyName;
  final DateTime startDate;
  final DateTime endDate;
  final int totalStudents;
  final String status; // "Upcoming", "Ongoing", "Completed"
  final DateTime createdAt;
  final DateTime? updatedAt;

  BatchModel({
    required this.id,
    required this.batchName,
    required this.courseType,
    required this.instructorId,
    required this.instructorName,
    required this.companyId,
    required this.companyName,
    required this.startDate,
    required this.endDate,
    required this.totalStudents,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory BatchModel.fromMap(Map<String, dynamic> map, String documentId) {
    return BatchModel(
      id: documentId,
      batchName: map['batchName'] ?? '',
      courseType: map['courseType'] ?? '',
      instructorId: map['instructorId'] ?? '',
      instructorName: map['instructorName'] ?? '',
      companyId: map['companyId'] ?? '',
      companyName: map['companyName'] ?? '',
      startDate: map['startDate'] != null
          ? (map['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? (map['endDate'] as Timestamp).toDate()
          : DateTime.now(),
      totalStudents: map['totalStudents'] ?? 0,
      status: map['status'] ?? 'Upcoming',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory BatchModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BatchModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'batchName': batchName,
      'courseType': courseType,
      'instructorId': instructorId,
      'instructorName': instructorName,
      'companyId': companyId,
      'companyName': companyName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalStudents': totalStudents,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  BatchModel copyWith({
    String? batchName,
    String? courseType,
    String? instructorId,
    String? instructorName,
    String? companyId,
    String? companyName,
    DateTime? startDate,
    DateTime? endDate,
    int? totalStudents,
    String? status,
    DateTime? updatedAt,
  }) {
    return BatchModel(
      id: id,
      batchName: batchName ?? this.batchName,
      courseType: courseType ?? this.courseType,
      instructorId: instructorId ?? this.instructorId,
      instructorName: instructorName ?? this.instructorName,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalStudents: totalStudents ?? this.totalStudents,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}