import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color plum = Color(0xFF743B83);
  static const Color berry = Color(0xFFB94D83);
  static const Color blush = Color(0xFFFFE7F1);
  static const Color lavender = Color(0xFFF2E8FA);
  static const Color ink = Color(0xFF342A37);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: plum,
      brightness: Brightness.light,
      primary: plum,
      secondary: berry,
      surface: const Color(0xFFFFFBFD),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFFFF8FB),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: lavender,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? plum : Colors.grey,
          ),
        ),
      ),
    );
  }
}
