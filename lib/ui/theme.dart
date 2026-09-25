import 'package:flutter/material.dart';

abstract final class WinTheme {
  static const ink = Color(0xFF21094F);
  static const purple = Color(0xFF773CFF);
  static const muted = Color(0xFF796A9F);
  static const lavender = Color(0xFFF2EBFF);
  static const mint = Color(0xFFE3FAF2);
  static const peach = Color(0xFFFFF2E2);
  static const green = Color(0xFF079C8B);
  static ThemeData get data => ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: const Color(0xFFFEFDFF),
    colorScheme: ColorScheme.fromSeed(
      seedColor: purple,
      primary: purple,
      surface: const Color(0xFFFEFDFF),
      onSurface: ink,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 37,
        height: 1.08,
        fontWeight: FontWeight.w900,
        color: ink,
        letterSpacing: -1.3,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.16,
        fontWeight: FontWeight.w900,
        color: ink,
        letterSpacing: -.8,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: ink,
        letterSpacing: -.5,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      bodyLarge: TextStyle(fontSize: 17, height: 1.45, color: ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: purple,
      elevation: 0,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
    ),
    dividerColor: lavender,
  );
}
