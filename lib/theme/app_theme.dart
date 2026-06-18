import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary Colors
  static const Color primaryColor = Color(0xFF26B5AD);
  static const Color primaryLightColor = Color(0xFF7ADDD6);
  static const Color primaryDarkColor = Color(0xFF168B82);
  static const Color primaryColorDarkMode = Color(0xFF66DED6);

  // Secondary Colors
  static const Color secondaryColor = Color(0xFF0F766E);
  static const Color secondaryLightColor = Color(0xFF4DD4CB);
  static const Color secondaryDarkColor = Color(0xFFBDEFEA);

  // Neutral Colors
  static const Color backgroundColor = Color(0xFFF7F8FA);
  static const Color cardColor = Colors.white;
  static const Color dividerColor = Color(0xFFE4EBEF);
  static const Color surfaceColor =
      Color(0xFFF0F5F6); // Surface color for light theme

  // Text Colors
  static const Color textPrimaryColor = Color(0xFF172033);
  static const Color textSecondaryColor = Color(0xFF737B8C);
  static const Color textLightColor = Color(0xFF9AA3B2);

  // Soft Text Colors (with alpha 0.85 for gentle appearance)
  static final Color textPrimaryColorSoft =
      Color(0xFF172033).withValues(alpha: 0.85);
  static final Color textSecondaryColorSoft =
      Color(0xFF737B8C).withValues(alpha: 0.85);

  // Status Colors
  static const Color successColor = Color(0xFF8FE3B0);
  static const Color errorColor = Color(0xFFE57373);
  static const Color warningColor = Color(0xFFFFCC7A);
  static const Color infoColor = Color(0xFF7EC8E3);

  // Dark Theme Colors
  static const Color darkAccentColor = primaryColorDarkMode;
  static const Color darkBackgroundColor = Color(0xFF09090A);
  static const Color darkCardColor = Color(0xFF1B1B1B);
  static const Color darkComponentColor = Color(0xFF242424);
  static const Color darkChatInputColor = Color(0xFF1D1D1D);
  static const Color darkUserMessageColor = Color(0xFF34383F);
  static const Color darkTextColor = Color(0xFFF8F8F8);
  static const Color darkMutedTextColor = Color(0xFF9B9B9F);
  static const Color darkDisabledTextColor = Color(0xFF68686D);
  static const Color darkBorderColor = Color(0xFF383838);

  // Dark Theme Soft Text Colors (with alpha 0.85 for gentle appearance)
  static final Color darkTextColorSoft = darkTextColor.withValues(alpha: 0.85);

  // Helper method to get soft text color based on theme
  static Color getSoftTextColor(bool isDarkMode) {
    return isDarkMode ? darkTextColorSoft : textPrimaryColorSoft;
  }

  static Color selectedPillBackgroundColor(bool isDarkMode) {
    return (isDarkMode ? primaryColorDarkMode : primaryColor)
        .withValues(alpha: isDarkMode ? 0.20 : 0.22);
  }

  static Color selectedPillTextColor(bool isDarkMode) {
    return isDarkMode ? primaryColorDarkMode : textPrimaryColor;
  }

  static Border standardCardBorder(bool isDarkMode) {
    return Border.all(
      color: isDarkMode
          ? darkBorderColor.withValues(alpha: 0.46)
          : dividerColor.withValues(alpha: 0.75),
      width: 1,
    );
  }

  static ShapeBorder standardCardShape(bool isDarkMode, {double radius = 16}) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: isDarkMode
            ? darkBorderColor.withValues(alpha: 0.46)
            : dividerColor.withValues(alpha: 0.75),
        width: 1,
      ),
    );
  }

  static List<BoxShadow> standardCardShadow(bool isDarkMode) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDarkMode ? 0.34 : 0.08),
        blurRadius: isDarkMode ? 16 : 8,
        offset: const Offset(0, 5),
      ),
    ];
  }

  static double standardCardElevation(bool isDarkMode) {
    return 6;
  }

  static Color standardCardShadowColor(bool isDarkMode) {
    return Colors.black.withValues(alpha: isDarkMode ? 0.40 : 0.08);
  }

  static Color profileCardColor(bool isDarkMode) {
    return isDarkMode ? darkCardColor : Colors.white;
  }

  static Border profileCardBorder(bool isDarkMode) {
    return Border.all(
      color: isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05),
    );
  }

  static List<BoxShadow> profileCardShadow(bool isDarkMode) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDarkMode ? 0.22 : 0.045),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ];
  }

  static BoxDecoration profileCardDecoration(
    bool isDarkMode, {
    double radius = 24,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? profileCardColor(isDarkMode),
      borderRadius: BorderRadius.circular(radius),
      border: profileCardBorder(isDarkMode),
      boxShadow: profileCardShadow(isDarkMode),
    );
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
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      surfaceTintColor: surfaceColor,
      shape: standardCardShape(false),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textPrimaryColor,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: headingSmall.copyWith(color: textPrimaryColor),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
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
    dividerColor: darkBorderColor,
    textTheme: TextTheme(
      displayLarge: headingLarge.copyWith(color: Colors.white),
      displayMedium: headingMedium.copyWith(color: Colors.white),
      displaySmall: headingSmall.copyWith(color: Colors.white),
      bodyLarge: bodyLarge.copyWith(color: darkTextColor),
      bodyMedium: bodyMedium.copyWith(color: darkTextColor),
      bodySmall: bodySmall.copyWith(color: darkTextColor),
      labelLarge: buttonText.copyWith(color: Colors.black),
      labelSmall: captionText.copyWith(color: darkMutedTextColor),
    ),
    colorScheme: ColorScheme.dark(
      primary: primaryColorDarkMode,
      secondary: secondaryDarkColor,
      tertiary: darkAccentColor,
      error: errorColor,
      surface: darkComponentColor,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: darkTextColor,
      outline: darkBorderColor,
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
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.40),
      surfaceTintColor: darkComponentColor,
      shape: standardCardShape(true),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
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
      selectedItemColor: primaryColorDarkMode,
      unselectedItemColor: darkDisabledTextColor,
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
      hintStyle: bodyMedium.copyWith(color: darkMutedTextColor),
      labelStyle: bodyMedium.copyWith(color: darkMutedTextColor),
    ),
  );
}
