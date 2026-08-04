import 'package:cloud_firestore/cloud_firestore.dart';

class SimulatorModel {
  final String id;
  final String simulatorName;
  final String model;
  final String serialNumber;
  final String companyId;
  final String companyName;
  final String status; // "Available", "In Use", "Under Maintenance"
  final DateTime createdAt;
  final DateTime? updatedAt;

  SimulatorModel({
    required this.id,
    required this.simulatorName,
    required this.model,
    required this.serialNumber,
    required this.companyId,
    required this.companyName,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory SimulatorModel.fromMap(Map<String, dynamic> map, String documentId) {
    return SimulatorModel(
      id: documentId,
      simulatorName: map['simulatorName'] ?? '',
      model: map['model'] ?? '',
      serialNumber: map['serialNumber'] ?? '',
      companyId: map['companyId'] ?? '',
      companyName: map['companyName'] ?? '',
      status: map['status'] ?? 'Available',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory SimulatorModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SimulatorModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'simulatorName': simulatorName,
      'model': model,
      'serialNumber': serialNumber,
      'companyId': companyId,
      'companyName': companyName,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  SimulatorModel copyWith({
    String? simulatorName,
    String? model,
    String? serialNumber,
    String? companyId,
    String? companyName,
    String? status,
    DateTime? updatedAt,
  }) {
    return SimulatorModel(
      id: id,
      simulatorName: simulatorName ?? this.simulatorName,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}