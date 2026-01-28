import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reservation.dart';
import 'reservation_manager.dart';
import 'package:intl/intl.dart';
import 'email_service.dart';
import 'user_manager.dart';

class CourtReservations extends StatefulWidget {
  final DateTime selectedDate; // Selected date passed from DateSelector
  final String? selectedPartner; // Add this line
  final String? myUserName;
  final bool useFullNames; // When true, show full names (for TV)

  const CourtReservations(
      {required this.selectedDate,
      super.key,
      this.selectedPartner,
      this.myUserName,
      this.useFullNames = false});

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
            // Map DB court number (rightmost = 1) to UI index (leftmost = 0)
            int courtIndex = numberOfCourts - reservation.court;
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
    DateTime endOfWeek = startOfWeek.add(Duration(days: 6)); // End on Thursday

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

  Future<bool> doesUserWantEmails(String email) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users_2024')
          .where('מייל', isEqualTo: email)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return data['receiveReservationEmails'] ?? false;
      }
    } catch (e) {
      print("❌ Error checking email preferences for $email: $e");
    }
    return false;
  }

  Future<String> getReservationUserName(
      String date, int courtNumber, int hour) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('reservations')
        .where('date', isEqualTo: date)
        .where('courtNumber', isEqualTo: courtNumber)
        .where('hour', isEqualTo: hour)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first['userName'] ?? '';
    }

    return '';
  }

  void _reserve(int courtNumber, int hour) async {
    final User? user = FirebaseAuth.instance.currentUser;
    DateTime selectedDate = widget.selectedDate;
    if (user != null) {
      try {
        // Format the selected date to match the Firestore document ID format (e.g., 'yyyy-MM-dd')
        String formattedDate =
            "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
        // Map UI column number (leftmost = 1) to DB court number (rightmost = 1)
        int totalCourts = await _determineNumberOfCourts(selectedDate);
        int dbCourtNumber = totalCourts - courtNumber + 1;

        // Create a query to check for an existing reservation with the same court and hour
        final existingReservationQuery = FirebaseFirestore.instance
            .collection('reservations')
            .where('date', isEqualTo: formattedDate)
            .where('courtNumber', isEqualTo: dbCourtNumber)
            .where('hour', isEqualTo: hour);
        bool isManager = widget.myUserName == "אודי אש" ||
            widget.myUserName == "רני לפלר" ||
            widget.myUserName == "עפר בן ישי" ||
            widget.myUserName == "מיקי זילברשטיין" ||
            widget.myUserName == "מועדון כרמל";
        // Restrict users from reserving for themselves if they are not a manager
        if (!isManager && widget.selectedPartner == widget.myUserName) {
          // Show an error dialog
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('שגיאת הזמנה'),
                content: const Text(
                    'לא ניתן להזמין לעצמך. בחר שותפ.ה אחר.ת להזמנה.'),
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
                if (!isManager &&
                    reservationDateTime.difference(DateTime.now()).inMinutes <
                        180) {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('שגיאה'),
                        content: const Text(
                            'לא ניתן למחוק הזמנה פחות משלוש שעות מראש'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('אישור'),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      );
                    },
                  );
                  return;
                }
                // Await confirmation dialog and check if widget is still mounted
                bool confirmDelete =
                    await _showDeleteConfirmationDialog(context);
                if (!mounted) return; // Check if still mounted after async call
                if (confirmDelete) {
                  int displayCourtNumber = dbCourtNumber;

                  final originatorEmail = user.email!;
                  final originatorName = widget.myUserName ?? '';
                  final partnerName = partnerUserName?.trim() ?? '';
                  String? partnerEmail = await UserManager.instance
                      .getEmailByUsername(partnerName);

                  final originatorWantsEmail =
                      await doesUserWantEmails(originatorEmail);
                  final partnerWantsEmail = partnerEmail != null
                      ? await doesUserWantEmails(partnerEmail)
                      : false;
                  String realPartnerName = partnerName;

                  // If the partner and originator are the same, find first reservation user
                  if (partnerName == originatorName) {
                    realPartnerName = await getReservationUserName(
                        formattedDate, dbCourtNumber, hour);
                    partnerEmail = await UserManager.instance
                        .getEmailByUsername(realPartnerName);
                  }

                  await sendReservationEmails(
                    originatorEmail: originatorEmail,
                    originatorName: originatorName,
                    originatorWantsEmail: originatorWantsEmail,
                    partnerEmail: partnerEmail ?? '',
                    partnerName: realPartnerName,
                    partnerWantsEmail: partnerWantsEmail,
                    courtNumber: displayCourtNumber,
                    date: selectedDate,
                    hour: hour,
                    isCancellation: true,
                  );

                  await firstDocument.reference.delete();
                  // Update UI state using the original UI column index
                  courtsReservations[courtNumber - 1][hour] = {
                    'isReserved': false,
                    'userName': '',
                    'partner': ''
                  };
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
                  'courtNumber': dbCourtNumber,
                  'hour': hour,
                  'isReserved': true,
                  'userName': widget.myUserName!.trim(),
                  'partner': widget.selectedPartner!.trim(),
                };
                // Optimistically update UI before the network round-trip.
                final previousCell = Map<String, dynamic>.from(
                  courtsReservations[courtNumber - 1][hour] ??
                      {'isReserved': false, 'userName': '', 'partner': ''},
                );
                setState(() {
                  courtsReservations[courtNumber - 1][hour] = {
                    'isReserved': true,
                    'userName': widget.myUserName!.trim(),
                    'partner': widget.selectedPartner!.trim(),
                  };
                });
                final reservationId = DateTime.now().toUtc().toIso8601String();
                try {
                  // Store the reservation in Firestore using the unique reservation ID
                  await FirebaseFirestore.instance
                      .collection('reservations')
                      .doc(reservationId)
                      .set(reservationData);
                } catch (e) {
                  // Roll back optimistic UI update on failure
                  if (mounted) {
                    setState(() {
                      courtsReservations[courtNumber - 1][hour] = previousCell;
                    });
                  }
                  rethrow;
                }

                // Update the last 5 partners after the reservation is saved
                await updateLastFivePartners(
                    user.email!, widget.selectedPartner!.trim());

                int displayCourtNumber = dbCourtNumber;

                final originatorEmail = user.email!;
                final originatorName = widget.myUserName ?? '';
                final partnerName = widget.selectedPartner?.trim() ?? '';
                final partnerEmail =
                    await UserManager.instance.getEmailByUsername(partnerName);

                // בדיקת העדפות מייל
                final originatorWantsEmail =
                    await doesUserWantEmails(originatorEmail);
                final partnerWantsEmail = partnerEmail != null
                    ? await doesUserWantEmails(partnerEmail)
                    : false;

                await sendReservationEmails(
                  originatorEmail: originatorEmail,
                  originatorName: originatorName,
                  originatorWantsEmail: originatorWantsEmail,
                  partnerEmail: partnerEmail ?? '',
                  partnerName: partnerName,
                  partnerWantsEmail: partnerWantsEmail,
                  courtNumber: displayCourtNumber,
                  date: selectedDate,
                  hour: hour,
                  isCancellation: false,
                );
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
                    // Court Columns (leftmost = highest court, rightmost = 1)
                    for (int i = 0; i < numberOfCourts; i++)
                      Expanded(
                        child: Center(
                          child: Text('מגרש ${numberOfCourts - i}'),
                        ),
                      ),
                    // Time Column
                    const SizedBox(
                      width: 50, // Matches the width of "07:00"
                      child: Center(
                        child: Text('שעה'),
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
                        // Loop through each court and build button for each court in the row
                        for (int i = 0; i < numberOfCourts; i++)
                          Expanded(
                            child: Center(
                              child: buildCourtButton(i, hour),
                            ),
                          ),
                        // Time Column for Each Row
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Center(
                            child:
                                Text('${hour.toString().padLeft(2, '0')}:00'),
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
    String userName = widget.useFullNames
        ? (longUserName ?? '')
        : formatName(longUserName ?? '');
    String? longPartnerName = courtsReservations[courtIndex][hour]?['partner'];
    String partnerName = widget.useFullNames
        ? (longPartnerName ?? '')
        : formatName(longPartnerName ?? '');
    // Check if the partner field starts with "!" indicating a custom message
    bool isCustomMessage =
        longPartnerName != null && longPartnerName.startsWith('!');
    // Remove the leading "!" for display if it's a custom message
    String displayMessage = isCustomMessage
        ? longPartnerName.substring(1) // Remove "!" for custom messages
        : "$userName, $partnerName"; // Display as usual if it's a regular partner

    // Create a DateTime object for the current slot's time on the selected date
    DateTime now = DateTime.now();
    DateTime reservationDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      hour,
    );

    // For TV mode, ignore all time/date logic - only show reserved/available
    bool isPast = true;
    bool isTv = false;
    if (widget.useFullNames) {
      // TV mode: never show as past - only reserved (red) or available (green)
      isPast = false;
      // In TV view: show names instead of "תפוס", no clicks, no blue color
      isTv = true;
    } else {
      // Regular mode: use original logic - allow booking up to 1 hour before
      bool isWithin1Hour = reservationDateTime.difference(now).inMinutes < 60;
      isPast = reservationDateTime.isBefore(now) || isWithin1Hour;
    }

    bool isMine = longUserName == widget.myUserName ||
        longPartnerName == widget.myUserName;
    bool isManager = widget.myUserName == "אודי אש" ||
        widget.myUserName == "רני לפלר" ||
        widget.myUserName == "עפר בן ישי" ||
        widget.myUserName == "מיקי זילברשטיין" ||
        widget.myUserName == "מועדון כרמל";

    // Using null-aware operators for safety
    if ((holidayType != null && holidayType != "חג") &&
        (widget.selectedDate.weekday == DateTime.friday ||
            (holidayType != null && holidayType == "ערב חג")) &&
        (hour >= 7 && hour <= 18) &&
        courtIndex == 0) {
      // Coach line: on TV we want to show players' full names if reserved
      final coachLabel =
          (widget.useFullNames && isReserved) ? displayMessage : "מאמן";
      final Color coachBg = widget.useFullNames
          ? (isReserved
              ? Colors.red
              : Colors.red) // TV mode: always red for coach
          : (isReserved ? Colors.red : (isPast ? Colors.grey : Colors.green));

      if (widget.useFullNames) {
        return Container(
          decoration: BoxDecoration(
            color: coachBg,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text(
            coachLabel,
            style: const TextStyle(color: Colors.white),
          ),
        );
      }

      return ElevatedButton(
        onPressed: null, // Always non-interactive for coach line
        style: ElevatedButton.styleFrom(
          backgroundColor: coachBg,
          foregroundColor: Colors.white,
        ),
        child: Text(coachLabel),
      );
    } else {
      final String label = isReserved
          ? (isTv
              ? displayMessage
              : (isManager || isMine ? displayMessage : "תפוס"))
          : (isTv ? "פנוי" : (isPast ? "סגור" : "פנוי"));

      final Color bgColor = isReserved
          ? (isTv ? Colors.red : (isMine ? Colors.blue : Colors.red))
          : (isTv ? Colors.green : (isPast ? Colors.grey : Colors.green));

      if (isTv) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
        );
      }

      return ElevatedButton(
        onPressed: ((isPast && !isReserved && !isManager)
            ? null
            : () {
                if (isReserved && !isMine && !isManager) {
                  return;
                }
                _reserve(courtIndex + 1, hour);
              }),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
        ),
        child: Text(label),
      );
    }
  }
}
