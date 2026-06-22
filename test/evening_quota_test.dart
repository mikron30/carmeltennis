import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
