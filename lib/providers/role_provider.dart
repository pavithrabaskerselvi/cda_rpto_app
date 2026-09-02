// lib/providers/role_provider.dart
//
// App-wide access to "who is the current user and what can they do".
// Register this in main.dart's MultiProvider (see integration notes),
// and call load()/loadFromFirebaseUser() right after AccessControlService
// .onUserLoggedIn() succeeds.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_role_model.dart';
import '../services/access_control_service.dart';

class RoleProvider extends ChangeNotifier {
  AppUserAccess? _access;
  bool _isLoading = false;

  AppUserAccess? get access => _access;
  bool get isLoading => _isLoading;

  bool get isSignedIn => _access != null;
  bool get isAdmin => _access?.isAdmin ?? false;
  bool get isInstructor => _access?.isInstructor ?? false;
  bool get isStudent => _access?.isStudent ?? false;
  bool get canEdit => _access?.canEdit ?? false;
  bool get canView => _access?.canView ?? false;
  bool get isPendingApproval => _access?.isPending ?? false;

  /// Runs the login hook (creates/refreshes the access record, fires an
  /// admin notification on first login) and stores the result. Call this
  /// once, right after a successful FirebaseAuth sign-in.
  ///
  /// Rethrows [AccountRemovedException] so the caller (login_screen) can
  /// sign the user back out and show a message — this provider does not
  /// swallow that error.
  Future<void> loadFromFirebaseUser(User firebaseUser) async {
    _isLoading = true;
    notifyListeners();
    try {
      _access = await AccessControlService.onUserLoggedIn(firebaseUser);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears local state on sign-out. Does not touch Firestore beyond
  /// flipping isOnline — call AccessControlService.onUserLoggedOut
  /// separately before this if you want that.
  void clear() {
    _access = null;
    notifyListeners();
  }
}
