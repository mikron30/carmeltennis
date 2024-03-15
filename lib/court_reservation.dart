import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reservation.dart';
import 'reservation_manager.dart';
import 'package:intl/intl.dart';

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
  Future<Map<String, dynamic>>? _reservationsFuture;

  // Dynamic list to store reservations for each court
  List<Map<int, Map<String, dynamic>>> courtsReservations = [];
  bool isWeekend(DateTime date) {
    // In Dart, weekday 6 represents Friday and 7 represents Saturday
    return date.weekday == DateTime.friday || date.weekday == DateTime.saturday;
  } // Example: Initializing for 2 courts, you can adjust based on actual number

  void initReservations(int numberOfCourts) {
    courtsReservations = List.generate(
        numberOfCourts,
        (index) => {
              for (var i = 7; i <= 21; i++)
                i: {'isReserved': false, 'userName': '', 'partner': ''}
            });
    if (mounted) {
      setState(() {}); // Ensure UI is updated to reflect the reset state
    }
  }

  @override
  void initState() {
    DateTime selectedDate = widget.selectedDate;

    initReservations(isWeekend(selectedDate) ? 3 : 2);
    _getReservationsForDate(selectedDate);
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
    _reservationsFuture = _getReservationsForDate(widget.selectedDate);
  }

  Future<Map<String, dynamic>> _getReservationsForDate(
      DateTime selectedDate) async {
    Map<String, dynamic> reservationsData = {}; // Initialize an empty map
    String formattedDate =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        int numberOfCourts = isWeekend(selectedDate) ? 3 : 2;
        for (int i = 1; i <= numberOfCourts; i++) {
          reservationsData[i.toString()] =
              {}; // Use court number as a string key
        }
        initReservations(numberOfCourts);

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
            // Assuming 'courtNumber' is a 1-based index
            int courtIndex = reservation.court - 1;
            courtsReservations[courtIndex][reservation.time] = {
              'isReserved': true,
              'userName': reservation.user,
              'partner': reservation.partner,
            };
            String courtNumber = data['courtNumber'].toString();
            int hour = data['hour'];
            reservationsData[courtNumber][hour] = {
              'isReserved': true,
              'userName': data['userName'],
              'partner': data['partner'],
              // Add any other reservation detail you want to include
            };
          }
          setState(() {});
        }
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Update your state to reflect the error if necessary
        });
      }
    }
    return reservationsData; // Return the populated map
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
              DateTime now = DateTime.now();
              DateTime reservationDateTime = DateTime(selectedDate.year,
                  selectedDate.month, selectedDate.day, hour);

              // Check if the reservation time is in the past or the current hour
              if (!reservationDateTime.isBefore(now) &&
                  !(reservationDateTime.hour == now.hour)) {
                await firstDocument.reference.delete();
                courtsReservations[courtNumber - 1]
                    [hour] = {'isReserved': false, 'userName': ''};
              } else {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('שגיאה'),
                      content: const Text('לא ניתן למחוק הזמנות שקרו בעבר'),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('אישור'),
                          onPressed: () {
                            Navigator.of(context).pop(); // Close the dialog
                          },
                        ),
                      ],
                    );
                  },
                );
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
                    title: const Text('שגיאת הזמנה'),
                    content: Text("משתמש $name כבר מוזמן"),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('אישור'),
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
          _getReservationsForDate(selectedDate);
        });
      } catch (e) {
        // Handle errors or show an error message
      }
    }
  }

  String formatName(String fullName) {
    // Trim the fullName to remove leading/trailing whitespaces
    if (fullName == "") {
      return "";
    }
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

  Future<bool> _isHoliday(DateTime date) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final docSnapshot = await FirebaseFirestore.instance
        .collection('holidays')
        .doc(formattedDate)
        .get();
    return docSnapshot
        .exists; // Returns true if a holiday document exists for the selected date
  }

  Future<int> _determineNumberOfCourts(DateTime date) async {
    bool isHoliday = await _isHoliday(date);
    int dayOfWeek = date.weekday;

    if (dayOfWeek == DateTime.friday ||
        dayOfWeek == DateTime.saturday ||
        isHoliday) {
      return 3; // 3 courts on weekends and holidays
    } else {
      return 2; // 2 courts on regular days
    }
  }

  Future<Map<String, dynamic>> _fetchData(DateTime date) async {
    int numberOfCourts = await _determineNumberOfCourts(date);
    await _reservationsFuture; // This line is unnecessary if _getReservationsForDate() doesn't return a meaningful value.

    if (_reservationsFuture == null) {
      _reservationsFuture = _getReservationsForDate(date);
    }
    Map<String, dynamic>? reservationsData = await _reservationsFuture;

    return {
      'numberOfCourts': numberOfCourts,
      'reservationsData': reservationsData,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
        future: _fetchData(widget.selectedDate),
        builder: (BuildContext context,
            AsyncSnapshot<Map<String, dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            int numberOfCourts =
                snapshot.data?['numberOfCourts'] ?? 2; // Default to 2 courts
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Container(
                          // Adjust the width as needed to fit your content
                          width: MediaQuery.of(context).size.width *
                              (numberOfCourts /
                                  2), // Example dynamic width based on number of courts
                          child: Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    const Text('שעה'),
                                    for (int i = 0; i < numberOfCourts; i++)
                                      Text('מגרש ${i + 1}'),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: courtsReservations[0].length,
                                  itemBuilder: (context, index) {
                                    int hour = index + 7; // Starting from 7
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Text('$hour:00'),
                                        for (int i = 1;
                                            i <= numberOfCourts;
                                            i++)
                                          buildCourtButton(i - 1, hour),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
        });
  }

  Widget buildCourtButton(int courtIndex, int hour) {
    // Assuming courtsReservations is a list of maps, and you're accessing the 'isReserved', 'userName', and 'partner' keys
    bool isReserved =
        courtsReservations[courtIndex][hour]?['isReserved'] ?? false;
    String userName =
        formatName(courtsReservations[courtIndex][hour]?['userName'] ?? '');
    String partnerName =
        formatName(courtsReservations[courtIndex][hour]?['partner'] ?? '');

    bool isMine =
        userName == widget.myUserName || partnerName == widget.myUserName;

    // Using null-aware operators for safety
    return ElevatedButton(
      onPressed: () => _reserve(
          courtIndex + 1, hour), // Assuming court numbering starts from 1
      style: ElevatedButton.styleFrom(
        backgroundColor: isReserved
            ? isMine
                ? Colors.blue
                : Colors.red
            : Colors.green,
      ),
      child: Text(isReserved ? "$userName, $partnerName" : "פנוי - הזמן"),
    );
  }
}
