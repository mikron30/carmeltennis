// Israel-local time helpers.
//
// Source of truth is [ServerTime] (HTTP `Date` header anchored once, ticking
// via a monotonic [Stopwatch]) — never the device's wall clock. The Israel
// timezone offset is then applied so callers can read Y/M/D/H fields that
// match Israel local time regardless of where the device is set.

import 'server_time.dart';

class IsraelTime {
  IsraelTime._();

  /// Current time as Israel wall clock, returned as a local-flavored
  /// [DateTime] whose `year/month/day/hour/...` fields encode Israel local
  /// time. Designed to drop into existing `DateTime(y, m, d, h)` arithmetic
  /// and `.isBefore` comparisons — as long as every operand on both sides
  /// uses Israel-wall-clock fields, comparisons are consistent. Mixing this
  /// with raw `DateTime.now()` would compare different reference frames.
  static DateTime now() {
    final utc = ServerTime.utcNow();
    final shifted = utc.add(Duration(hours: _isDst(utc) ? 3 : 2));
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  // Israel DST rule (Law 5773-2013): IDT begins on the Friday before the last
  // Sunday of March (switch at 02:00 IST → 03:00 IDT) and ends on the last
  // Sunday of October (switch at 02:00 IDT → 01:00 IST).
  static bool _isDst(DateTime utc) {
    final year = utc.year;

    final lastSunMarch = _lastWeekdayOf(year, 3, DateTime.sunday);
    final fridayBefore = lastSunMarch.subtract(const Duration(days: 2));
    final dstStartUtc = DateTime.utc(
        fridayBefore.year, fridayBefore.month, fridayBefore.day);

    final lastSunOct = _lastWeekdayOf(year, 10, DateTime.sunday);
    final dstEndUtc = DateTime.utc(
        lastSunOct.year, lastSunOct.month, lastSunOct.day - 1, 23);

    return !utc.isBefore(dstStartUtc) && utc.isBefore(dstEndUtc);
  }

  static DateTime _lastWeekdayOf(int year, int month, int weekday) {
    var d = DateTime.utc(year, month + 1, 0);
    while (d.weekday != weekday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d;
  }
}
