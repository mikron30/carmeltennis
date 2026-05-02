import 'package:cloud_firestore/cloud_firestore.dart';

import 'booking_limits.dart';

class ReservationManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
