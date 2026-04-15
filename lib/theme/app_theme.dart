import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary Colors
  static const Color primaryColor = Color(0xFF111111);
  static const Color primaryLightColor = Color(0xFF2B2B2B);
  static const Color primaryDarkColor = Color(0xFF4A4A4A);
  static const Color primaryColorDarkMode = Color(0xFFF5F5F5);

  // Secondary Colors
  static const Color secondaryColor = Color(0xFF2A2A2A);
  static const Color secondaryLightColor = Color(0xFF5A5A5A);
  static const Color secondaryDarkColor = Color(0xFFE6E6E6);

  // Neutral Colors
  static const Color backgroundColor = Color(0xFFF7F9FC);
  static const Color cardColor = Colors.white;
  static const Color dividerColor = Color(0xFFE1E6F0);
  static const Color surfaceColor =
      Color(0xFFF0F2F5); // Surface color for light theme

  // Text Colors
  static const Color textPrimaryColor = Color(0xFF424242);
  static const Color textSecondaryColor = Color(0xFF757575);
  static const Color textLightColor = Color(0xFF8D96AD);

  // Soft Text Colors (with alpha 0.85 for gentle appearance)
  static final Color textPrimaryColorSoft = Color(0xFF424242).withValues(alpha: 0.85);
  static final Color textSecondaryColorSoft = Color(0xFF757575).withValues(alpha: 0.85);

  // Status Colors
  static const Color successColor = Color(0xFF8FE3B0);
  static const Color errorColor = Color(0xFFE57373);
  static const Color warningColor = Color(0xFFFFCC7A);
  static const Color infoColor = Color(0xFF7EC8E3);

  // Dark Theme Colors
  static const Color darkBackgroundColor = Color.fromARGB(255, 24, 25, 26);
  static const Color darkCardColor = Color(0xFF242526);
  static const Color darkComponentColor = Color(0xFF252525);
  static const Color darkTextColor = Color(0xFFE4E6EB);
  static const Color darkBorderColor = Color(0xFF333333);

  // Dark Theme Soft Text Colors (with alpha 0.85 for gentle appearance)
  static final Color darkTextColorSoft = Color(0xFFE4E6EB).withValues(alpha: 0.85);

  // Helper method to get soft text color based on theme
  static Color getSoftTextColor(bool isDarkMode) {
    return isDarkMode ? darkTextColorSoft : textPrimaryColorSoft;
  }

  static Color onPrimaryFor(bool isDarkMode) {
    return isDarkMode ? Colors.black : Colors.white;
  }

  static Color onColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, primaryLightColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondaryColor, secondaryLightColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text Styles
  static TextStyle get headingLarge => GoogleFonts.poppins(
        fontSize: 28.0,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
        height: 1.4,
      );

  static TextStyle get headingMedium => GoogleFonts.poppins(
        fontSize: 24.0,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
        height: 1.4,
      );

  static TextStyle get headingSmall => GoogleFonts.poppins(
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
        color: textPrimaryColor,
        height: 1.5,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 18.0,
        fontWeight: FontWeight.w400,
        color: textPrimaryColor,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 16.0,
        fontWeight: FontWeight.w400,
        color: textPrimaryColor,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 14.0,
        fontWeight: FontWeight.w400,
        color: textPrimaryColor,
        height: 1.5,
      );

  static TextStyle get buttonText => GoogleFonts.inter(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.5,
      );

  static TextStyle get captionText => GoogleFonts.inter(
        fontSize: 12.0,
        fontWeight: FontWeight.w400,
        color: textSecondaryColor,
        height: 1.5,
      );

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    dividerColor: dividerColor,
    textTheme: TextTheme(
      displayLarge: headingLarge,
      displayMedium: headingMedium,
      displaySmall: headingSmall,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: buttonText,
      labelSmall: captionText,
    ),
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      background: backgroundColor,
      surface: surfaceColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: BorderSide(color: primaryColor, width: 1.5),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: headingSmall.copyWith(color: Colors.black),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.black,
      unselectedItemColor: textSecondaryColor,
      type: BottomNavigationBarType.fixed,
      elevation: 1,
      selectedLabelStyle: TextStyle(overflow: TextOverflow.visible),
      unselectedLabelStyle: TextStyle(overflow: TextOverflow.visible),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: errorColor, width: 1),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: bodyMedium.copyWith(color: textLightColor),
      labelStyle: bodyMedium.copyWith(color: textSecondaryColor),
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColorDarkMode,
    scaffoldBackgroundColor: darkBackgroundColor,
    cardColor: darkCardColor,
    dividerColor: Color(0xFF2D2D2D),
    textTheme: TextTheme(
      displayLarge: headingLarge.copyWith(color: Colors.white),
      displayMedium: headingMedium.copyWith(color: Colors.white),
      displaySmall: headingSmall.copyWith(color: Colors.white),
      bodyLarge: bodyLarge.copyWith(color: darkTextColor),
      bodyMedium: bodyMedium.copyWith(color: darkTextColor),
      bodySmall: bodySmall.copyWith(color: darkTextColor),
      labelLarge: buttonText.copyWith(color: Colors.black),
      labelSmall: captionText.copyWith(color: Color(0xFFAEB7CE)),
    ),
    colorScheme: ColorScheme.dark(
      primary: primaryColorDarkMode,
      secondary: secondaryDarkColor,
      error: errorColor,
      background: darkBackgroundColor,
      surface: darkComponentColor,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColorDarkMode,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryColorDarkMode,
        foregroundColor: Colors.black,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColorDarkMode,
        side: BorderSide(color: primaryColorDarkMode, width: 1.5),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColorDarkMode,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColorDarkMode,
      foregroundColor: Colors.black,
    ),
    cardTheme: CardThemeData(
      color: darkCardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkBackgroundColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: headingSmall.copyWith(color: Colors.white),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkBackgroundColor,
      selectedItemColor: Colors.white,
      unselectedItemColor: Color(0xFFAEB7CE),
      type: BottomNavigationBarType.fixed,
      elevation: 1,
      selectedLabelStyle: TextStyle(overflow: TextOverflow.visible),
      unselectedLabelStyle: TextStyle(overflow: TextOverflow.visible),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkComponentColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: darkBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: darkBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryColorDarkMode, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: errorColor, width: 1),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: bodyMedium.copyWith(color: Color(0xFF8D96AD)),
      labelStyle: bodyMedium.copyWith(color: Color(0xFFAEB7CE)),
    ),
  );
}
