/// Centralized form validators for use with TextFormField / CustomTextField
/// validator callbacks across the app.
///
/// ASSUMPTIONS:
/// - Phone validation assumes 10-digit Indian mobile numbers
///   (adjust the regex if you support other countries/formats).
/// - Each method returns an error String, or null if valid.
class Validators {
  Validators._(); // static-only class

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length != 10) return 'Enter a valid 10-digit phone number';
    return null;
  }

  static String? password(String? value, {int minLength = 8}) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain an uppercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain a number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != originalPassword) return 'Passwords do not match';
    return null;
  }

  static String? minLength(String? value, int min, {String fieldName = 'This field'}) {
    if (value == null || value.trim().length < min) {
      return '$fieldName must be at least $min characters';
    }
    return null;
  }

  static String? numeric(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    if (double.tryParse(value.trim()) == null) {
      return '$fieldName must be a number';
    }
    return null;
  }

  /// Validates a drone registration / UIN number format if you follow
  /// DGCA's alphanumeric convention — adjust the regex to your exact format.
  static String? droneRegistrationNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Registration number is required';
    }
    final regex = RegExp(r'^[A-Z0-9\-]{5,20}$');
    if (!regex.hasMatch(value.trim().toUpperCase())) {
      return 'Enter a valid registration/UIN number';
    }
    return null;
  }
}