import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, PhoneAuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

class ApplicationState extends ChangeNotifier {
  ApplicationState() {
    init();
  }
  static ApplicationState? _instance; // Store the current instance

  // Static method to get the current instance
  static ApplicationState getInstance() {
    if (_instance == null) {
      _instance = ApplicationState();
    }
    return _instance!;
  }

  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;
  String? userName = "";
  Future<void> init() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    FirebaseUIAuth.configureProviders([
      EmailAuthProvider(),
    ]);

    FirebaseAuth.instance.userChanges().listen((user) {
      if (user != null) {
        _loggedIn = true;
        userName = FirebaseAuth.instance.currentUser?.displayName;
      } else {
        userName = "";
        _loggedIn = false;
      }
      notifyListeners();
    });
  }
}
