import 'package:flutter/material.dart';

class CanaryTheme {
  static const background = Color(0xFFFFFCF3);
  static const canvas = Color(0xFFFFF7E6);
  static const panel = Color(0xDFFFFAF0);
  static const panelStrong = Color(0xFFF7E9C9);
  static const border = Color(0x33A77A1D);
  static const text = Color(0xFF2A2416);
  static const muted = Color(0xFF827354);
  static const faint = Color(0xFFB3A582);
  static const canary = Color(0xFFFFD447);
  static const amber = Color(0xFFEAA51F);
  static const honey = Color(0xFFFFE7A3);
  static const leaf = Color(0xFF9BAF55);
  static const coral = Color(0xFFE77B5C);
  static const teal = Color(0xFF4DAFA3);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'DM Sans',
      colorScheme: ColorScheme.fromSeed(
        seedColor: canary,
        brightness: Brightness.light,
        surface: background,
      ),
      scaffoldBackgroundColor: background,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: text),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: text,
          foregroundColor: background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: .72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: amber, width: 1.4),
        ),
      ),
    );
  }
}
