import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  primaryColor: const Color(0xFF3B82F6), // Primary (синий)
  scaffoldBackgroundColor: const Color(0xFFF9FAFB), // Background
  cardColor: Colors.white, // Surface
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF3B82F6), // основной синий
    secondary: Color(0xFF10B981), // зелёный успеха
    background: Color(0xFFF9FAFB),
    surface: Colors.white,
    error: Color(0xFFEF4444), // красный ошибки
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF111827)), // основной текст
    bodyMedium: TextStyle(color: Color(0xFF6B7280)), // вторичный текст
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF111827),
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF3B82F6), // Primary
      foregroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF3B82F6),
  scaffoldBackgroundColor: const Color(0xFF111827),
  cardColor: const Color(0xFF1F2937),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF3B82F6),
    secondary: Color(0xFF10B981),
    background: Color(0xFF111827),
    surface: Color(0xFF1F2937),
    error: Color(0xFFEF4444),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Color(0xFF9CA3AF)),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1F2937),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF3B82F6),
      foregroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  ),
);

