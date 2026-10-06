import 'package:flutter/material.dart';

class AppTheme {
  // Vibrant Water Blue matching Shuddham Website
  static const Color primaryBlue = Color(0xFF0077EE);
  static const Color royalBlue = Color(0xFF0084FF);
  static const Color aquaCyan = Color(0xFF00B4D8);
  static const Color accentOrange = Color(0xFFFF7A00);
  static const Color deepNavy = Color(0xFF1E293B);
  static const Color textDark = Color(0xFF181F2C);
  static const Color textMuted = Color(0xFF64748B);
  static const Color waterBgLight = Color(0xFFF4FAFF);
  static const Color accentGreen = Color(0xFF10B981);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: aquaCyan,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2EEF8)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: textDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: royalBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme; // Primary brand experience is pristine white
}
