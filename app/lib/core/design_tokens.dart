import 'package:flutter/material.dart';

class DesignTokens {
  // High contrast colors for stroke survivors
  static const Color primaryColor = Color(0xFF0052CC); // High contrast blue
  static const Color secondaryColor = Color(0xFFFF991F); // High contrast orange
  static const Color backgroundLight = Color(0xFFF4F5F7);
  static const Color backgroundDark = Color(0xFF172B4D);
  static const Color textPrimaryLight = Color(0xFF172B4D);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  
  static const Color successColor = Color(0xFF00875A);
  static const Color errorColor = Color(0xFFDE350B);

  // Accessible sizing
  static const double minTouchTargetSize = 48.0;
  
  static const EdgeInsets defaultPadding = EdgeInsets.all(16.0);
  static const EdgeInsets largePadding = EdgeInsets.all(24.0);
  
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 16.0;
  static const double borderRadiusLarge = 24.0;
  
  // Typography
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );
  
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 18, // Larger base font size for accessibility
    fontWeight: FontWeight.w400,
  );
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        background: backgroundLight,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onBackground: textPrimaryLight,
        onSurface: textPrimaryLight,
        error: errorColor,
      ),
      textTheme: const TextTheme(
        displayLarge: headingStyle,
        bodyLarge: bodyStyle,
        bodyMedium: TextStyle(fontSize: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
          padding: defaultPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMedium),
          ),
        ),
      ),
    );
  }
}
