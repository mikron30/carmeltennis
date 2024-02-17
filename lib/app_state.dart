import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, PhoneAuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'court_reserved.dart';

class ApplicationState extends ChangeNotifier {
  ApplicationState();

  // Static method to get the current instance or create a new one if it doesn't exist
  static ApplicationState getInstance() {
    if (_instance == null) {
      _instance = ApplicationState();
    }
    return _instance!;
  }

  static ApplicationState? _instance; // Store the current instance

  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;
  String? userName = "";
  List<CourtReserved> _courtsReserved = [];
  List<CourtReserved> get courtsReserved => _courtsReserved;

  Future<void> init() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    FirebaseUIAuth.configureProviders([
      EmailAuthProvider(),
    ]);

    FirebaseAuth.instance.userChanges().listen((user) async {
      if (user != null) {
        _loggedIn = true;
        userName = FirebaseAuth.instance.currentUser?.displayName;
        QuerySnapshot querySnapshot =
            await FirebaseFirestore.instance.collection('reservations').get();
        _courtsReserved = querySnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return CourtReserved(
            user: data['userName'] as String,
            date: data['date'] as String,
            hour: data['hour'] as int,
          );
        }).toList();
      } else {
        userName = "";
        _loggedIn = false;
      }
      notifyListeners();
    });
  }
}
