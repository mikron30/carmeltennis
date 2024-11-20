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
  int numberOfCourts = 2; // Default to 2 courts, will be updated in initState
  // Dynamic list to store reservations for each court
  List<Map<int, Map<String, dynamic>>> courtsReservations = [];
  String? holidayType;
  void initReservations(int numberOfCourts) {
    // Clear the existing reservations to avoid conflicts
    courtsReservations.clear();
    // Initialize the reservation structure for each court
    courtsReservations = List.generate(
        numberOfCourts,
        (index) => {
              for (var i = 7;
                  i <= 21;
                  i++) // Reserve slots between 7:00 and 21:00
                i: {'isReserved': false, 'userName': '', 'partner': ''}
            });
    // Ensure the UI is updated after initializing reservations
    if (mounted) {
      setState(() {}); // Ensure a UI update after reservation changes
    }
  }

  @override
  void initState() {
    super.initState();
    _determineNumberOfCourts(widget.selectedDate).then((courtCount) {
      setState(() {
        numberOfCourts = courtCount;
        initReservations(numberOfCourts);
        _fetchReservations();
      });
    });
  }

  @override
  void didUpdateWidget(covariant CourtReservations oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _determineNumberOfCourts(widget.selectedDate).then((courtCount) {
        setState(() {
          numberOfCourts = courtCount;
          initReservations(numberOfCourts);
          _fetchReservations();
        });
      });
    }
  }

  Future<String> _getHolidayType(DateTime date) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final docSnapshot = await FirebaseFirestore.instance
        .collection('holidays')
        .doc(formattedDate)
        .get();

    if (docSnapshot.exists) {
      return docSnapshot['holidayType'] ?? 'חג';
    }
    return 'רגיל'; // Return 'regular' if there's no holiday
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

  Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('אישור מחיקה'),
              content: const Text('האם אתה בטוח שברצונך למחוק את ההזמנה?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('ביטול'),
                  onPressed: () {
                    Navigator.of(context)
                        .pop(false); // Return false if canceled
                  },
                ),
                TextButton(
                  child: const Text('אישור'),
                  onPressed: () {
                    Navigator.of(context).pop(true); // Return true if confirmed
                  },
                ),
              ],
            );
          },
        ) ??
        false; // Return false if dialog is dismissed
  }

  Future<void> updateLastFivePartners(
      String userEmail, String newPartner) async {
    // Query the users_2024 collection where the מייל field matches the userEmail
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users_2024')
        .where('מייל', isEqualTo: userEmail)
        .get();

    // If a document is found, proceed with updating the lastFivePartners field
    if (querySnapshot.docs.isNotEmpty) {
      DocumentReference userDoc = querySnapshot.docs.first.reference;
      DocumentSnapshot userSnapshot = await userDoc.get();

      List<String> lastFivePartners = [];

      if (userSnapshot.exists) {
        // Use try-catch block to handle potential errors if lastFivePartners does not exist
        try {
          lastFivePartners =
              List<String>.from(userSnapshot['lastFivePartners'] ?? []);
        } catch (e) {
          // If lastFivePartners does not exist, initialize it as an empty list
          lastFivePartners = [];
        }
      }

      // Add the new partner to the list and ensure only 5 are kept
      if (!newPartner.startsWith('!') &&
          !lastFivePartners.contains(newPartner)) {
        lastFivePartners.add(newPartner);
        if (lastFivePartners.length > 5) {
          lastFivePartners.removeAt(0); // Keep only the last 5
        }
      }

      // Update Firestore with the updated lastFivePartners list
      await userDoc.update({'lastFivePartners': lastFivePartners});
    } else {
      // Handle case where the user document is not found (if needed)
      print("User document not found for email: $userEmail");
    }
  }

  // Add this function to count the weekly reservations between specific hours
  Future<int> _countReservation(String userName, DateTime selectedDate,
      int startHour, int endHour) async {
    // Define the start and end of the week (Sunday to Thursday)
    DateTime startOfWeek = selectedDate.subtract(
      Duration(days: (selectedDate.weekday % 7)),
    );
    DateTime endOfWeek = startOfWeek.add(Duration(days: 4)); // End on Thursday

    String startOfWeekFormatted = DateFormat('yyyy-MM-dd').format(startOfWeek);
    String endOfWeekFormatted = DateFormat('yyyy-MM-dd').format(endOfWeek);

    try {
      // Query for reservations where userName equals userName
      final userNameQuery = FirebaseFirestore.instance
          .collection('reservations')
          .where('userName', isEqualTo: userName);
      final QuerySnapshot userNameSnapshot = await userNameQuery.get();

      // Filter each result set for the date range and specific hours
      int userNameCount = userNameSnapshot.docs.where((doc) {
        String date = doc['date'];
        int hour = doc['hour'];
        bool withinDateRange = date.compareTo(startOfWeekFormatted) >= 0 &&
            date.compareTo(endOfWeekFormatted) <= 0;
        bool withinHours = hour >= startHour && hour <= endHour;
        return withinDateRange && withinHours;
      }).length;

      final partnerNameQuery = FirebaseFirestore.instance
          .collection('reservations')
          .where('partner', isEqualTo: userName);
      final QuerySnapshot partnerNameSnapshot = await partnerNameQuery.get();

      // Filter each result set for the date range and specific hours
      int partnerNameCount = partnerNameSnapshot.docs.where((doc) {
        String date = doc['date'];
        int hour = doc['hour'];
        bool withinDateRange = date.compareTo(startOfWeekFormatted) >= 0 &&
            date.compareTo(endOfWeekFormatted) <= 0;
        bool withinHours = hour >= startHour && hour <= endHour;
        return withinDateRange && withinHours;
      }).length;

      int total = partnerNameCount + userNameCount;
      print("reservations count $total");

      // Return the total count
      return total;
    } catch (e) {
      // Handle any errors
      print("Error in counting weekly reservations between hours: $e");
      return 0; // Return a default value in case of error
    }
  }

  bool isBeforeOrNow(DateTime reservationDateTime) {
    DateTime now = DateTime.now();
    DateTime currentDateTime = DateTime(now.year, now.month, now.day, now.hour);

    return reservationDateTime.isBefore(currentDateTime) ||
        reservationDateTime.isAtSameMomentAs(currentDateTime);
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
        bool isManager = widget.myUserName == "אודי אש" ||
            widget.myUserName == "רני לפלר" ||
            widget.myUserName == "עפר בן ישי" ||
            widget.myUserName == "מיקי זילברשטיין" ||
            widget.myUserName == "מועדון כרמל";

        final existingReservationSnapshot =
            await existingReservationQuery.get();
        DateTime now = DateTime.now();
        DateTime reservationDateTime = DateTime(
            selectedDate.year, selectedDate.month, selectedDate.day, hour);
        if (existingReservationSnapshot.docs.isNotEmpty) {
          // Assuming you have only one document with a matching username,
          // you can access the username from the first document.
          final firstDocument = existingReservationSnapshot.docs.first;
          final data = firstDocument.data();
          final storedUserName = data['userName'];
          final partnerUserName = data['partner'];
          if (storedUserName == widget.myUserName ||
              partnerUserName == widget.myUserName ||
              isManager) {
            try {
              if (isManager || (!isBeforeOrNow(reservationDateTime))) {
                // Await confirmation dialog and check if widget is still mounted
                bool confirmDelete =
                    await _showDeleteConfirmationDialog(context);
                if (!mounted) return; // Check if still mounted after async call
                if (confirmDelete) {
                  // Check if the reservation time is in the past or the current hour
                  await firstDocument.reference.delete();
                  courtsReservations[courtNumber - 1]
                      [hour] = {'isReserved': false, 'userName': ''};
                }
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
          if (isManager || widget.selectedPartner != '') {
            ReservationManager reservationManager = ReservationManager();

            // Check if the user or the partner already has a reservation on the given date
            bool userHasReservation = await reservationManager
                .hasExistingReservation(widget.myUserName ?? '', selectedDate);
            bool partnerHasReservation =
                await reservationManager.hasExistingReservation(
                    widget.selectedPartner ?? '', selectedDate);

            if (!isManager && (userHasReservation || partnerHasReservation)) {
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
              if (reservationDateTime.isBefore(now)) {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('שגיאה'),
                      content: const Text('לא ניתן להזמין בעבר'),
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
                bool canReserveMe = await _countReservation(
                        widget.myUserName ?? '', selectedDate, 18, 20) <
                    3;
                bool canReservepartner = await _countReservation(
                        widget.selectedPartner ?? '', selectedDate, 18, 20) <
                    3;
                if (!isManager &&
                    hour >= 18 &&
                    hour <= 20 &&
                    (!canReserveMe || !canReservepartner)) {
                  // Show an error message if the user exceeded the weekly limit
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('שגיאה'),
                        content: canReservepartner
                            ? const Text(
                                ' הגעת למכסת ההזמנות השבועיות בשעות הערב 6 עד 9')
                            : const Text(
                                ' השותפ.ה הגיע.ה למכסת ההזמנות השבועיות בשעות הערב 6 עד 9'),
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
                  return; // Exit the function without reserving
                }

                // Create the reservation data including the date
                final reservationData = {
                  'date': formattedDate, // Add the date to the reservation data
                  'courtNumber': courtNumber,
                  'hour': hour,
                  'isReserved': true,
                  'userName': widget.myUserName!.trim(),
                  'partner': widget.selectedPartner!.trim(),
                };
                final reservationId = DateTime.now().toUtc().toIso8601String();
                // Store the reservation in Firestore using the unique reservation ID
                await FirebaseFirestore.instance
                    .collection('reservations')
                    .doc(reservationId)
                    .set(reservationData);

                // Update the last 5 partners after the reservation is saved
                await updateLastFivePartners(
                    user.email!, widget.selectedPartner!.trim());
              }
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

  Future<int> _determineNumberOfCourts(DateTime date) async {
    holidayType = await _getHolidayType(date);
    int dayOfWeek = date.weekday;
    // Determine the number of courts based on the holiday type
    if (holidayType == 'אין מגרשים') {
      return 0; // No courts available
    } else if (holidayType == 'מגרש אחד') {
      return 1; // Only one court available
    } else if (holidayType == 'חג' ||
        holidayType == 'ערב חג' ||
        dayOfWeek == DateTime.friday ||
        dayOfWeek == DateTime.saturday) {
      return 3; // Only one court available
    }
    return 2;
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
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          // Debugging the number of courts

          return Column(
            children: [
              // Header Row for Time and Courts
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Time Column
                    Expanded(
                      child: Center(
                        child: const Text('שעה'),
                      ),
                    ),
                    // Court Columns
                    for (int i = 0; i < numberOfCourts; i++)
                      Expanded(
                        child: Center(
                          child: Text('מגרש ${i + 1}'),
                        ),
                      ),
                  ],
                ),
              ),
              // Body with Reservation Data
              Expanded(
                child: ListView.builder(
                  itemCount: courtsReservations.isNotEmpty
                      ? courtsReservations[0].length
                      : 0, // Ensure the length is correct
                  itemBuilder: (context, index) {
                    int hour = index + 7; // Starting from 7

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Time Column for Each Row
                        Expanded(
                          child: Center(
                            child: Text('$hour:00'),
                          ),
                        ),
                        // Loop through each court and build button for each court in the row
                        for (int i = 0; i < numberOfCourts; i++)
                          Expanded(
                            child: Center(
                              child: buildCourtButton(i, hour),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget buildCourtButton(int courtIndex, int hour) {
    // Check if courtIndex is within the range of courtsReservations
    if (courtIndex < 0 || courtIndex >= courtsReservations.length) {
      // Handle the invalid courtIndex case (e.g., by returning a disabled button)
      return ElevatedButton(
        onPressed: null, // Disabled button
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
        ),
        child: const Text("Invalid"),
      );
    }

    // Check if the hour is a valid key in the court's reservation map
    if (!courtsReservations[courtIndex].containsKey(hour)) {
      // Handle the invalid hour case (e.g., by returning a disabled button)
      return ElevatedButton(
        onPressed: null, // Disabled button
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
        ),
        child: const Text("Invalid Hour"),
      );
    }

    // Assuming courtsReservations is a list of maps, and you're accessing the 'isReserved', 'userName', and 'partner' keys
    bool isReserved =
        courtsReservations[courtIndex][hour]?['isReserved'] ?? false;
    String? longUserName = courtsReservations[courtIndex][hour]?['userName'];
    String userName = formatName(longUserName ?? '');
    String? longPartnerName = courtsReservations[courtIndex][hour]?['partner'];
    String partnerName = formatName(longPartnerName ?? '');
    // Check if the partner field starts with "!" indicating a custom message
    bool isCustomMessage =
        longPartnerName != null && longPartnerName.startsWith('!');
    // Remove the leading "!" for display if it's a custom message
    String displayMessage = isCustomMessage
        ? longPartnerName!.substring(1) // Remove "!" for custom messages
        : "$userName, $partnerName"; // Display as usual if it's a regular partner

    // Create a DateTime object for the current slot's time on the selected date
    DateTime now = DateTime.now();
    DateTime reservationDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      hour,
    );

    // Disable the button if the date/time is in the past
    bool isPast = reservationDateTime.isBefore(now);

    bool isMine = longUserName == widget.myUserName ||
        longPartnerName == widget.myUserName;
    bool isManager = widget.myUserName == "אודי אש" ||
        widget.myUserName == "רני לפלר" ||
        widget.myUserName == "עפר בן ישי" ||
        widget.myUserName == "מיקי זילברשטיין" ||
        widget.myUserName == "מועדון כרמל";

    // Using null-aware operators for safety
    if (((widget.selectedDate.weekday == DateTime.friday ||
            (holidayType != null && holidayType == "ערב חג"))) &&
        (hour >= 7 && hour <= 18) &&
        courtIndex == 2) {
      return ElevatedButton(
        onPressed: null, // Disable the button
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
        child: Text("מאמן"),
      );
    } else {
// Disable if the time is in the past
      return ElevatedButton(
        onPressed: (isPast && !isReserved && !isManager)
            ? null // Disable if unreserved, in the past, and user is not a manager
            : () {
                // Check if the reservation is by someone else and not the user's
                if (isReserved && !isMine && !isManager) {
                  return; // Do nothing if the slot is reserved by someone else
                }
                // Proceed with reservation if conditions are valid
                _reserve(courtIndex + 1, hour);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: isReserved
              ? (isMine
                  ? Colors.blue
                  : Colors
                      .red) // Blue if it's the user's reservation, Red if someone else's
              : (isPast
                  ? Colors.grey
                  : Colors
                      .green), // Gray for past unreserved slots, Green for available
        ),
        child: Text(
          isReserved
              ? displayMessage
              : isPast
                  ? "סגור" // Label for past time slots
                  : "פנוי", // Label for available slots
        ),
      );
    }
  }
}
