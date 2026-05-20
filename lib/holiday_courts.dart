import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Session-scoped cache keyed by 'yyyy-MM-dd'. Holiday docs change rarely and
// the admin editor calls [clearHolidayCache] after writing, so within-session
// edits show up on the next day-switch. A page reload clears it.
final Map<String, String> _holidayTypeCache = {};

/// Looks up the `holidays/<yyyy-MM-dd>` doc and returns the `holidayType` field
/// (e.g. 'חג', 'ערב חג', 'מגרש אחד', 'אין מגרשים') or 'רגיל' if no override exists.
Future<String> getHolidayType(DateTime date) async {
  final formattedDate = DateFormat('yyyy-MM-dd').format(date);
  final cached = _holidayTypeCache[formattedDate];
  if (cached != null) return cached;
  final docSnapshot = await FirebaseFirestore.instance
      .collection('holidays')
      .doc(formattedDate)
      .get();
  final type = docSnapshot.exists
      ? ((docSnapshot['holidayType'] ?? 'חג') as String)
      : 'רגיל';
  _holidayTypeCache[formattedDate] = type;
  return type;
}

/// Invalidate the session-scoped holiday-type cache. Call after editing or
/// deleting a holiday doc so the booking screen re-fetches on the next visit.
void clearHolidayCache() {
  _holidayTypeCache.clear();
}

/// Resolves the number of bookable courts for a given date based on the
/// holiday override and weekday rules:
/// - 'אין מגרשים' → 0
/// - 'מגרש אחד' → 1
/// - 'חג' / 'ערב חג' / Friday / Saturday → 3
/// - default → 2
Future<int> determineNumberOfCourts(DateTime date) async {
  final holidayType = await getHolidayType(date);
  return numberOfCourtsFor(date, holidayType);
}

/// Synchronous variant when the holiday type is already known.
int numberOfCourtsFor(DateTime date, String holidayType) {
  if (holidayType == 'אין מגרשים') return 0;
  if (holidayType == 'מגרש אחד') return 1;
  final dayOfWeek = date.weekday;
  if (holidayType == 'חג' ||
      holidayType == 'ערב חג' ||
      dayOfWeek == DateTime.friday ||
      dayOfWeek == DateTime.saturday) {
    return 3;
  }
  return 2;
}

/// True when the given (date, hour, courtUiIndex) cell falls on the
/// Friday/holiday-eve coach line. UI court index 0 = leftmost = highest court
/// number; the coach line lives in the leftmost column at hours 7..18.
bool isCoachSlot({
  required DateTime date,
  required int hour,
  required int courtUiIndex,
  required String holidayType,
}) {
  if (courtUiIndex != 0) return false;
  if (hour < 7 || hour > 18) return false;
  if (holidayType == 'חג') return false;
  final isFriday = date.weekday == DateTime.friday;
  return isFriday || holidayType == 'ערב חג';
}
