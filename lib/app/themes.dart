// lib/app/themes.dart
import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFE53935);
  static const primaryDark = Color(0xFFC62828);
  static const secondary = Color(0xFF1E1E2F);
  static const background = Color(0xFFF5F5F5);
  static const surface = Colors.white;
  static const text = Color(0xFF1A1A1A);
  static const textLight = Color(0xFF666666);
  static const success = Color(0xFF4CAF50);
  static const error = Color(0xFFF44336);
  static const warning = Color(0xFFFF9800);

  // ألوان البطاقات
  static const cardBlue = Color(0xFF2196F3);
  static const cardGreen = Color(0xFF4CAF50);
  static const cardOrange = Color(0xFFFF9800);
  static const cardPurple = Color(0xFF9C27B0);
}

class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Cairo',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
