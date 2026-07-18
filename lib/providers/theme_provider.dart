import 'package:flutter/material.dart';
import '../config/theme.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;
  ThemeData get currentTheme => _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }
}
