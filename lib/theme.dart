import 'package:flutter/material.dart';

class AppColors {
  static const primaryGreen = Color(0xFF0B8A4D);
  static const adminGold = Color(0xFFF5BD02);
  static const collectorPink = Color(0xFFC90274);
  static const residentPink = Color(0xFFE73895);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    // TextField theme
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: const TextStyle(color: Colors.black),
      hintStyle: const TextStyle(color: Colors.grey),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.green, width: 2.0),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
    ),

    // Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen, // fill color
        foregroundColor: Colors.white, // text color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // rounded edges
        ),
        textStyle: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 125, vertical: 20),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontSize: 40),
        foregroundColor: AppColors.primaryGreen, // text color
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryGreen, // text color
        side: const BorderSide(color: AppColors.primaryGreen, width: 2.0),
        // border
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    //  AppBar  theme
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryGreen,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      elevation: 2,
    ),

    // BottomNavigationBar  theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
