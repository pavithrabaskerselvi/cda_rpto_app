// lib/services/access_control_service.dart
//
// Central place for the RPTO app's "Admin full control" feature:
//   - what happens the moment ANY user logs in (creates/refreshes their
//     access record + fires an admin notification for non-admins)
//   - admin approving/denying/changing access
//   - streams the admin screens use to show live data
//   - a lightweight activity log
//
// Adapted from the CDA Inventory app's access_control_service.dart for
// RPTO's three roles ('admin' / 'instructor' / 'student'). No gamification
// dependency — this file is self-contained.
//
// Firestore layout added by this feature:
//
//   users/{uid}
//       ...existing fields (name, email, role, branch, createdAt)...
//       accessLevel   : 'none' | 'viewer' | 'editor'
//       accessStatus  : 'pending' | 'approved' | 'rejected'
//       approvedBy    : admin uid (nullable)
//       approvedAt    : Timestamp (nullable)
//       lastLogin     : Timestamp
//       isOnline      : bool
//
//   admin_notifications/{id}
//       type            : 'access_request' | 'info'
//       userId, userName, userEmail
//       message
//       requestedAccess : 'viewer' | 'editor'
//       status          : 'pending' | 'approved' | 'rejected'
//       read            : bool
//       createdAt       : Timestamp
//
//   activity_logs/{id}
//       userId, userName, action, detail
//       createdAt : Timestamp

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_admin.dart';
import '../models/user_role_model.dart';

/// Thrown by [AccessControlService.onUserLoggedIn] when the signed-in
/// Firebase Auth account belongs to a user the admin has removed/rejected
/// and access has now been fully withdrawn. The Auth account itself still
/// exists (can't be disabled client-side), so callers must catch this,
/// sign the user back out immediately, and show a clear message instead
/// of letting them anywhere near the app.
class AccountRemovedException implements Exception {
  const AccountRemovedException();
  @override
  String toString() =>
      'This account has been removed by the admin. Contact the RPTO office.';
}

class AccessControlService {
  AccessControlService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Lightweight in-memory cache of the signed-in user's access record,
  // refreshed on every login (see onUserLoggedIn below). Lets
  // logCurrentUserAction() log an action without an extra Firestore
  // read on every single call.
  static AppUserAccess? _currentUserCache;

  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  static CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('admin_notifications');

  static CollectionReference<Map<String, dynamic>> get _activity =>
      _db.collection('activity_logs');

  // ---------------------------------------------------------------------
  // Register hook — call this right after AuthService.register() succeeds,
  // BEFORE navigating away from the register screen. Creates the access
  // fields and fires the admin notification immediately at registration
  // time, instead of waiting for the user's first login.
  // ---------------------------------------------------------------------

