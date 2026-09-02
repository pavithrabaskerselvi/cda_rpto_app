// lib/models/user_role_model.dart
//
// Shared models for the RPTO Admin Control system:
//  - AppUserAccess          : the access-control fields stored on users/{uid}
//  - AdminNotificationModel : entries in the admin_notifications collection
//  - ActivityLogModel       : entries in the activity_logs collection
//
// Mirrors the CDA Inventory app's app_access_models.dart, adapted to RPTO's
// three roles ('admin' / 'instructor' / 'student') and its existing
// users/{uid}.branch field (raw values 'Branch 1' / 'Branch 2').
//
// Plain data classes, no code-gen, so this drops straight into the app.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_admin.dart';

/// Access level an instructor/student can be granted by the admin.
/// Admin accounts always have full access regardless of this value
/// (see [AppUserAccess.canEdit] / [AppUserAccess.canView]).
enum AccessLevel { none, viewer, editor }

AccessLevel accessLevelFromString(String? value) {
  switch (value) {
    case 'editor':
      return AccessLevel.editor;
    case 'viewer':
      return AccessLevel.viewer;
    default:
      return AccessLevel.none;
  }
}

String accessLevelToString(AccessLevel level) {
  switch (level) {
    case AccessLevel.editor:
      return 'editor';
    case AccessLevel.viewer:
      return 'viewer';
    case AccessLevel.none:
      return 'none';
  }
}

/// Status of a user's access request.
enum AccessStatus { pending, approved, rejected }

AccessStatus accessStatusFromString(String? value) {
  switch (value) {
    case 'approved':
      return AccessStatus.approved;
    case 'denied': // tolerate either spelling if hand-edited in Firestore
    case 'rejected':
      return AccessStatus.rejected;
    default:
      return AccessStatus.pending;
  }
}

String accessStatusToString(AccessStatus status) {
  switch (status) {
    case AccessStatus.approved:
      return 'approved';
    case AccessStatus.rejected:
      return 'rejected';
    case AccessStatus.pending:
      return 'pending';
  }
}

/// Full access-control snapshot for a single user, mirrors the fields
/// added to the `users/{uid}` Firestore document.
class AppUserAccess {
  final String uid;
  final String name;
  final String email;
  final String role; // 'admin' | 'instructor' | 'student' — always lowercase
  final String branch; // raw 'Branch 1' / 'Branch 2' or '' for admin
  final AccessLevel accessLevel;
  final AccessStatus accessStatus;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final bool isOnline;

  AppUserAccess({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.branch = '',
    required this.accessLevel,
    required this.accessStatus,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.lastLogin,
    this.isOnline = false,
  });

  // Admin status is decided by email alone (kAdminEmail /
  // isAdminEmail() — the single source of truth, see app_admin.dart),
  // never by the mutable `role` string on this document. Previously
  // this was `role == 'admin'`, which meant anyone who got an
  // 'admin' value into their own Firestore doc — e.g. by picking
  // "Admin" on the sign-up screen — was treated as a real admin
  // throughout the app. Keeping `role` as a display/branch-logic
  // field only, and gating actual admin power strictly on the email,
  // closes that hole regardless of what `role` ends up containing.
  bool get isAdmin => isAdminEmail(email);
  bool get isInstructor => role == 'instructor';
  bool get isStudent => role == 'student';

  /// Admins can always edit. Instructors/students need editor-level
  /// access AND an approved request.
  bool get canEdit =>
      isAdmin ||
          (accessStatus == AccessStatus.approved &&
              accessLevel == AccessLevel.editor);

  /// Admins can always view. Instructors/students need viewer-or-above
  /// access AND an approved request.
  bool get canView =>
      isAdmin ||
          (accessStatus == AccessStatus.approved &&
              accessLevel != AccessLevel.none);

  bool get isPending => !isAdmin && accessStatus == AccessStatus.pending;
  bool get isRejected => !isAdmin && accessStatus == AccessStatus.rejected;

  factory AppUserAccess.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppUserAccess(
      uid: doc.id,
      name: (data['name'] as String?)?.trim() ?? '',
      email: (data['email'] as String?)?.trim() ?? '',
      role: (data['role'] as String?)?.trim().toLowerCase() ?? '',
      branch: (data['branch'] as String?)?.trim() ?? '',
      accessLevel: accessLevelFromString(data['accessLevel'] as String?),
      accessStatus: accessStatusFromString(data['accessStatus'] as String?),
      approvedBy: data['approvedBy'] as String?,
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
      isOnline: data['isOnline'] as bool? ?? false,
    );
  }
}

/// Entries in the `admin_notifications` collection — fired whenever an
/// instructor/student logs in for the first time (access request) or
/// another admin-worthy event happens.
class AdminNotificationModel {
  final String id;
  final String type; // 'access_request' | 'info'
  final String userId;
  final String userName;
  final String userEmail;
  final String message;
  final AccessLevel requestedAccess;
  final AccessStatus status;
  final bool read;
  final DateTime? createdAt;

  AdminNotificationModel({
    required this.id,
    required this.type,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.message,
    required this.requestedAccess,
    required this.status,
    required this.read,
    this.createdAt,
  });

  factory AdminNotificationModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? <String, dynamic>{};
    return AdminNotificationModel(
      id: doc.id,
      type: data['type'] as String? ?? 'info',
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      message: data['message'] as String? ?? '',
      requestedAccess:
      accessLevelFromString(data['requestedAccess'] as String?),
      status: accessStatusFromString(data['status'] as String?),
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Entries in the `activity_logs` collection — a lightweight audit trail
/// the admin can review (who logged in, who was approved/denied, etc).
class ActivityLogModel {
  final String id;
  final String userId;
  final String userName;
  final String userRole; // 'admin' | 'instructor' | 'student' | '' (unknown)
  final String action; // e.g. 'login', 'access_approved', 'batch_created'
  final String detail;
  final DateTime? createdAt;

  ActivityLogModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userRole = '',
    required this.action,
    required this.detail,
    this.createdAt,
  });

  factory ActivityLogModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? <String, dynamic>{};
    return ActivityLogModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      userRole: (data['userRole'] as String? ?? '').toLowerCase(),
      action: data['action'] as String? ?? '',
      detail: data['detail'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}