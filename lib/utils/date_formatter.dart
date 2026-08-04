import 'package:intl/intl.dart';

/// DateFormatter
/// -------------
/// Static date/time helpers used across the CDA RPTO app
/// (student enrollment dates, logbook flight dates, form timestamps, etc).
///
/// Works with both DateTime and the ISO-8601 strings your services
/// store (since AuthService etc. use DateTime.now().toIso8601String()
/// instead of Firestore Timestamps).
class DateFormatter {
  /// "12 Jul 2026"
  static String toDisplayDate(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  /// "12 Jul 2026, 4:30 PM"
  static String toDisplayDateTime(DateTime date) {
    return DateFormat('d MMM yyyy, h:mm a').format(date);
  }

  /// "4:30 PM"
  static String toDisplayTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  /// "2026-07-12" - useful for form fields / sorting keys
  static String toIsoDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Parses an ISO-8601 string (as stored by our services) back to DateTime.
  /// Returns null if the string is null or invalid instead of throwing -
  /// handy for optional Firestore fields.
  static DateTime? parseIso(String? isoString) {
    if (isoString == null || isoString.isEmpty) return null;
    try {
      return DateTime.parse(isoString);
    } catch (_) {
      return null;
    }
  }

  /// Relative-time string: "Just now", "5m ago", "3h ago", "2d ago",
  /// falling back to a display date for anything older than a week.
  static String toRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return toDisplayDate(date);
  }

  /// Same as [toRelative] but accepts the ISO string directly - avoids
  /// callers having to null-check/parse first. Returns '' if unparsable.
  static String toRelativeFromIso(String? isoString) {
    final date = parseIso(isoString);
    if (date == null) return '';
    return toRelative(date);
  }

  /// Age in whole years from a date of birth
  static int calculateAge(DateTime dateOfBirth) {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    final hasHadBirthdayThisYear = (now.month > dateOfBirth.month) ||
        (now.month == dateOfBirth.month && now.day >= dateOfBirth.day);
    if (!hasHadBirthdayThisYear) age--;
    return age;
  }

  /// Number of whole days between two dates (e.g. batch duration)
  static int daysBetween(DateTime start, DateTime end) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    return endDate.difference(startDate).inDays;
  }

  /// Formats minutes as "1h 25m" / "45m" - used for logbook & simulator
  /// duration display (those services store durationMinutes as an int).
  static String formatDurationMinutes(num totalMinutes) {
    final minutes = totalMinutes.round();
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (hours == 0) return '${remaining}m';
    if (remaining == 0) return '${hours}h';
    return '${hours}h ${remaining}m';
  }

  /// True if [date] falls on today's calendar day
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}