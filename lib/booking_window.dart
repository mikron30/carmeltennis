// booking_window.dart
class BookingWindow {
  /// The moment a target date becomes orderable: D - 2 days at 22:00 local time.
  static DateTime opensAt(DateTime targetDate) {
    final d = DateTime(targetDate.year, targetDate.month, targetDate.day);
    // Subtract 2 days, then add 22 hours
    return d.subtract(const Duration(days: 2)).add(const Duration(hours: 22));
  }

  /// True if `now` is at or after the opening time for `targetDate`.
  static bool isOpenFor(DateTime targetDate, {DateTime? now}) {
    final n = now ?? DateTime.now();
    return !n.isBefore(opensAt(targetDate));
  }
}
