import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, PhoneAuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'navigation_service.dart';

class ApplicationState extends ChangeNotifier {
  ApplicationState._privateConstructor();

  static final ApplicationState _instance =
      ApplicationState._privateConstructor();

  factory ApplicationState() {
    return _instance;
  }

  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;
  String? userName = "";

  Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseUIAuth.configureProviders([
      EmailAuthProvider(),
    ]);

    FirebaseAuth.instance.userChanges().listen((user) async {
      if (user != null) {
        try {
          _loggedIn = true;
          userName = FirebaseAuth.instance.currentUser?.displayName;
          // Check if it's the user's first login
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users_2024')
              .doc(user.uid)
              .get();
          bool isFirstLogin =
              (userDoc.data() as Map<String, dynamic>)['isFirstLogin'] ?? false;

          if (isFirstLogin) {
            final NavigationService navigationService = NavigationService();
            navigationService.navigateTo('change-password');
          }
        } catch (e) {}
      } else {
        userName = "";
        _loggedIn = false;
      }
      notifyListeners();
    });
  }
}
