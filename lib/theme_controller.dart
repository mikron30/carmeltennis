import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal();

  ThemeMode get mode => _mode;

  void setDark(bool isDark) {
    final newMode = isDark ? ThemeMode.dark : ThemeMode.light;
    if (newMode != _mode) {
      _mode = newMode;
      notifyListeners();
    }
  }
}
