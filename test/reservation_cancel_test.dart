import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtk_flutter/reservation_manager.dart';

// Regression for the cancel-but-slot-stays-booked bug: cancelling used to delete
// a single doc id, so a duplicate doc on the same cell (legacy timestamp id vs
// deterministic date_court_hour id) survived and kept the slot "taken" for
// everyone — while the cancellation email had already gone out.
void main() {
  late FakeFirebaseFirestore fake;
  late CollectionReference<Map<String, dynamic>> res;
  late ReservationManager mgr;

  Future<void> seedCell(String id) => res.doc(id).set({
        'date': '2026-06-21',
        'courtNumber': 1,
        'hour': 20,
        'userName': 'אבי כהן',
        'partner': 'דנה לוי',
        'isReserved': true,
      });

  setUp(() {
    fake = FakeFirebaseFirestore();
    res = fake.collection('reservations');
    mgr = ReservationManager(firestore: fake);
  });

  test('sweeps every duplicate on the cell, leaves other slots alone', () async {
    await seedCell('2026-06-21_1_20'); // deterministic id
    await seedCell('legacy_ts_991122'); // legacy timestamp-id duplicate, same cell
    await res.add({
      'date': '2026-06-21', // unrelated booking — must survive
      'courtNumber': 2,
      'hour': 20,
      'userName': 'מישהו אחר',
      'partner': 'שותף',
      'isReserved': true,
    });

    final removed = await mgr.deleteReservationCell(
        date: '2026-06-21', courtNumber: 1, hour: 20);

    expect(removed, 2, reason: 'both docs on the cell should be deleted');

    final cellLeft = await res
        .where('date', isEqualTo: '2026-06-21')
        .where('courtNumber', isEqualTo: 1)
        .where('hour', isEqualTo: 20)
        .get();
    expect(cellLeft.docs, isEmpty, reason: 'no straggler may hold the slot');

    final all = await res.get();
    expect(all.docs.length, 1);
    expect(all.docs.first.data()['courtNumber'], 2,
        reason: 'the neighbouring booking must be untouched');
  });

  test('returns 0 when the cell is already empty', () async {
    final removed = await mgr.deleteReservationCell(
        date: '2026-06-21', courtNumber: 1, hour: 20);
    expect(removed, 0);
  });
}
