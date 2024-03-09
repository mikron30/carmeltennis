import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reservation.dart';
import 'user_manager.dart';
import 'reservation_manager.dart';

class CourtReservations extends StatefulWidget {
  final DateTime selectedDate; // Selected date passed from DateSelector
  final String? selectedPartner; // Add this line
  final String? myUserName;

  const CourtReservations(
      {required this.selectedDate,
      super.key,
      this.selectedPartner,
      this.myUserName});

  @override
  CourtReservationsState createState() => CourtReservationsState();
}

class CourtReservationsState extends State<CourtReservations> {
  CourtReservationsState(); // Constructor to receive the selected date
  Future<void>? _reservationsFuture;

  // Sample data for two courts
  Map<int, Map<dynamic, dynamic>> court1Reservations = {
    for (var i = 7; i <= 21; i++)
      i: {'isReserved': false, 'userName': '', 'partner': ''},
  };

  Map<int, Map<dynamic, dynamic>> court2Reservations = {
    for (var i = 7; i <= 21; i++)
      i: {'isReserved': false, 'userName': '', 'partner': ''},
  };

  void initReservations() {
    // Initialize or reset your reservations data here
    court1Reservations = {
      for (var i = 7; i <= 21; i++)
        i: {'isReserved': false, 'userName': '', 'partner': ''},
    };
    court2Reservations = {
      for (var i = 7; i <= 21; i++)
        i: {'isReserved': false, 'userName': '', 'partner': ''},
    };
    if (mounted) {
      setState(() {}); // Ensure UI is updated to reflect the reset state
    }
  }

  @override
  void initState() {
    DateTime selectedDate = widget.selectedDate;
    String formattedDate =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    initReservations();
    _getReservationsForDate(formattedDate);
    super.initState();
    _fetchReservations();
  }

