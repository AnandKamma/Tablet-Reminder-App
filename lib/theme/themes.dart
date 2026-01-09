import 'package:flutter/material.dart';

// ============================================================================
// LIGHT MODE THEME
// ============================================================================

ThemeData lightMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,

  colorScheme: ColorScheme.light(
    surface: Colors.grey.shade300,
    primary: Colors.grey.shade200,
    secondary: Colors.grey.shade400,
    inversePrimary: Colors.grey.shade800,
  ),

  // Scaffold background
  scaffoldBackgroundColor: Colors.grey.shade300,

  // AppBar theme
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.grey.shade300,
    foregroundColor: Colors.grey.shade800,
    elevation: 0,
    centerTitle: false,
  ),

  // Floating Action Button theme
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.grey.shade800,
    foregroundColor: Colors.white,
  ),
);

// ============================================================================
// DARK MODE THEME
// ============================================================================

ThemeData darkMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,

  colorScheme: ColorScheme.dark(
    surface: Colors.grey.shade900,
    primary: Colors.grey.shade800,
    secondary: Colors.grey.shade700,
    inversePrimary: Colors.grey.shade300,
  ),

  // Scaffold background
  scaffoldBackgroundColor: Colors.grey.shade900,

  // AppBar theme
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.grey.shade900,
    foregroundColor: Colors.grey.shade100,
    elevation: 0,
    centerTitle: false,
  ),

  // Floating Action Button theme
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.grey.shade700,
    foregroundColor: Colors.white,
  ),
);