import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/attach_document_button.dart';

class InstructorModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String licenseNumber;
  final String specialization; // e.g. "Fixed Wing", "Multirotor", "VTOL"
  final int experienceYears;
  final int experienceMonths; // 0-11, extra months beyond experienceYears
  final String companyId;
  final String companyName;
  final String status; // "Active" or "Inactive"
  final String? profileImageUrl;
  final List<AttachedDocument> documents;
  final DateTime createdAt;
  final DateTime? updatedAt;

  InstructorModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.licenseNumber,
    required this.specialization,
    required this.experienceYears,
    this.experienceMonths = 0,
    required this.companyId,
    required this.companyName,
    required this.status,
    this.profileImageUrl,
    this.documents = const [],
    required this.createdAt,
    this.updatedAt,
  });

  factory InstructorModel.fromMap(Map<String, dynamic> map, String documentId) {
    return InstructorModel(
      id: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      licenseNumber: map['licenseNumber'] ?? '',
      specialization: map['specialization'] ?? '',
      experienceYears: map['experienceYears'] ?? 0,
      experienceMonths: map['experienceMonths'] ?? 0,
      companyId: map['companyId'] ?? '',
      companyName: map['companyName'] ?? '',
      status: map['status'] ?? 'Active',
      profileImageUrl: map['profileImageUrl'],
      documents: (map['documents'] as List<dynamic>? ?? [])
          .map((d) => AttachedDocument.fromMap(d as Map<String, dynamic>))
          .toList(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory InstructorModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InstructorModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'licenseNumber': licenseNumber,
      'specialization': specialization,
      'experienceYears': experienceYears,
      'experienceMonths': experienceMonths,
      'companyId': companyId,
      'companyName': companyName,
      'status': status,
      'profileImageUrl': profileImageUrl,
      'documents': documents.map((d) => d.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  InstructorModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? licenseNumber,
    String? specialization,
    int? experienceYears,
    int? experienceMonths,
    String? companyId,
    String? companyName,
    String? status,
    String? profileImageUrl,
    List<AttachedDocument>? documents,
    DateTime? updatedAt,
  }) {
    return InstructorModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      specialization: specialization ?? this.specialization,
      experienceYears: experienceYears ?? this.experienceYears,
      experienceMonths: experienceMonths ?? this.experienceMonths,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      status: status ?? this.status,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      documents: documents ?? this.documents,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}