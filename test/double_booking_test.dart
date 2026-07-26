import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtk_flutter/reservation_manager.dart';

// Regression for the two-bookings-on-one-day bug (2026-07-21: the same pair
// held 07:00 court 1 AND 10:00 court 2). hasExistingReservation is a read, and
// the write that follows lands on a different cell, so the deterministic cell
// id never collided. Only a transaction over the per-member day lock does.
void main() {
  late FakeFirebaseFirestore fake;
  late ReservationManager mgr;
  const date = '2026-07-21';
  const a = 'גדעון כהן';
  const b = 'זאב לוי';

  Future<void> book(int court, int hour,
          {String user = a, String partner = b, bool manager = false}) =>
      mgr.createReservation(
        date: date,
        courtNumber: court,
        hour: hour,
        userName: user,
        partner: partner,
        claimDayLocks: !manager,
      );

  setUp(() {
    fake = FakeFirebaseFirestore();
    mgr = ReservationManager(firestore: fake);
  });

  test('same pair cannot take a second slot on the same date', () async {
    await book(1, 7);
    await expectLater(book(2, 10), throwsA(isA<BookingConflict>()));

    final all = await fake.collection('reservations').get();
    expect(all.docs.length, 1, reason: 'the 10:00 booking must not be written');
  });

  test('blocks whichever side is already booked, including as partner',
      () async {
    await book(1, 7);
    // b was the partner at 07:00; now b tries to book as the main user.
    await expectLater(
        book(2, 10, user: b, partner: 'מישהו אחר'),
        throwsA(isA<BookingConflict>()));
    // ...and someone else pulling a already booked in is blocked too.
    await expectLater(
        book(2, 11, user: 'מישהו אחר', partner: a),
        throwsA(isA<BookingConflict>()));
  });

  test('name matching ignores case and surrounding whitespace', () async {
    await book(1, 7);
    await expectLater(
        book(2, 10, user: '  גדעון כהן  ', partner: 'מישהו אחר'),
        throwsA(isA<BookingConflict>()));
  });

  test('cancelling releases the day lock so the pair can rebook', () async {
    await book(1, 7);
    await mgr.deleteReservationCell(date: date, courtNumber: 1, hour: 7);
    await book(2, 10); // must not throw
    expect((await fake.collection('reservations').get()).docs.length, 1);
  });

  test('a different date is unaffected', () async {
    await book(1, 7);
    await mgr.createReservation(
      date: '2026-07-22',
      courtNumber: 1,
      hour: 7,
      userName: a,
      partner: b,
      claimDayLocks: true,
    );
    expect((await fake.collection('reservations').get()).docs.length, 2);
  });

  test('two bookings on one cell still collide', () async {
    await book(1, 7);
    await expectLater(
        book(1, 7, user: 'אחר א', partner: 'אחר ב'),
        throwsA(isA<BookingConflict>()));
  });

  test('managers keep their override and take no locks', () async {
    await book(1, 7, manager: true);
    await book(2, 10, manager: true); // must not throw
    expect((await fake.collection('day_locks').get()).docs, isEmpty);
  });

  test('a lock whose reservation vanished outside the app is reclaimed',
      () async {
    await book(1, 7);
    // Simulate an admin console / delete_all_reservations.py wipe that does
    // not know about day_locks — the member must not be barred forever.
    await fake
        .collection('reservations')
        .doc(reservationCellId(date, 1, 7))
        .delete();
    await book(2, 10); // must not throw
  });

  test('a stale lock pointing at someone else\'s booking is reclaimed',
      () async {
    // The way a member could get stuck for good: their booking is wiped
    // outside the app (admin console / delete_all_reservations.py) so the lock
    // survives, and the freed cell is then taken by somebody else. Checking
    // only that the cell exists would bar them from that date forever.
    await book(1, 7); // a+b hold cell 1_7, locks point at it
    await fake
        .collection('reservations')
        .doc(reservationCellId(date, 1, 7))
        .delete(); // external wipe — locks left behind
    await book(1, 7, user: 'זר אחד', partner: 'זר שני'); // someone else takes it

    await book(2, 10); // a+b must still be able to book — must not throw
    expect((await fake.collection('reservations').get()).docs.length, 2);
  });

  test('a stale lock pointing at the booked cell itself is reclaimed',
      () async {
    // Same external wipe, but the member rebooks the SAME slot the stale lock
    // points at — the cell is free, so the lock must not block it.
    await fake.collection('day_locks').doc(dayLockId(date, a)).set(
        {'cell': reservationCellId(date, 1, 7), 'date': date, 'hour': 7});
    await book(1, 7); // must not throw
  });

  test('cancelling a manager booking leaves an unrelated day lock armed',
      () async {
    await book(1, 7); // a+b, locks -> cell 1_7
    await book(2, 10, user: 'מנהל', partner: a, manager: true); // no locks
    await mgr.deleteReservationCell(date: date, courtNumber: 2, hour: 10);
    // a is still booked at 07:00 — the guard must still hold.
    await expectLater(book(3, 11, user: a, partner: 'מישהו אחר'),
        throwsA(isA<BookingConflict>()));
  });
}