  @override
  void didUpdateWidget(covariant CourtReservations oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _fetchReservations(); // Fetch reservations when the selected date changes
    }
  }

  void _fetchReservations() {
    String formattedDate =
        "${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}";
    _reservationsFuture = _getReservationsForDate(formattedDate);
  }

  Future<void> _getReservationsForDate(String formattedDate) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        court1Reservations.clear();
        court2Reservations.clear();
        for (var i = 7; i <= 21; i++) {
          court1Reservations[i] = {
            'isReserved': false,
            'userName': '',
            'partner': ''
          };
          court2Reservations[i] = {
            'isReserved': false,
            'userName': '',
            'partner': ''
          };
        }
        final query = FirebaseFirestore.instance
            .collection('reservations')
            .where('date', isEqualTo: formattedDate);

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
            if (reservation.court == 1) {
              court1Reservations[reservation.time] = {
                'isReserved': true,
                'userName': reservation.user,
                'partner': reservation.partner,
              };
            }
            if (reservation.court == 2) {
              court2Reservations[reservation.time] = {
                'isReserved': true,
                'userName': reservation.user,
                'partner': reservation.partner,
              };
            }
          }
          setState(() {});
        }
        setState(() {});
      }
    } catch (e) {
      print('Error fetching reservations: $e');
      if (mounted) {
        setState(() {
          // Update your state to reflect the error if necessary
        });
      }
    }
  }

  void _reserve(int courtNumber, int hour) async {
    final User? user = FirebaseAuth.instance.currentUser;
    DateTime selectedDate = widget.selectedDate;
    if (user != null) {
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
          if (storedUserName == widget.myUserName) {
            try {
              await firstDocument.reference.delete();
              if (courtNumber == 1) {
                court1Reservations[hour] = {
                  'isReserved': false,
                  'userName': ''
                };
              } else if (courtNumber == 2) {
                court2Reservations[hour] = {
                  'isReserved': false,
                  'userName': ''
                };
              }
            } catch (e) {
              // Handle the error as needed
            }
          }
        } else {
          if (widget.selectedPartner != '') {
            ReservationManager reservationManager = ReservationManager();

            // Check if the user or the partner already has a reservation on the given date
            bool userHasReservation = await reservationManager
                .hasExistingReservation(widget.myUserName ?? '', selectedDate);
            bool partnerHasReservation =
                await reservationManager.hasExistingReservation(
                    widget.selectedPartner ?? '', selectedDate);

            if (userHasReservation || partnerHasReservation) {
              if (!mounted) {
                return; // Add this check before showDialog or using context after async gap
              }
              String? name = userHasReservation
                  ? widget.myUserName
                  : widget.selectedPartner;
              // Show popup if the user already has a reservation
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Reservation Error'),
                    content: Text("משתמש $name כבר מוזמן"),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close the dialog
                        },
                      ),
                    ],
                  );
                },
              );
            } else {
              // Create the reservation data including the date
              final reservationData = {
                'date': formattedDate, // Add the date to the reservation data
                'courtNumber': courtNumber,
                'hour': hour,
                'isReserved': true,
                'userName': widget.myUserName,
                'partner': widget.selectedPartner,
              };
              final reservationId = DateTime.now().toUtc().toIso8601String();
              // Store the reservation in Firestore using the unique reservation ID
              await FirebaseFirestore.instance
                  .collection('reservations')
                  .doc(reservationId)
                  .set(reservationData);
            }
          } else {
            // Within an async function
            if (!mounted) {
              return; // Add this check before showDialog or using context after async gap
            }
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('שגיאה'),
                  content: const Text('בבקשה הכנס שם שותף'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        if (!mounted) {
                          return; // It's also good practice to check before using context in here
                        }
                        Navigator.of(context).pop(); // Close the dialog
                      },
                      child: const Text('אישור'),
                    ),
                  ],
                );
              },
            );
          }
        }
        // Call _getReservations to refresh the screen with updated data
        // Schedule a delayed call to _getReservations after 500 milliseconds (adjust the delay as needed)
        Future.delayed(const Duration(milliseconds: 500), () {
          _getReservationsForDate(formattedDate);
        });
      } catch (e) {
        // Handle errors or show an error message
      }
    }
  }

  String formatName(String fullName) {
    // Trim the fullName to remove leading/trailing whitespaces
    fullName = fullName.trim();

    List<String> names = fullName.split(' ');

    // Filter out any empty strings that may result from multiple consecutive spaces
    names = names.where((name) => name.isNotEmpty).toList();

    if (names.length > 1) {
      // Safely assume the last element is the last name as we've filtered out empty names
      String lastNameInitial = names.last.substring(0, 1);
      // Join the first name and the initial of the last name
      return '${names.first} $lastNameInitial.';
    } else {
      // Return the first name or the full name if it doesn't include a last name
      return names.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
        future: _reservationsFuture,
        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
          // Check the state of the future
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Data is still loading
            return CircularProgressIndicator(); // Show a loader
          } else if (snapshot.hasError) {
            // An error occurred
            return Text('Error: ${snapshot.error}');
          } else {
            return Column(
              children: [
                // Header
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text('שעה'),
                      Text('מגרש 1'),
                      Text('מגרש 2'),
                    ],
                  ),
                ),
                // Reservations list
                Expanded(
                  child: ListView.builder(
                    itemCount: court1Reservations
                        .length, // Assuming equal hours for both courts
                    itemBuilder: (context, index) {
                      int hour = court1Reservations.keys.elementAt(index);
                      // Inside your ListView.builder itemBuilder
                      bool isReservedCourt1 =
                          court1Reservations[hour]!['isReserved'];
                      bool isReservedCourt2 =
                          court2Reservations[hour]!['isReserved'];
                      String userNameCourt1 = isReservedCourt1
                          ? formatName(court1Reservations[hour]!['userName'])
                          : "";
                      String partnerNameCourt1 = isReservedCourt1
                          ? formatName(court1Reservations[hour]!['partner'])
                          : "";
                      String userNameCourt2 = isReservedCourt2
                          ? formatName(court2Reservations[hour]!['userName'])
                          : "";
                      String partnerNameCourt2 = isReservedCourt2
                          ? formatName(court2Reservations[hour]!['partner'])
                          : "";
                      bool isMine1 = userNameCourt1 == widget.myUserName ||
                          partnerNameCourt1 == widget.myUserName;
                      bool isMine2 = userNameCourt2 == widget.myUserName ||
                          partnerNameCourt2 == widget.myUserName;

                      String textCourt1 = isReservedCourt1
                          ? "$userNameCourt1, $partnerNameCourt1"
                          : "פנוי - הזמן";
                      String textCourt2 = isReservedCourt2
                          ? "$userNameCourt2, $partnerNameCourt2"
                          : "פנוי - הזמן";
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Hour
                          Text('$hour:00'),
                          // Court 1 Button
                          ElevatedButton(
                            onPressed: () => _reserve(1, hour),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isMine1
                                  ? Colors.blue
                                  : isReservedCourt1
                                      ? Colors.red
                                      : Colors.green, // Updated parameter
                            ),
                            child: Text(textCourt1),
                          ),
                          // Court 2 Button
                          ElevatedButton(
                            onPressed: () => _reserve(2, hour),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isMine2
                                  ? Colors.blue
                                  : isReservedCourt2
                                      ? Colors.red
                                      : Colors.green, // Updated parameter
                            ),
                            child: Text(textCourt2),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          }
        });
  }
}
