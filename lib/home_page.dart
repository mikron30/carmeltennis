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

class HomePage extends StatefulWidget {
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
  // Callback function to update the selected date
  void updateSelectedDate(DateTime newDate) {
    selectedDate = newDate;
    setState(() {
      selectedDate = newDate;
    });
  }

  void fetchAllUsers() async {
    try {
      // Query the 'users_2024' collection
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('users_2024').get();

      // Process each document
      List<String> fetchedUsers = querySnapshot.docs.map((doc) {
        String firstName =
            doc['שם פרטי']; // Assuming field names are exactly these
        String lastName = doc['שם משפחה'];
        return '$firstName $lastName'; // Concatenate to form a full name
      }).toList();

      // Update suggestionsList with the fetched and processed users
      setState(() {
        suggestionsList = fetchedUsers;
      });
    } catch (e) {
      print("Error fetching users: $e");
      // Handle the error accordingly
    }
  }

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    fetchAllUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('מועדון הכרמל'),
        centerTitle: true,
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
                Flexible(
                  child: DateSelector(onDateSelected: updateSelectedDate),
                ),
                Flexible(
                  child: Consumer<ApplicationState>(
                    builder: (context, appState, _) {
                      return AuthFunc(
                        loggedIn: appState.loggedIn,
                        signOut: () {
                          FirebaseAuth.instance.signOut();
                        },
                      );
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // CourtReservations widget
          Expanded(
            child: Consumer<ApplicationState>(
              builder: (context, appState, _) {
                return CourtReservations(
                  selectedDate: selectedDate ?? DateTime.now(),
                  selectedPartner: selectedPartner ?? '',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
