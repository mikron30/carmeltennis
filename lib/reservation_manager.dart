import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReservationManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> hasExistingReservation(String userName, DateTime date) async {
    final String formattedDate = DateFormat('yyyy-MM-dd').format(date);

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
}
