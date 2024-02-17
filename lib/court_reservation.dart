import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reservation.dart';
import 'user_manager.dart';

class CourtReservations extends StatefulWidget {
  final DateTime selectedDate; // Selected date passed from DateSelector
  final String? selectedPartner; // Add this line

  CourtReservations(
      {required this.selectedDate, Key? key, this.selectedPartner})
      : super(key: key);

  @override
  CourtReservationsState createState() => CourtReservationsState();
}

class CourtReservationsState extends State<CourtReservations> {
  CourtReservationsState(); // Constructor to receive the selected date

  // Sample data for two courts
  Map<int, Map<dynamic, dynamic>> court1Reservations = {
    for (var i = 7; i <= 21; i++)
      i: {'isReserved': false, 'userName': '', 'partner': ''},
  };

  Map<int, Map<dynamic, dynamic>> court2Reservations = {
    for (var i = 7; i <= 21; i++)
      i: {'isReserved': false, 'userName': '', 'partner': ''},
  };

  @override
  void initState() {
    DateTime selectedDate = widget.selectedDate;
    String formattedDate =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    _getReservationsForDate(formattedDate);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant CourtReservations oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if the selectedDate has changed
    if (widget.selectedDate != oldWidget.selectedDate) {
      String formattedDate =
          "${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}";
      // Call _getReservations to refresh the screen with updated data
      // Schedule a delayed call to _getReservations after 500 milliseconds (adjust the delay as needed)
      _getReservationsForDate(formattedDate);
    }
  }

  Future<void> _getReservationsForDate(String formattedDate) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Create a query to fetch all reservations for the specified date
        final query = FirebaseFirestore.instance
            .collection('reservations')
            .where('date', isEqualTo: formattedDate);

        // Fetch the documents that match the query
        final QuerySnapshot querySnapshot = await query.get();

        if (querySnapshot.docs.isNotEmpty) {
          // Process the reservation data here
          final List<Reservation> reservations = [];
          for (final doc in querySnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final reservation = Reservation(
              // Create a Reservation object or a data structure to hold the reservation data
              // You may need to define the Reservation class accordingly
              date: data['date'],
              court: data['courtNumber'],
              time: data['hour'],
              user: data['userName'],
              partner: data['partner'],
            );
            reservations.add(reservation);
            if (reservation.court == 1)
              court1Reservations[reservation.time] = {
                'isReserved': true,
                'userName': reservation.user,
                'partner': reservation.partner,
              };
            if (reservation.court == 2)
              court2Reservations[reservation.time] = {
                'isReserved': true,
                'userName': reservation.user,
                'partner': reservation.partner,
              };
          }

          // Now, you have the list of reservations for the specified date in the 'reservations' variable
          // You can use this data as needed
        } else {
          // empty data for two courts
          court1Reservations = {
            for (var i = 7; i <= 21; i++)
              i: {'isReserved': false, 'userName': '', 'partner': ''},
          };

          court2Reservations = {
            for (var i = 7; i <= 21; i++)
              i: {'isReserved': false, 'userName': '', 'partner': ''},
          };

          // No reservations found for the specified date
        }
      }
    } catch (e) {
      print('Error fetching reservations: $e');
      // Handle errors or show an error message
    }
    setState(() {});
  }

  void _reserve(int courtNumber, int hour) async {
    final User? user = FirebaseAuth.instance.currentUser;
    DateTime selectedDate = widget.selectedDate;
    if (user != null) {
      String? userEmail =
          FirebaseAuth.instance.currentUser?.email; // Now assigns user's email
      final String? userName =
          await UserManager.instance.getUsernameByEmail(userEmail ?? '');

      try {
        // Format the selected date to match the Firestore document ID format (e.g., 'yyyy-MM-dd')
        String formattedDate =
            "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

        // Create a query to check for an existing reservation with the same court and hour
        final existingReservationQuery = FirebaseFirestore.instance
            .collection('reservations')
            .where('date', isEqualTo: formattedDate)
            .where('courtNumber', isEqualTo: courtNumber)
            .where('hour', isEqualTo: hour);

        final existingReservationSnapshot =
            await existingReservationQuery.get();
        if (existingReservationSnapshot.docs.isNotEmpty) {
          // Assuming you have only one document with a matching username,
          // you can access the username from the first document.
          final firstDocument = existingReservationSnapshot.docs.first;
          final data = firstDocument.data();
          final storedUserName = data['userName'];
          if (storedUserName == userName) {
            try {
              await firstDocument.reference.delete();
              if (courtNumber == 1)
                court1Reservations[hour] = {
                  'isReserved': false,
                  'userName': ''
                };
              else if (courtNumber == 2)
                court1Reservations[hour] = {
                  'isReserved': false,
                  'userName': ''
                };
            } catch (e) {
              print('Error deleting reservation: $e');
              // Handle the error as needed
            }
          }
        } else {
          if (widget.selectedPartner != '') {
            // Create the reservation data including the date
            final reservationData = {
              'date': formattedDate, // Add the date to the reservation data
              'courtNumber': courtNumber,
              'hour': hour,
              'isReserved': true,
              'userName': userName,
              'partner': widget.selectedPartner,
            };
            final reservationId = DateTime.now().toUtc().toIso8601String();
            // Store the reservation in Firestore using the unique reservation ID
            await FirebaseFirestore.instance
                .collection('reservations')
                .doc(reservationId)
                .set(reservationData);
          }
        }
        // Call _getReservations to refresh the screen with updated data
        // Schedule a delayed call to _getReservations after 500 milliseconds (adjust the delay as needed)
        Future.delayed(Duration(milliseconds: 500), () {
          _getReservationsForDate(formattedDate);
        });
      } catch (e) {
        print('Error reserving court: $e');
        // Handle errors or show an error message
      }
    }
  }

  Widget buildCourt(
      int courtNumber, Map<int, Map<dynamic, dynamic>> reservations) {
    return Column(
      children: reservations.entries.map((entry) {
        final int hour = entry.key;
        final Map<dynamic, dynamic> reservationData = entry.value;
        final bool isReserved = reservationData['isReserved'];
        final String reservedBy = reservationData['userName'];
        final String partner = reservationData['partner'] ?? '';

        return ListTile(
          title: Text('$hour:00'),
          subtitle: Text('$reservedBy, $partner'),
          trailing: isReserved
              ? Icon(Icons.check, color: Colors.green)
              : Icon(Icons.close, color: Colors.red),
          onTap: () => _reserve(courtNumber, hour),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime selectedDate = widget.selectedDate;
    String formattedDate =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    _getReservationsForDate(formattedDate);
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            children: <Widget>[
              buildCourt(1, court1Reservations),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: <Widget>[
              buildCourt(2, court2Reservations),
            ],
          ),
        ),
      ],
    );
  }
}
