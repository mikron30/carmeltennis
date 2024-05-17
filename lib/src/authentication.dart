// Copyright 2022 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, PhoneAuthProvider;

import 'widgets.dart';

class AuthFunc extends StatelessWidget {
  final bool loggedIn;
  final void Function() signOut;

  const AuthFunc({
    super.key,
    required this.loggedIn,
    required this.signOut,
  });

  @override
  Widget build(BuildContext context) {
    final String? userName = FirebaseAuth.instance.currentUser?.displayName;
    final String user1 = userName ?? '';
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 8),
          child: StyledButton(
              onPressed: () {
                !loggedIn ? context.push('/sign-in') : signOut();
              },
              child: !loggedIn ? const Text('התחבר') : const Text('התנתק')),
        ),
        Visibility(
          visible: loggedIn,
          child: Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 8),
            child: StyledButton(
              onPressed: () {
                context.push('/profile');
              },
              child: Row(
                children: [
                  Text('שלום $user1'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