  /// Sets initial access fields on a freshly-registered user and — for
  /// non-admins — immediately notifies the admin, so the request shows
  /// up in AdminNotificationsScreen right after registration completes
  /// (the user doesn't need to log in first for the admin to see it).
  static Future<void> createAccessRequestOnRegister({
    required String uid,
    required String name,
    required String email,
    required String role,
  }) async {
    final roleLower = role.trim().toLowerCase();
    // Email is the sole admin signal (see app_admin.dart) — a user
    // typing/selecting role 'admin' does NOT make them one. This used
    // to be `roleLower == 'admin' || isAdminEmail(email)`, which let
    // anyone grant themselves full editor+approved access just by
    // choosing "Admin" at registration.
    final isAdminRole = isAdminEmail(email);

    await _users.doc(uid).set({
      'accessLevel': accessLevelToString(
          isAdminRole ? AccessLevel.editor : AccessLevel.none),
      'accessStatus': accessStatusToString(
          isAdminRole ? AccessStatus.approved : AccessStatus.pending),
    }, SetOptions(merge: true));

    if (isAdminRole) return;

    // Guard against a duplicate notification in the rare case the
    // login-hook path (onUserLoggedIn, fired by the auto sign-in that
    // happens right after account creation) runs at nearly the same
    // moment as this call.
    final existing = await _notifications
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: accessStatusToString(AccessStatus.pending))
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    await _notifications.add({
      'type': 'access_request',
      'userId': uid,
      'userName': name,
      'userEmail': email,
      'message': '$name (${roleLower.isEmpty ? 'user' : roleLower}) requested access.',
      'requestedAccess': accessLevelToString(AccessLevel.viewer),
      'status': accessStatusToString(AccessStatus.pending),
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------
  // Login hook — call this right after a successful FirebaseAuth login,
  // BEFORE navigating into the app. See login_screen.dart integration.
  // ---------------------------------------------------------------------

  /// Ensures the user's access-control fields exist, refreshes
  /// lastLogin/isOnline, fires an admin notification the first time a
  /// non-admin logs in, and logs the login to the activity feed.
  ///
  /// Throws [AccountRemovedException] if this user's access was rejected
  /// after previously being approved (i.e. admin revoked them).
  static Future<AppUserAccess> onUserLoggedIn(User firebaseUser) async {
    final ref = _users.doc(firebaseUser.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      // Shouldn't normally happen (register_screen creates the doc), but
      // guard anyway so this never throws a null-check error.
      throw const AccountRemovedException();
    }

    final data = snap.data()!;
    final role = (data['role'] as String? ?? '').trim().toLowerCase();
    // Email is the sole admin signal (see app_admin.dart) — this used
    // to be `role == 'admin' || isAdminEmail(...)`, which meant ANY
    // account with role:'admin' in its Firestore doc (e.g. self-set
    // at sign-up) was granted full admin powers here regardless of
    // its email. Only the exact kAdminEmail account gets treated as
    // admin now, no matter what `role` says.
    final isAdminRole = isAdminEmail(firebaseUser.email);

    final hasAccessFields = data.containsKey('accessStatus');
    final currentStatus =
    accessStatusFromString(data['accessStatus'] as String?);

    // A previously-approved user whose status is now 'rejected' has been
    // actively removed by the admin — kick them out.
    if (!isAdminRole && hasAccessFields && currentStatus == AccessStatus.rejected) {
      throw const AccountRemovedException();
    }

    final updates = <String, dynamic>{
      'lastLogin': FieldValue.serverTimestamp(),
      'isOnline': true,
    };

    if (isAdminRole) {
      // Admins always have full access — keep their record consistent
      // even if these fields were never set.
      updates['accessLevel'] = accessLevelToString(AccessLevel.editor);
      updates['accessStatus'] = accessStatusToString(AccessStatus.approved);
    } else if (!hasAccessFields) {
      // First login for this user — create a pending request and notify
      // the admin.
      updates['accessLevel'] = accessLevelToString(AccessLevel.none);
      updates['accessStatus'] = accessStatusToString(AccessStatus.pending);

      await _notifications.add({
        'type': 'access_request',
        'userId': firebaseUser.uid,
        'userName': data['name'] ?? '',
        'userEmail': data['email'] ?? firebaseUser.email ?? '',
        'message':
        '${data['name'] ?? firebaseUser.email} (${role.isEmpty ? 'user' : role}) requested access.',
        'requestedAccess': accessLevelToString(AccessLevel.viewer),
        'status': accessStatusToString(AccessStatus.pending),
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await ref.set(updates, SetOptions(merge: true));

    await _logActivity(
      userId: firebaseUser.uid,
      userName: data['name'] as String? ?? firebaseUser.email ?? '',
      userRole: role,
      action: 'login',
      detail: 'Logged in as $role',
    );

    final freshSnap = await ref.get();
    final access = AppUserAccess.fromDoc(freshSnap);
    _currentUserCache = access; // used by logCurrentUserAction() below
    return access;
  }

  /// Call when the user signs out so the "online" dot goes grey.
  static Future<void> onUserLoggedOut(String uid) async {
    await _users.doc(uid).set(
      {'isOnline': false},
      SetOptions(merge: true),
    );
  }

  // ---------------------------------------------------------------------
  // Admin actions
  // ---------------------------------------------------------------------

  /// Sets an instructor/student's access level and marks them approved.
  static Future<void> setAccessLevel({
    required String targetUid,
    required AccessLevel level,
    required String adminUid,
  }) async {
    await _users.doc(targetUid).set({
      'accessLevel': accessLevelToString(level),
      'accessStatus': accessStatusToString(AccessStatus.approved),
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _logActivity(
      userId: adminUid,
      userName: 'Admin',
      userRole: 'admin',
      action: 'access_updated',
      detail:
      'Set access level to ${accessLevelToString(level)} for $targetUid',
    );
  }

  /// Rejects/revokes a user's access. Their next login attempt will be
  /// blocked with [AccountRemovedException].
  static Future<void> rejectAccess({
    required String targetUid,
    required String adminUid,
  }) async {
    await _users.doc(targetUid).set({
      'accessLevel': accessLevelToString(AccessLevel.none),
      'accessStatus': accessStatusToString(AccessStatus.rejected),
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _logActivity(
      userId: adminUid,
      userName: 'Admin',
      userRole: 'admin',
      action: 'access_rejected',
      detail: 'Rejected access for $targetUid',
    );
  }

  /// Approves or rejects a specific pending notification and applies the
  /// same decision to the user's record in one call — this is what the
  /// admin-notifications screen's Approve/Reject buttons call.
  static Future<void> resolveNotification({
    required AdminNotificationModel notification,
    required bool approve,
    required AccessLevel grantedLevel,
    required String adminUid,
  }) async {
    if (approve) {
      await setAccessLevel(
        targetUid: notification.userId,
        level: grantedLevel,
        adminUid: adminUid,
      );
    } else {
      await rejectAccess(targetUid: notification.userId, adminUid: adminUid);
    }

    await _notifications.doc(notification.id).set({
      'status':
      accessStatusToString(approve ? AccessStatus.approved : AccessStatus.rejected),
      'read': true,
    }, SetOptions(merge: true));
  }

  /// Deletes a user's Firestore profile (does NOT delete their Firebase
  /// Auth account — that requires an Admin SDK / Cloud Function call).
  static Future<void> deleteUserProfile(String targetUid) async {
    await _users.doc(targetUid).delete();
  }

  // ---------------------------------------------------------------------
  // Streams — used by the admin screens
  // ---------------------------------------------------------------------

  /// Instructor accounts, for the User Access screen.
  ///
  /// Scoped to 'instructor' only per current requirement — student
  /// accounts still register with role 'student' and get an
  /// access-control record + pending status like everyone else, but
  /// they're excluded from this admin-management list. Change to
  /// `whereIn: ['instructor', 'student']` if student management needs
  /// to be added here later.
  static Stream<List<AppUserAccess>> watchManagedUsers() {
    return _users
        .where('role', isEqualTo: 'instructor')
        .snapshots()
        .map((qs) => qs.docs.map(AppUserAccess.fromDoc).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
  }

  /// Notifications filtered by status ('pending' | 'approved' | 'rejected').
  static Stream<List<AdminNotificationModel>> watchNotifications({
    required AccessStatus status,
  }) {
    return _notifications
        .where('status', isEqualTo: accessStatusToString(status))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map(AdminNotificationModel.fromDoc).toList());
  }

  /// Count of unread pending notifications, for a badge on the admin nav
  /// entry.
  static Stream<int> watchUnreadCount() {
    return _notifications
        .where('status', isEqualTo: accessStatusToString(AccessStatus.pending))
        .where('read', isEqualTo: false)
        .snapshots()
        .map((qs) => qs.docs.length);
  }

  /// Recent activity log entries, newest first.
  static Stream<List<ActivityLogModel>> watchActivity({int limit = 100}) {
    return _activity
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((qs) => qs.docs.map(ActivityLogModel.fromDoc).toList());
  }

  /// Same as [watchActivity] but filtered to one role ('admin' |
  /// 'instructor' | 'student') — used by the role tabs on
  /// ActivityFeedScreen.
  static Stream<List<ActivityLogModel>> watchActivityByRole({
    required String role,
    int limit = 100,
  }) {
    return _activity
        .where('userRole', isEqualTo: role.toLowerCase())
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((qs) => qs.docs.map(ActivityLogModel.fromDoc).toList());
  }

  /// Public logging hook — call this from ANY screen (batch add, student
  /// add, drone add, vault upload, etc.) to make that action show up
  /// live on the admin's Activity Feed. See INTEGRATION notes for
  /// example call sites.
  ///
  /// Example:
  /// ```dart
  /// await AccessControlService.logAction(
  ///   userId: uid,
  ///   userName: name,
  ///   userRole: role,       // 'admin' | 'instructor' | 'student'
  ///   action: 'batch_created',
  ///   detail: 'Created batch "BATCH 5"',
  /// );
  /// ```
  static Future<void> logAction({
    required String userId,
    required String userName,
    required String userRole,
    required String action,
    required String detail,
  }) {
    return _logActivity(
      userId: userId,
      userName: userName,
      userRole: userRole,
      action: action,
      detail: detail,
    );
  }

  /// Convenience version of [logAction] for the CURRENTLY signed-in
  /// user — no need to look up uid/name/role yourself. This is what the
  /// module services (batch_service, student_service, drone_service,
  /// etc.) call after every add/update/delete, so every module's
  /// activity shows up on the admin's Live Activity feed automatically,
  /// no matter which screen triggered it.
  ///
  /// Silently does nothing if nobody is signed in (shouldn't normally
  /// happen, since these calls only run from already-authenticated
  /// screens).
  static Future<void> logCurrentUserAction({
    required String action,
    required String detail,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String name = '';
    String role = '';
    if (_currentUserCache?.uid == user.uid) {
      name = _currentUserCache!.name;
      role = _currentUserCache!.role;
    }
    if (name.isEmpty || role.isEmpty) {
      // Cache miss (e.g. app was hot-restarted without a fresh login) —
      // fall back to a one-off Firestore read.
      final snap = await _users.doc(user.uid).get();
      final data = snap.data();
      name = (data?['name'] as String?)?.trim().isNotEmpty == true
          ? data!['name'] as String
          : (user.email ?? 'Unknown');
      role = (data?['role'] as String? ?? '').trim().toLowerCase();
    }

    await _logActivity(
      userId: user.uid,
      userName: name,
      userRole: role,
      action: action,
      detail: detail,
    );
  }

  static Future<void> _logActivity({
    required String userId,
    required String userName,
    String userRole = '',
    required String action,
    required String detail,
  }) async {
    await _activity.add({
      'userId': userId,
      'userName': userName,
      'userRole': userRole.toLowerCase(),
      'action': action,
      'detail': detail,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}