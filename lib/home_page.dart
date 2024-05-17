// Copyright 2022 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, PhoneAuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'court_reservation.dart';
import 'date_selection.dart';
import 'src/authentication.dart';
import 'user_manager.dart';
import 'hoilday.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<HomePage> {
  DateTime? selectedDate;
  String? selectedPartner;
  List<String> suggestionsList = []; // Assuming this is populated elsewhere

  List<String> allUsers = []; // This should be fetched from your backend
  List<String> lastSelectedUsers =
      []; // This should be fetched from SharedPreferences or similar
  String? myUserName;

  void _showInvalidDateMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invalid Date'),
        content: const Text('ניתן להזמין רק להיום ולמחר'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('אישור'),
          ),
        ],
      ),
    );
  }

  // Callback function to update the selected date
  void updateSelectedDate(BuildContext context, DateTime newDate) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime tomorrow = DateTime(now.year, now.month, now.day + 1);

    if (newDate.isAtSameMomentAs(today) || newDate.isAtSameMomentAs(tomorrow)) {
      setState(() {
        selectedDate = newDate;
      });
    } else {
      setState(() {
        selectedDate = today;
      });
      _showInvalidDateMessage(context);
    }
  }

  void fetchMyUserName() async {
    try {
      String? userEmail =
          FirebaseAuth.instance.currentUser?.email; // Now assigns user's email
      myUserName =
          await UserManager.instance.getUsernameByEmail(userEmail ?? '');
    } catch (e) {
      // Handle the error accordingly
    }
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
        String firstName =
            doc['שם פרטי']; // Assuming field names are exactly these
        String lastName = doc['שם משפחה'];
        return '$firstName $lastName'; // Concatenate to form a full name
      }).toList();
      if (myUserName != "מועדון כרמל") {
        fetchedUsers.removeWhere(
            (userName) => userName == myUserName || userName == "מועדון כרמל");
      }

      // Update suggestionsList with the fetched and processed users
      setState(() {
        suggestionsList = fetchedUsers;
      });
    } catch (e) {
      // Handle the error accordingly
    }
  }

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // User is logged in
      fetchAllUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final bool loggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(''), // Keep empty or use a different title
        centerTitle: true,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu), // Hamburger icon for the drawer
              onPressed: () {
                Scaffold.of(context).openEndDrawer(); // Open the drawer
              },
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            );
          },
        ),
      ),
      body: Column(
        children: <Widget>[
          // Expanded Row to contain DateSelector, AuthFunc, and Autocomplete
          Expanded(
            flex:
                0, // Set flex to 0 to prevent the row from expanding vertically
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user != null) // User is logged in
                  Flexible(
                    child: DateSelector(
                      onDateSelected: (DateTime date) {
                        updateSelectedDate(context, date);
                      },
                    ),
                  ),
                Flexible(
                  child: Autocomplete<String>(
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
                        selectedPartner =
                            selection; // Update selectedPartner with the selected name
                      });
                      // Update last selected users list here
                    },
                    fieldViewBuilder: (
                      BuildContext context,
                      TextEditingController fieldTextEditingController,
                      FocusNode fieldFocusNode,
                      VoidCallback onFieldSubmitted,
                    ) {
                      return TextField(
                        controller: fieldTextEditingController,
                        focusNode: fieldFocusNode,
                        decoration: InputDecoration(
                          hintText: "הכנס שם שותף", // Placeholder text
                          // Additional decoration to match your app's style
                        ),
                        // Add any additional styling or functionality to the TextField here
                      );
                    },
                    optionsViewBuilder: (
                      BuildContext context,
                      AutocompleteOnSelected<String> onSelected,
                      Iterable<String> options,
                    ) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          child: Container(
                            width: 300, // Adjust the width as needed
                            height: 200, // Adjust the height as needed
                            child: ListView.builder(
                              padding: EdgeInsets.all(10.0),
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // CourtReservations widget
          if (user != null) // User is logged in
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
      ),
      // Assuming the use of a Stateful Widget and proper setup for AuthFunc and other used widgets
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                  loggedIn
                      ? 'שלום ${FirebaseAuth.instance.currentUser?.displayName ?? "אורח"}'
                      : 'אורח',
                  style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              title: AuthFunc(
                loggedIn: loggedIn,
                signOut: () async {
                  await FirebaseAuth.instance.signOut();
                  setState(() {});
                  Navigator.of(context).pop(); // Close the drawer
                  // Optionally, navigate to a different page after logging out
                },
              ),
            ),
            if (myUserName == "מועדון כרמל")
              ListTile(
                title: const Text('ניהול חגים'),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => AddHolidayScreen()));
                },
              ),
            // Additional drawer items...
          ],
        ),
      ),
    );
  }
}
