import 'package:cloud_firestore/cloud_firestore.dart';

import 'booking_limits.dart';

class ReservationManager {
  final FirebaseFirestore _firestore;

  // firestore is injectable so the Firestore logic here is unit-testable
  // (e.g. with fake_cloud_firestore); defaults to the live instance.
  ReservationManager({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Deletes every reservation doc occupying one cell (date+court+hour) and
  /// returns how many were removed. A cell is one logical booking, but a legacy
  /// timestamp-id doc can duplicate the deterministic date_court_hour doc on the
  /// same slot — deleting a single id would leave the straggler holding the
  /// slot. This is the authoritative half of a cancellation: it must succeed
  /// before any cancellation email goes out.
  Future<int> deleteReservationCell({
    required String date,
    required int courtNumber,
    required int hour,
  }) async {
    final cell = await _firestore
        .collection('reservations')
        .where('date', isEqualTo: date)
        .where('courtNumber', isEqualTo: courtNumber)
        .where('hour', isEqualTo: hour)
        .get();
    final batch = _firestore.batch();
    for (final d in cell.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    return cell.docs.length;
  }

  Future<bool> hasExistingReservation(String userName, DateTime date) async {
    final String formattedDate = bookingDateKey(date);

    // Query for reservations where the current user is the main user
    final mainUserQuery = await _firestore
        .collection('reservations')
        .where('date', isEqualTo: formattedDate)
        .where('userName', isEqualTo: userName)
        .get();

    // Query for reservations where the current user is the partner
    final partnerQuery = await _firestore
        .collection('reservations')
        .where('date', isEqualTo: formattedDate)
        .where('partner', isEqualTo: userName)
        .get();

    // If either query returns any documents, the user has an existing reservation
    return mainUserQuery.docs.isNotEmpty || partnerQuery.docs.isNotEmpty;
  }

  Future<int> countWeeklyEveningReservations(
    String userName,
    DateTime date,
  ) async {
    final normalizedName = userName.trim();
    if (normalizedName.isEmpty) return 0;

    final startKey = bookingDateKey(startOfBookingWeek(date));
    final endKey = bookingDateKey(endOfBookingWeek(date));
    final countedDocIds = <String>{};

    final snapshots = await Future.wait([
      _firestore
          .collection('reservations')
          .where('userName', isEqualTo: normalizedName)
          .get(),
      _firestore
          .collection('reservations')
          .where('partner', isEqualTo: normalizedName)
          .get(),
    ]);

    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dateValue = data['date'];
        final hour = _readHour(data['hour']);
        if (dateValue is! String || hour == null) continue;
        final inWeek = dateValue.compareTo(startKey) >= 0 &&
            dateValue.compareTo(endKey) <= 0;
        if (inWeek && isEveningQuotaHour(hour)) {
          countedDocIds.add(doc.id);
        }
      }
    }

    return countedDocIds.length;
  }

  int? _readHour(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
