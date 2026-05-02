const Set<int> kEveningQuotaHours = {18, 19, 20};
const int kWeeklyEveningQuota = 3;

bool isEveningQuotaHour(int hour) => kEveningQuotaHours.contains(hour);

DateTime startOfBookingWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday % DateTime.daysPerWeek));
}

DateTime endOfBookingWeek(DateTime date) {
  return startOfBookingWeek(date).add(const Duration(days: 6));
}

String bookingDateKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
