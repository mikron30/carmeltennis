// Copyright 2022 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, PhoneAuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'court_reservation.dart';
import 'date_selection.dart';
import 'src/authentication.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('מועדון הכרמל'),
        centerTitle: true,
      ),
      body: Column(
        // Correct usage of Column
        children: <Widget>[
          const DateSelector(), // DateSelector widget
          Consumer<ApplicationState>(
            builder: (context, appState, _) => AuthFunc(
                loggedIn: appState.loggedIn,
                signOut: () {
                  FirebaseAuth.instance.signOut();
                }),
          ),
          const SizedBox(height: 8),
          const CourtReservations(), // CourtReservations widget
        ],
      ),
    );
  }
}
