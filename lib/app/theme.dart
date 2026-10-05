import 'package:flutter/material.dart';

const brandGreen = Color(0xFF16A34A);
const brandPurple = Color(0xFF7C3AED);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandGreen,
    primary: brandGreen,
    secondary: brandPurple,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF7F8F7),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}
