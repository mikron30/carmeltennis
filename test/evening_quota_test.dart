import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtk_flutter/booking_limits.dart';
import 'package:gtk_flutter/reservation_manager.dart';

// Regression for the 20:00-booking-rejected bug: the weekly evening quota count
// deduped by doc.id, so a legacy timestamp-id doc duplicating the deterministic
// date_court_hour doc on one slot got counted twice — inflating the count to the
// quota of 3 and wrongly blocking the next evening booking.
void main() {
  late FakeFirebaseFirestore fake;
  late ReservationManager mgr;
  final week = DateTime(2026, 6, 21); // any day in the booking week

  Future<void> seed(String id, String date, int court, int hour) =>
      fake.collection('reservations').doc(id).set({
        'date': date,
        'courtNumber': court,
        'hour': hour,
        'userName': 'קרינה',
        'partner': 'שותף',
        'isReserved': true,
      });

  setUp(() {
    fake = FakeFirebaseFirestore();
    mgr = ReservationManager(firestore: fake);
  });

  test('duplicate docs on one cell count once', () async {
    await seed('2026-06-21_1_18', '2026-06-21', 1, 18); // deterministic
    await seed('legacy_ts_5', '2026-06-21', 1, 18); // legacy dup, same cell
    await seed('2026-06-22_1_19', '2026-06-22', 1, 19);

    expect(await mgr.countWeeklyEveningReservations('קרינה', week), 2);
  });

  test('only evening hours within the week are counted', () async {
    await seed('a', '2026-06-21', 1, 17); // before evening window
    await seed('b', '2026-06-21', 1, 21); // after evening window
    await seed('c', '2026-06-28', 1, 20); // next week
    await seed('d', '2026-06-21', 1, 20); // counts

    expect(await mgr.countWeeklyEveningReservations('קרינה', week), 1);
  });

  test('week boundaries are DST-proof (constructor day arithmetic)', () {
    // 2026-03-28 is the Saturday after Israel's spring-forward Friday; the old
    // Duration-based subtraction crossed the 23h day and landed on 03-21 23:00.
    expect(bookingDateKey(startOfBookingWeek(DateTime(2026, 3, 28))),
        '2026-03-22');
    expect(bookingDateKey(endOfBookingWeek(DateTime(2026, 3, 22))),
        '2026-03-28');
  });

  // The quota's read-then-write race, closed inside the booking transaction:
  // the week's day locks are re-counted there, so a racing evening commit on
  // another day of the week collides instead of overshooting the quota.
  group('atomic quota guard', () {
    Future<void> book(String date, int hour,
            {String user = 'קרינה',
            Map<String, Set<String>> baseline = const {}}) =>
        mgr.createReservation(
          date: date,
          courtNumber: 1,
          hour: hour,
          userName: user,
          partner: 'שותף',
          claimDayLocks: true,
          eveningBaseline: baseline,
        );

    test('4th evening booking in a week is rejected from locks alone',
        () async {
      await book('2026-06-21', 18);
      await book('2026-06-22', 19);
      await book('2026-06-23', 20);
      // Baseline deliberately empty — simulates the racing commit whose
      // pre-check query ran before the others landed.
      await expectLater(
          book('2026-06-24', 18), throwsA(isA<BookingConflict>()));
    });

    test('lock-less legacy rows still count via the baseline', () async {
      await seed('legacy1', '2026-06-21', 1, 18);
      await seed('legacy2', '2026-06-22', 1, 19);
      await seed('legacy3', '2026-06-23', 1, 20);
      final cells = await mgr.weeklyEveningCells('קרינה', week);
      expect(cells.length, 3);
      await expectLater(
          book('2026-06-24', 18, baseline: {'קרינה': cells}),
          throwsA(isA<BookingConflict>()));
    });

    test('baseline and locks dedup by cell, not double-count', () async {
      // One booking known to BOTH the baseline query and its own day lock
      // must count once — not twice.
      await book('2026-06-21', 18);
      final cells = await mgr.weeklyEveningCells('קרינה', week);
      expect(cells.length, 1);
      await book('2026-06-22', 19, baseline: {'קרינה': cells}); // 2nd: fine
      await book('2026-06-23', 20); // 3rd: fine
      await expectLater(
          book('2026-06-24', 18), throwsA(isA<BookingConflict>()));
    });

    test('non-evening booking is allowed at full evening quota', () async {
      await book('2026-06-21', 18);
      await book('2026-06-22', 19);
      await book('2026-06-23', 20);
      await book('2026-06-24', 10); // morning — must not throw
    });
  });
}
