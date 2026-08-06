import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String rollNo; // NEW
  final String name;
  final String email;
  final String phone;
  final String state; // NEW
  final String place; // NEW
  final String batchId;
  final String batchName;
  final String companyId;
  final String companyName;
  final String status; // "Active", "Completed", "Dropped"
  final DateTime? enrollmentDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  StudentModel({
    required this.id,
    required this.rollNo, // NEW
    required this.name,
    required this.email,
    required this.phone,
    required this.state, // NEW
    required this.place, // NEW
    required this.batchId,
    required this.batchName,
    required this.companyId,
    required this.companyName,
    required this.status,
    this.enrollmentDate,
    required this.createdAt,
    this.updatedAt,
  });

  factory StudentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return StudentModel(
      id: documentId,
      rollNo: map['rollNo'] ?? '', // NEW
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      state: map['state'] ?? '', // NEW
      place: map['place'] ?? '', // NEW
      batchId: map['batchId'] ?? '',
      batchName: map['batchName'] ?? '',
      companyId: map['companyId'] ?? '',
      companyName: map['companyName'] ?? '',
      status: map['status'] ?? 'Active',
      enrollmentDate: map['enrollmentDate'] != null
          ? (map['enrollmentDate'] as Timestamp).toDate()
          : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory StudentModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'rollNo': rollNo, // NEW
      'name': name,
      'email': email,
      'phone': phone,
      'state': state, // NEW
      'place': place, // NEW
      'batchId': batchId,
      'batchName': batchName,
      'companyId': companyId,
      'companyName': companyName,
      'status': status,
      'enrollmentDate': enrollmentDate != null ? Timestamp.fromDate(enrollmentDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  StudentModel copyWith({
    String? rollNo, // NEW
    String? name,
    String? email,
    String? phone,
    String? state, // NEW
    String? place, // NEW
    String? batchId,
    String? batchName,
    String? companyId,
    String? companyName,
    String? status,
    DateTime? enrollmentDate,
    DateTime? updatedAt,
  }) {
    return StudentModel(
      id: id,
      rollNo: rollNo ?? this.rollNo, // NEW
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      state: state ?? this.state, // NEW
      place: place ?? this.place, // NEW
      batchId: batchId ?? this.batchId,
      batchName: batchName ?? this.batchName,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      status: status ?? this.status,
      enrollmentDate: enrollmentDate ?? this.enrollmentDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Compares two roll numbers for ascending sort order.
  /// Numeric roll numbers (e.g. "1", "02", "13") are compared as numbers so
  /// "2" sorts before "10". Non-numeric roll numbers (e.g. "A12") fall back
  /// to a case-insensitive alphabetical comparison. Blank roll numbers are
  /// always pushed to the end of the list.
  static int compareRollNo(StudentModel a, StudentModel b) {
    final aRoll = a.rollNo.trim();
    final bRoll = b.rollNo.trim();
    if (aRoll.isEmpty && bRoll.isEmpty) return 0;
    if (aRoll.isEmpty) return 1;
    if (bRoll.isEmpty) return -1;

    final aNum = num.tryParse(aRoll);
    final bNum = num.tryParse(bRoll);
    if (aNum != null && bNum != null) return aNum.compareTo(bNum);

    return aRoll.toLowerCase().compareTo(bRoll.toLowerCase());
  }
}