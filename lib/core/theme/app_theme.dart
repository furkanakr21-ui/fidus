import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static const String fontFamily = 'Plus Jakarta Sans';

  static TextStyle _font({
    required Color color,
    required FontWeight fontWeight,
    double? fontSize,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      color: color,
      fontWeight: fontWeight,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
    );
  }

  static TextTheme _buildTextTheme({required bool isDark}) {
    final base = isDark ? AppColors.darkText : AppColors.lightText;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final textTheme = isDark
        ? Typography.material2021().white
        : Typography.material2021().black;
    return textTheme
        .apply(fontFamily: fontFamily)
        .copyWith(
          displayLarge: _font(
            color: base,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
          displayMedium: _font(
            color: base,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
          ),
          headlineLarge: _font(
            color: base,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          titleLarge: _font(
            color: base,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
          titleMedium: _font(
            color: base,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          bodyLarge: _font(
            color: base,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          bodyMedium: _font(
            color: secondary,
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
          labelLarge: _font(
            color: base,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          labelSmall: _font(
            color: secondary,
            fontWeight: FontWeight.w500,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        );
  }

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppColors.lightPrimary,
      onPrimary: Colors.white,
      secondary: AppColors.lightPrimary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightText,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    cardColor: AppColors.lightCard,
    textTheme: _buildTextTheme(isDark: false),
    cardTheme: CardThemeData(
      color: AppColors.lightCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _font(
        color: AppColors.lightText,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      iconTheme: const IconThemeData(color: AppColors.lightText),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
    ),
    dividerColor: AppColors.lightBorder,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.lightPrimary, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.lightTextSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.lightPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: _font(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.lightPrimary,
        side: const BorderSide(color: AppColors.lightPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: _font(
          color: AppColors.lightPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Color(0xFF001A14),
      secondary: AppColors.primary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    cardColor: AppColors.darkCard,
    textTheme: _buildTextTheme(isDark: true),
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _font(
        color: AppColors.darkText,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      iconTheme: const IconThemeData(color: AppColors.darkText),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
    ),
    dividerColor: AppColors.darkBorder,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF001A14),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: _font(
          color: const Color(0xFF001A14),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: _font(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
  );
}
