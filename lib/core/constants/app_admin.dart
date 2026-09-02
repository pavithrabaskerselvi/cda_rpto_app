// lib/core/constants/app_admin.dart
//
// SINGLE SOURCE OF TRUTH for "who is allowed to be Admin" in the RPTO app.
//
// This is an EXTRA safety net on top of the users/{uid}.role == 'admin'
// check — even if a Firestore doc is ever hand-edited to say role:
// 'admin', AccessControlService will still refuse full admin powers
// unless the email matches too.
//
// TODO: replace with your real admin email before shipping.
// This MUST stay in sync with isAdminEmail() in firestore.rules — if you
// change it here, change it there too.
const String kAdminEmail = 'info@chennaidroneacademy.com';

/// Case/whitespace-insensitive comparison against [kAdminEmail].
bool isAdminEmail(String? email) {
  if (email == null) return false;
  return email.trim().toLowerCase() == kAdminEmail.trim().toLowerCase();
}
