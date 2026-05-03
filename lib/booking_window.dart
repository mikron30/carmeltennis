// booking_window.dart
import 'israel_time.dart';

class BookingWindow {
  /// The moment a target date becomes orderable: D - 2 days at 22:00
  /// Israel local time. The returned [DateTime] uses Israel-wall-clock
  /// fields and is meant to be compared against [IsraelTime.now].
  static DateTime opensAt(DateTime targetDate) {
    final d = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return d.subtract(const Duration(days: 2)).add(const Duration(hours: 22));
  }

  /// True if `now` is at or after the opening time for `targetDate`.
  /// Both sides are evaluated in Israel wall clock so the rollover behaves
  /// the same regardless of the device's timezone.
  static bool isOpenFor(DateTime targetDate, {DateTime? now}) {
    final n = now ?? IsraelTime.now();
    return !n.isBefore(opensAt(targetDate));
  }
}
