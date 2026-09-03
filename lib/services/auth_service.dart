import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // True from the moment login_screen calls signInWithEmailAndPassword
  // until it finishes validating the signed-in account (role/email
  // checks) and either lets the user through or signs them back out.
  //
  // WHY THIS EXISTS: signInWithEmailAndPassword fires
  // FirebaseAuth.authStateChanges() the instant it succeeds. main.dart's
  // AuthGate listens to that same stream at the app root and reacts
  // immediately — it doesn't know login_screen still has post-sign-in
  // checks (isAdminEmail, role-vs-dropdown match) in flight. Without
  // this flag, AuthGate races ahead and shows Dashboard/PendingApproval
  // using the account's REAL stored role/access, regardless of what the
  // user picked on the login screen or whether the checks below are
  // about to sign them out — and by the time they fail, LoginScreen is
  // already unmounted so the error snackbar silently never shows. This
  // was the "logs in with any email as Admin, no error shown" bug.
  //
  // AuthGate must stay on a spinner (not react to authStateChanges)
  // for as long as this is true.
  static final ValueNotifier<bool> isVerifyingLogin = ValueNotifier<bool>(false);

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Register new user (admin/employee) and store profile in Firestore
  static Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String role, // "admin" or "employee" - store lowercase always
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await _firestore.collection('users').doc(cred.user!.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'role': role.toLowerCase(), // IMPORTANT: always lowercase to avoid role-matching bugs
        'createdAt': DateTime.now().toIso8601String(),
      });

      return null; // no error
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Registration failed';
    } catch (e) {
      return e.toString();
    }
  }

  /// Login existing user
  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Login failed';
    } catch (e) {
      return e.toString();
    }
  }

  /// Fetch current user's role from Firestore ("admin" / "employee")
  static Future<String?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return (doc.data()?['role'] as String?)?.toLowerCase();
  }

  /// Fetch full current user profile
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return doc.data();
  }

  static Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Could not send reset email';
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }
}