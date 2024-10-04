// Copyright 2022 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, PhoneAuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart'; // Import GoRouter

import 'app_state.dart';
import 'court_reservation.dart';
import 'date_selection.dart';
import 'src/authentication.dart';
import 'user_manager.dart';
import 'hoilday.dart';
import 'package:intl/intl.dart'; // Import the intl package for date formatting
import 'users_management.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<HomePage> {
  DateTime? selectedDate;
  String? selectedPartner;
  List<String> suggestionsList = []; // Assuming this is populated elsewhere
  TextEditingController _partnerController =
      TextEditingController(); // Add controller
  List<String> allUsers = []; // This should be fetched from your backend
  List<String> lastSelectedPartners =
      []; // This should be fetched from SharedPreferences or similar
  String? myUserName;

  bool isTodaySelected = true; // Default to "Today" being selected
  bool isTomorrowSelected = false; // Initially, tomorrow is not selected

  void updateSelectedDate(BuildContext context, DateTime newDate) {
    // Normalize both dates to midnight (00:00:00) for comparison
    DateTime today = DateTime.now();
    DateTime normalizedToday = DateTime(today.year, today.month, today.day);
    DateTime normalizedNewDate =
        DateTime(newDate.year, newDate.month, newDate.day);

    setState(() {
      selectedDate = newDate;

      if (normalizedNewDate.isAtSameMomentAs(normalizedToday)) {
        // "Today" selected
        isTodaySelected = true;
        isTomorrowSelected = false;
      } else {
        // "Tomorrow" selected
        isTodaySelected = false;
        isTomorrowSelected = true;
      }
    });
  }

  void fetchAllUsers() async {
    try {
      String? userEmail =
          FirebaseAuth.instance.currentUser?.email; // Now assigns user's email
      myUserName =
          await UserManager.instance.getUsernameByEmail(userEmail ?? '');

      // Query the 'users_2024' collection
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('users_2024').get();

      List<String> fetchedUsers = querySnapshot.docs.map((doc) {
        String firstName = doc['שם פרטי'];
        String lastName = doc['שם משפחה'];
        return '$firstName $lastName'.trim(); // Ensure no extra spaces
      }).toList();

      // If the user is not "מועדון כרמל", remove them from the list of partners
      if (myUserName != "מועדון כרמל") {
        fetchedUsers.removeWhere((userName) =>
            userName.trim().toLowerCase() == myUserName?.trim().toLowerCase() ||
            userName == "מועדון כרמל");
      }

      // Update the suggestions list with the filtered users
      setState(() {
        suggestionsList = fetchedUsers;
      });
    } catch (e) {
      // Handle the error accordingly
      print("Error fetching users: $e");
    }
  }

  Future<List<String>> fetchLastFivePartners(String userEmail) async {
    // Query the users_2024 collection for the document with the matching 'מייל' field
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users_2024')
        .where('מייל', isEqualTo: userEmail) // Query by the 'מייל' field
        .get();

    // If the document exists, fetch the 'lastFivePartners' field
    if (querySnapshot.docs.isNotEmpty) {
      DocumentSnapshot userDoc = querySnapshot.docs.first;
      if (userDoc.exists && userDoc.data() != null) {
        try {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          // Return the list of last 5 partners or an empty list if not found
          return List<String>.from(data['lastFivePartners'] ?? []);
        } catch (e) {
          // Return an empty list if 'lastFivePartners' field does not exist
          return [];
        }
      }
    }

    return [];
  }

  Future<void> fetchMyUserName() async {
    try {
      String? userEmail = FirebaseAuth.instance.currentUser?.email;
      if (userEmail != null) {
        myUserName = await UserManager.instance.getUsernameByEmail(userEmail);
      }
    } catch (e) {}
  }

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    final User? user = FirebaseAuth.instance.currentUser;
    // Fetch last 5 reserved partners when the widget is initialized
    if (user != null) {
      fetchLastFivePartners(user.email!).then((partners) {
        setState(() {
          lastSelectedPartners = partners; // Store the fetched partners
        });
      });
    }
    if (user != null) {
      fetchAllUsers(); // Ensure this is being calle
      // Fetch the user name before building the UI
      fetchMyUserName().then((_) {
        setState(() {
          // Rebuild the UI after the username is fetched
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final bool loggedIn = user != null;

    return Scaffold(
      // No AppBar as per your previous request
      body: loggedIn
          ? _buildMainContent() // Show main content if logged in
          : _buildLoginScreen(), // Show login prompt if not logged in

      // Show drawer only if logged in
      drawer: loggedIn ? _buildDrawer() : null,
    );
  }

// Function to build the main content (when user is logged in)
  Widget _buildMainContent() {
    // Get today's and tomorrow's dates in dd/MM/yyyy format
    DateTime today = DateTime.now();
    DateTime tomorrow = today.add(const Duration(days: 1));
    String formattedToday = DateFormat('dd').format(today);
    String formattedTomorrow = DateFormat('dd').format(tomorrow);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8.0), // Add some padding
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Use a Builder to get the correct context for opening the drawer
              Builder(
                builder: (BuildContext context) {
                  return IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      // Open the drawer
                      Scaffold.of(context).openDrawer();
                    },
                    color: myUserName == "מועדון כרמל" ? Colors.red : null,
                  );
                },
              ),
              const SizedBox(width: 8),
              // Conditional display based on the username
              if (myUserName == "מועדון כרמל") ...[
                // Show full date selector for "מועדון כרמל"
                Flexible(
                  flex: 1,
                  child: DateSelector(
                    onDateSelected: (DateTime date) {
                      updateSelectedDate(context, date);
                    },
                  ),
                ),
              ] else ...[
                Flexible(
                  flex: 1,
                  child: Row(
                    children: [
                      // Button for "היום" (Today)
                      Flexible(
                        child: ElevatedButton(
                          onPressed: () {
                            updateSelectedDate(context, today);
                          },
                          child: Text(
                            formattedToday,
                            style: TextStyle(
                              fontWeight: isTodaySelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Button for "מחר" (Tomorrow)
                      Flexible(
                        child: ElevatedButton(
                          onPressed: () {
                            updateSelectedDate(context, tomorrow);
                          },
                          child: Text(
                            formattedTomorrow,
                            style: TextStyle(
                              fontWeight: isTomorrowSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 8),
// Combined Partner Selection: Single Text Box (Autocomplete + Dropdown)
              Expanded(
                flex: 3,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    // Autocomplete text box
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        return suggestionsList.where((String option) {
                          return option
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        setState(() {
                          selectedPartner = selection;
                          _partnerController.text =
                              selection; // Update the text box with the selected partner
                        });
                      },
                      fieldViewBuilder: (BuildContext context,
                          TextEditingController fieldTextEditingController,
                          FocusNode fieldFocusNode,
                          VoidCallback onFieldSubmitted) {
                        _partnerController =
                            fieldTextEditingController; // Link the controller with the text field
                        return TextField(
                          controller: _partnerController,
                          focusNode: fieldFocusNode,
                          decoration: InputDecoration(
                            hintText: "הכנס שם שותף",
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.arrow_drop_down),
                              onPressed: () {
                                // Show a drop-down menu with the last 5 partners when the icon is clicked
                                showMenu<String>(
                                  context: context,
                                  position: RelativeRect.fromLTRB(0, 40, 0,
                                      0), // Positioning of the dropdown
                                  items: lastSelectedPartners
                                      .map((String partner) {
                                    return PopupMenuItem<String>(
                                      value: partner,
                                      child: Text(partner),
                                    );
                                  }).toList(),
                                ).then((String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      selectedPartner = newValue;
                                      _partnerController.text =
                                          newValue; // Update the text box with the selected value
                                    });
                                  }
                                });
                              },
                            ),
                          ),
                        );
                      },
                      optionsViewBuilder: (BuildContext context,
                          AutocompleteOnSelected<String> onSelected,
                          Iterable<String> options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            child: Container(
                              width: 300,
                              height: 200,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(10.0),
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final String option =
                                      options.elementAt(index);
                                  return GestureDetector(
                                    onTap: () {
                                      onSelected(option);
                                    },
                                    child: ListTile(
                                      title: Text(option),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Consumer<ApplicationState>(
            builder: (context, appState, _) {
              fetchMyUserName();
              return CourtReservations(
                selectedDate: selectedDate ?? DateTime.now(),
                selectedPartner: selectedPartner ?? '',
                myUserName: myUserName,
              );
            },
          ),
        ),
      ],
    );
  }

// Function to show the login screen if not logged in
  Widget _buildLoginScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Please log in to continue',
            style: TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 20),
          AuthFunc(
            // Use the AuthFunc widget for login handling
            loggedIn: false,
            signOut: () async {
              await FirebaseAuth.instance.signOut();
              setState(() {}); // Rebuild after logout
            },
          ),
        ],
      ),
    );
  }

// Function to build the drawer (if logged in)
  Widget _buildDrawer() {
    return Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
      // Removed the DrawerHeader with "שלום ..."

      // Auth function for signing out
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue),
          borderRadius: BorderRadius.circular(10),
          color: Colors.blue[50],
        ),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: ListTile(
          leading: const Icon(Icons.exit_to_app, color: Colors.blue),
          title: const Text('התנתק', style: TextStyle(color: Colors.blue)),
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            setState(() {});
            Navigator.of(context).pop();
          },
        ),
      ),

      // Container for "שנה סיסמא" (Change Password)
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue),
          borderRadius: BorderRadius.circular(10),
          color: Colors.blue[50],
        ),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: ListTile(
          leading: const Icon(Icons.lock, color: Colors.blue),
          title: const Text('שנה סיסמא', style: TextStyle(color: Colors.blue)),
          onTap: () {
            GoRouter.of(context).push('/change-password');
          },
        ),
      ),

      if (myUserName == "מועדון כרמל")
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue),
            borderRadius: BorderRadius.circular(10),
            color: Colors.blue[50],
          ),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: const Icon(Icons.lock, color: Colors.blue),
            title:
                const Text('ניהול חגים', style: TextStyle(color: Colors.blue)),
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => AddHolidayScreen()));
            },
          ),
        ),
      // New "Manage Users" option
      if (myUserName == "מועדון כרמל")
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue),
            borderRadius: BorderRadius.circular(10),
            color: Colors.blue[50],
          ),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: const Icon(Icons.group,
                color: Colors.blue), // Choose a suitable icon
            title: const Text('ניהול משתמשים',
                style:
                    TextStyle(color: Colors.blue)), // 'Manage Users' in Hebrew
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => ManageUsersScreen()),
              );
            },
          ),
        ),
    ]));
  }
}
