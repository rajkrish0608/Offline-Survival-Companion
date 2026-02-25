import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryRed = Color(0xFFD32F2F);
  static const Color primaryDark = Color(0xFF121212);
  static const Color accentBlue = Color(0xFF1976D2);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningYellow = Color(0xFFFBC02D);
  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF424242);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFEEEEEE);

  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primaryRed,
      secondary: accentBlue,
      surface: surfaceLight,
      error: primaryRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
    ),
    scaffoldBackgroundColor: surfaceLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceLight,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 56,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: primaryRed.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryRed,
      foregroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    // cardTheme: CardTheme(
    //   color: Colors.white,
    //   elevation: 2,
    //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    // ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentBlue),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
    ),
  );

  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primaryRed,
      secondary: accentBlue,
      surface: surfaceDark,
      error: primaryRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textLight,
    ),
    scaffoldBackgroundColor: primaryDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceDark,
      foregroundColor: textLight,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 56,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceDark,
      indicatorColor: primaryRed.withValues(alpha: 0.3),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textLight,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryRed,
      foregroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    // cardTheme: CardTheme(
    //   color: surfaceDark,
    //   elevation: 2,
    //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    // ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: borderDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentBlue),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textLight,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textLight,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textLight,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: textLight),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
    ),
  );

  // Survival Theme (Extreme High Contrast, Minimal Color)
  static final ThemeData survivalTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      secondary: Colors.white,
      surface: Colors.black,
      error: Colors.red,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: Colors.black,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.white, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.black,
      indicatorColor: Colors.white,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Colors.white, fontSize: 18),
      bodyMedium: TextStyle(color: Colors.white70, fontSize: 16),
    ),
  );
}
