import 'package:cloud_firestore/cloud_firestore.dart';

class DroneModel {
  final String id;
  final String droneName;
  final String model;
  final String serialNumber;
  final String type; // "Fixed Wing", "Multirotor", "VTOL"
  final String companyId;
  final String companyName;
  final String status; // "Available", "In Use", "Under Maintenance"
  final DateTime? lastMaintenanceDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DroneModel({
    required this.id,
    required this.droneName,
    required this.model,
    required this.serialNumber,
    required this.type,
    required this.companyId,
    required this.companyName,
    required this.status,
    this.lastMaintenanceDate,
    required this.createdAt,
    this.updatedAt,
  });

  factory DroneModel.fromMap(Map<String, dynamic> map, String documentId) {
    return DroneModel(
      id: documentId,
      droneName: map['droneName'] ?? '',
      model: map['model'] ?? '',
      serialNumber: map['serialNumber'] ?? '',
      type: map['type'] ?? '',
      companyId: map['companyId'] ?? '',
      companyName: map['companyName'] ?? '',
      status: map['status'] ?? 'Available',
      lastMaintenanceDate: map['lastMaintenanceDate'] != null
          ? (map['lastMaintenanceDate'] as Timestamp).toDate()
          : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory DroneModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DroneModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'droneName': droneName,
      'model': model,
      'serialNumber': serialNumber,
      'type': type,
      'companyId': companyId,
      'companyName': companyName,
      'status': status,
      'lastMaintenanceDate': lastMaintenanceDate != null
          ? Timestamp.fromDate(lastMaintenanceDate!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  DroneModel copyWith({
    String? droneName,
    String? model,
    String? serialNumber,
    String? type,
    String? companyId,
    String? companyName,
    String? status,
    DateTime? lastMaintenanceDate,
    DateTime? updatedAt,
  }) {
    return DroneModel(
      id: id,
      droneName: droneName ?? this.droneName,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      type: type ?? this.type,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      status: status ?? this.status,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}