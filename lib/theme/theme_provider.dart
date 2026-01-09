import 'package:flutter/material.dart';
import 'package:tablet_reminder/theme/themes.dart';

class ThemeProvider extends ChangeNotifier {
  // Default to system theme
  ThemeMode _themeMode = ThemeMode.system;

  // Getter for theme mode
  ThemeMode get themeMode => _themeMode;

  // Check if currently in dark mode (considering system setting)
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      // Get system brightness
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  // Light theme getter
  ThemeData get lightTheme => lightMode;

  // Dark theme getter
  ThemeData get darkTheme => darkMode;

  // Get current theme data (for backwards compatibility)
  ThemeData get themeData => isDarkMode ? darkMode : lightMode;

  // Method to toggle: Light → Dark → System (cycle)
  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  // Optional: Set specific theme mode
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}