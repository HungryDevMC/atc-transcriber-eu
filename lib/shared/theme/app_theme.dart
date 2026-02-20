import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _primaryColor = Color(0xFF1A237E); // Dark blue - aviation style
  static const _secondaryColor = Color(0xFF00BCD4); // Cyan accent
  static const _errorColor = Color(0xFFD32F2F);
  static const _warningColor = Color(0xFFFFA000);
  static const _successColor = Color(0xFF388E3C);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: _secondaryColor,
        secondary: _secondaryColor,
        surface: const Color(0xFF121212),
        error: _errorColor,
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _secondaryColor,
        foregroundColor: Colors.black,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _secondaryColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _secondaryColor),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A2A),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: _primaryColor,
        secondary: _secondaryColor,
        surface: Colors.white,
        error: _errorColor,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryColor),
        ),
      ),
    );
  }

  // Text styles for transcription display
  static const TextStyle transcriptionText = TextStyle(
    fontSize: 18,
    height: 1.5,
    fontFamily: 'monospace',
  );

  static const TextStyle callsignHighlight = TextStyle(
    fontSize: 18,
    height: 1.5,
    fontFamily: 'monospace',
    fontWeight: FontWeight.bold,
    color: _secondaryColor,
  );

  static const TextStyle timestampText = TextStyle(
    fontSize: 12,
    color: Colors.grey,
  );

  static const Color recordingColor = Color(0xFFD32F2F);
  static const Color connectedColor = _successColor;
  static const Color disconnectedColor = _warningColor;
}
