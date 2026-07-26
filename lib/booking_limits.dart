const Set<int> kEveningQuotaHours = {18, 19, 20};
const int kWeeklyEveningQuota = 3;

bool isEveningQuotaHour(int hour) => kEveningQuotaHours.contains(hour);

// Day arithmetic via the DateTime constructor, NOT Duration: subtracting
// N*24h crosses DST changes on the device's timezone (23h/25h days) and can
// land an hour into the previous day — shifting the whole week key by a day.
DateTime startOfBookingWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return DateTime(day.year, day.month, day.day - day.weekday % DateTime.daysPerWeek);
}

DateTime endOfBookingWeek(DateTime date) {
  final s = startOfBookingWeek(date);
  return DateTime(s.year, s.month, s.day + 6);
}

String bookingDateKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
