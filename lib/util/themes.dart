import 'package:flutter/material.dart';

class AppThemes {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.green, // Your primary color for light mode
    primaryColor: Colors.green.shade700,
    hintColor: Colors.green.shade500,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      color: Colors.green,
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    cardColor: Colors.green.shade50, // Card background for light mode
    dialogBackgroundColor: Colors.white,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black87),
      headlineSmall: TextStyle(color: Colors.black),
      // Add more text styles as needed
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: Colors.green.shade700,
      textTheme: ButtonTextTheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white, backgroundColor: Colors.green.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.green.shade700),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.green.shade700,
      foregroundColor: Colors.white,
    ),
    // Define input decoration theme for text fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: Colors.green.shade700, width: 2.0),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade700),
      hintStyle: TextStyle(color: Colors.grey.shade500),
    ),
    iconTheme: IconThemeData(color: Colors.green.shade700),
    dividerColor: Colors.grey.shade300,
    listTileTheme: ListTileThemeData(
      iconColor: Colors.green.shade700,
      textColor: Colors.black87,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.teal, // A good primary color for dark mode
    primaryColor: Colors.teal.shade700,
    hintColor: Colors.teal.shade500,
    scaffoldBackgroundColor: Colors.grey.shade900, // Dark background
    appBarTheme: AppBarTheme(
      color: Colors.grey.shade800, // Darker app bar
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    cardColor: Colors.grey.shade800, // Card background for dark mode
    dialogBackgroundColor: Colors.grey.shade800,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white70),
      bodyMedium: TextStyle(color: Colors.white70),
      headlineSmall: TextStyle(color: Colors.white),
      // Add more text styles as needed
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: Colors.teal.shade700,
      textTheme: ButtonTextTheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white, backgroundColor: Colors.teal.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.teal.shade700),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.teal.shade700,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade700, // Darker fill for input fields
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: Colors.teal.shade700, width: 2.0),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade300),
      hintStyle: TextStyle(color: Colors.grey.shade400),
    ),
    iconTheme: IconThemeData(color: Colors.teal.shade700),
    dividerColor: Colors.grey.shade700,
    listTileTheme: ListTileThemeData(
      iconColor: Colors.teal.shade700,
      textColor: Colors.white70,
    ),
  );
}