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