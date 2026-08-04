import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/attach_document_button.dart';

class CompanyModel {
  final String id;
  final String name;
  final String registrationNumber;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String contactEmail;
  final String contactPhone;
  final String status; // "Active" or "Inactive"
  final String? parentCompanyId; // NEW: null/empty = main company, else = branch
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<AttachedDocument> documents;

  CompanyModel({
    required this.id,
    required this.name,
    required this.registrationNumber,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.contactEmail,
    required this.contactPhone,
    required this.status,
    this.parentCompanyId, // NEW
    required this.createdAt,
    this.updatedAt,
    this.documents = const [],
  });

  bool get isBranch => parentCompanyId != null && parentCompanyId!.isNotEmpty;
  bool get isMainCompany => !isBranch;

  factory CompanyModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CompanyModel(
      id: documentId,
      name: map['name'] ?? '',
      registrationNumber: map['registrationNumber'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
      contactEmail: map['contactEmail'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      status: map['status'] ?? 'Active',
      parentCompanyId: map['parentCompanyId'], // NEW
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      documents: (map['documents'] as List<dynamic>? ?? [])
          .map((d) => AttachedDocument.fromMap(d as Map<String, dynamic>))
          .toList(),
    );
  }

  factory CompanyModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompanyModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'registrationNumber': registrationNumber,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'status': status,
      'parentCompanyId': parentCompanyId, // NEW
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'documents': documents.map((d) => d.toMap()).toList(),
    };
  }

  CompanyModel copyWith({
    String? name,
    String? registrationNumber,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? contactEmail,
    String? contactPhone,
    String? status,
    String? parentCompanyId, // NEW
    DateTime? updatedAt,
    List<AttachedDocument>? documents,
  }) {
    return CompanyModel(
      id: id,
      name: name ?? this.name,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      status: status ?? this.status,
      parentCompanyId: parentCompanyId ?? this.parentCompanyId, // NEW
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      documents: documents ?? this.documents,
    );
  }
}