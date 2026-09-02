import 'package:flutter/material.dart';

// ---------------- Design Tokens (RPTO CDA App) — Light Theme ----------------
// NOTE: variable names kept as-is (kNavy, kSurface) to avoid renaming across
// the whole app; values now point to a light palette instead of dark.

const Color kNavy = Color(0xFFF7F8FA);      // page background (was dark navy)
const Color kTeal = Color(0xFF0F9E93);      // accent, slightly deepened for contrast on white
const Color kCoral = Color(0xFFE0454B);
const Color kAmber = Color(0xFFC97A08);
const Color kSurface = Color(0xFFFFFFFF);   // card/surface background (was dark navy-blue)
const Color kGreen = Color(0xFF15803D);
const Color kPurple = Color(0xFF6D28D9);

// Text colors for the light background
const Color kTextPrimary = Color(0xFF0F172A);
const Color kTextSecondary = Color(0xFF5B6472);
const Color kTextMuted = Color(0xFF8A93A3);
const Color kBorder = Color(0xFFE2E5EA);

// ---------------- Shared Text Styles ----------------

const TextStyle kTitleStyle = TextStyle(
  color: kTextPrimary,
  fontSize: 18,
  fontWeight: FontWeight.w600,
);

const TextStyle kSubtitleStyle = TextStyle(
  color: kTextSecondary,
  fontSize: 13,
);

const TextStyle kLabelStyle = TextStyle(
  color: kTextPrimary,
  fontSize: 13,
  fontWeight: FontWeight.w600,
);

// ---------------- Shared Input Decoration ----------------

InputDecoration kFieldDecoration(String hintOrLabel, {bool isLabel = false}) {
  return InputDecoration(
    hintText: isLabel ? null : hintOrLabel,
    labelText: isLabel ? hintOrLabel : null,
    hintStyle: const TextStyle(color: kTextMuted),
    labelStyle: const TextStyle(color: kTextSecondary),
    filled: true,
    fillColor: kSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kTeal),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kCoral),
    ),
  );
}

// ---------------- Batch Categories ----------------
// Single source of truth for the batch "course" categories. Used by the
// batch category picker screen, and every screen that has a Category
// dropdown (Add Batch, Bulk Batch Setup, Batch Detail) so they all stay
// in sync. Batches created before this list existed have no `category`
// field in Firestore — treat those as 'RPC' everywhere (RPC was the only
// course originally offered).
const String kDefaultBatchCategory = 'RPC';

const List<String> kBatchCategories = [
  'RPC',
  'Aerial Cinematography',
  'FPV Pilot',
  'FPV Build',
  'Agri Build',
];

class BatchCategoryInfo {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const BatchCategoryInfo({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<BatchCategoryInfo> kBatchCategoryInfo = [
  BatchCategoryInfo(
      key: 'RPC', label: 'RPC', icon: Icons.flight_takeoff, color: kTeal),
  BatchCategoryInfo(
      key: 'Aerial Cinematography',
      label: 'Aerial Cinematography',
      icon: Icons.videocam_outlined,
      color: kPurple),
  BatchCategoryInfo(
      key: 'FPV Pilot',
      label: 'FPV Pilot',
      icon: Icons.sports_esports_outlined,
      color: kAmber),
  BatchCategoryInfo(
      key: 'FPV Build',
      label: 'FPV Build',
      icon: Icons.build_outlined,
      color: kCoral),
  BatchCategoryInfo(
      key: 'Agri Build',
      label: 'Agri Build',
      icon: Icons.agriculture_outlined,
      color: kGreen),
];

/// Normalizes a raw `category` field from Firestore into one of the 5
/// known category keys.
///
/// Handles every messy real-world case so a batch can never silently
/// vanish from the category picker:
///  - missing / blank                       -> RPC
///  - matches a known category, wrong case
///    or with stray whitespace ('rpc ',
///    ' Fpv pilot')                          -> the canonical key
///  - anything else unrecognized (legacy /
///    stray data written before this
///    feature existed, typos, etc.)          -> RPC (the original,
///                                              only course pre-dating
///                                              this feature)
String normalizeBatchCategory(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return kDefaultBatchCategory;
  for (final known in kBatchCategories) {
    if (known.toLowerCase() == trimmed.toLowerCase()) return known;
  }
  return kDefaultBatchCategory;
}

// ---------------- Status Color Helper ----------------

Color kStatusColor(String status) {
  switch (status) {
    case 'Ongoing':
    case 'Active':
    case 'Present':
      return kGreen;
    case 'Upcoming':
      return kAmber;
    case 'Completed':
      return kTextMuted;
    case 'Absent':
    case 'Inactive':
    case 'Dropped':
      return kCoral;
    default:
      return kTeal;
  }
}