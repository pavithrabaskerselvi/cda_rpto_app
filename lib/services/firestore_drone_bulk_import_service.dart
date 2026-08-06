import 'package:cloud_firestore/cloud_firestore.dart';

/// Thrown for genuine Firestore failures (permission, network, etc).
class DroneImportException implements Exception {
  final String message;
  final Object? cause;

  DroneImportException(this.message, {this.cause});

  @override
  String toString() => 'DroneImportException: $message';
}

/// Result of a single drone-folder-name lookup.
class DroneMatch {
  final String droneId;
  final String droneName;

  const DroneMatch({required this.droneId, required this.droneName});
}

enum DroneImportSaveStatus { created, duplicateSkipped }

class DroneImportSaveResult {
  final DroneImportSaveStatus status;
  const DroneImportSaveResult({required this.status});
}

/// FirestoreDroneBulkImportService
/// ----------------------------------
/// Firestore-only side of the drone bulk import pipeline. Mirrors
/// FirestoreBulkImportService (the student one) but writes into the
/// SAME embedded 'documents' array field on drones/{id} that
/// DroneDetailsScreen's AttachDocumentButton already reads/writes — so
/// anything imported in bulk shows up instantly on the normal
/// Attachments screen, filed under the matching DroneDocCategories key.
///
/// ASSUMPTIONS:
///   - "drones" collection has "droneName" and "serialNumber" fields
///     (see DroneModel).
///   - Duplicate = same categoryKey + fileName already present in that
///     drone's 'documents' array.
class FirestoreDroneBulkImportService {
  final FirebaseFirestore _firestore;

  FirestoreDroneBulkImportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _dronesRef => _firestore.collection('drones');

  /// Finds a drone whose stored droneName OR serialNumber matches
  /// [rawName] once both are normalized (case-insensitive, leading
  /// numbering stripped, whitespace collapsed). Returns null if no
  /// drone matches.
  ///
  /// Loads the full drones collection once per call — callers doing
  /// many lookups in one import run should cache/reuse results.
  Future<DroneMatch?> findDroneByName(String rawName) async {
    final QuerySnapshot snapshot;
    try {
      snapshot = await _dronesRef.get();
    } catch (e) {
      throw DroneImportException(
        'Failed to load drones collection.',
        cause: e,
      );
    }

    final target = _normalize(rawName);
    if (target.isEmpty) return null;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final droneName = data['droneName'] as String? ?? '';
      final serial = data['serialNumber'] as String? ?? '';
      if (_normalize(droneName) == target || _normalize(serial) == target) {
        return DroneMatch(droneId: doc.id, droneName: droneName);
      }
    }

    return null;
  }

  /// Saves one uploaded document URL under [categoryKey] on
  /// drones/[droneId]'s embedded 'documents' array.
  ///
  /// If a document with the same categoryKey + fileName already
  /// exists, nothing is written and
  /// [DroneImportSaveStatus.duplicateSkipped] is returned. Otherwise
  /// the new entry is appended and [DroneImportSaveStatus.created] is
  /// returned.
  Future<DroneImportSaveResult> saveUploadedDocument({
    required String droneId,
    required String categoryKey,
    required String fileName,
    required String secureUrl,
  }) async {
    final docRef = _dronesRef.doc(droneId);

    List<dynamic> existing;
    try {
      final snap = await docRef.get();
      existing = (snap.data() as Map<String, dynamic>?)?['documents']
      as List<dynamic>? ??
          [];
    } catch (e) {
      throw DroneImportException(
        'Failed to load existing documents for drone "$droneId".',
        cause: e,
      );
    }

    final alreadyThere = existing.any((m) {
      final map = Map<String, dynamic>.from(m as Map);
      return map['key'] == categoryKey && map['name'] == fileName;
    });

    if (alreadyThere) {
      return const DroneImportSaveResult(
        status: DroneImportSaveStatus.duplicateSkipped,
      );
    }

    try {
      await docRef.set({
        'documents': FieldValue.arrayUnion([
          {
            'key': categoryKey,
            'name': fileName,
            'url': secureUrl,
            'uploadedAt': DateTime.now().toIso8601String(),
          }
        ]),
      }, SetOptions(merge: true));
      return const DroneImportSaveResult(
        status: DroneImportSaveStatus.created,
      );
    } catch (e) {
      throw DroneImportException(
        'Failed to save document record for "$fileName".',
        cause: e,
      );
    }
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^\d+\s*[.)-]?\s*'), '') // strip "1. "/"2) "
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}