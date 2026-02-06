import 'package:flutter/material.dart';
import 'package:sono/styles/app_theme.dart';

/// Light theme configuration
ThemeData buildLightTheme(MaterialColor primaryColor) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    primarySwatch: primaryColor,
    scaffoldBackgroundColor: AppTheme.backgroundLight,
    fontFamily: AppTheme.fontFamily,

    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: primaryColor,
      surface: AppTheme.surfaceLight,
      error: AppTheme.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppTheme.textPrimaryLight,
      onError: Colors.white,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppTheme.backgroundLight,
      foregroundColor: AppTheme.textPrimaryLight,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppTheme.textPrimaryLight),
      titleTextStyle: TextStyle(
        color: AppTheme.textPrimaryLight,
        fontSize: AppTheme.fontSubtitle,
        fontWeight: FontWeight.w600,
        fontFamily: AppTheme.fontFamilyHeading,
      ),
    ),

    cardTheme: CardThemeData(
      color: AppTheme.cardLight,
      elevation: AppTheme.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
    ),

    listTileTheme: ListTileThemeData(
      tileColor: AppTheme.cardLight,
      textColor: AppTheme.textPrimaryLight,
      iconColor: AppTheme.textPrimaryLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    dividerTheme: DividerThemeData(
      color: AppTheme.dividerLight,
      thickness: 1,
      space: 1,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppTheme.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: BorderSide(color: AppTheme.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: BorderSide(color: AppTheme.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      labelStyle: TextStyle(color: AppTheme.textSecondaryLight),
      hintStyle: TextStyle(color: AppTheme.textTertiaryLight),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return AppTheme.textTertiaryLight;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor.withAlpha((0.5 * 255).round());
        }
        return AppTheme.textDisabledLight;
      }),
    ),

    iconTheme: IconThemeData(
      color: AppTheme.textPrimaryLight,
      size: AppTheme.icon,
    ),

    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: AppTheme.fontDisplay,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryLight,
        fontFamily: AppTheme.fontFamilyHeading,
      ),
      displayMedium: TextStyle(
        fontSize: AppTheme.fontHeading,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryLight,
        fontFamily: AppTheme.fontFamilyHeading,
      ),
      displaySmall: TextStyle(
        fontSize: AppTheme.fontTitle,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimaryLight,
        fontFamily: AppTheme.fontFamilyHeading,
      ),
      headlineLarge: TextStyle(
        fontSize: AppTheme.fontHeading,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryLight,
        fontFamily: AppTheme.fontFamilyHeading,
      ),
      headlineMedium: TextStyle(
        fontSize: AppTheme.fontTitle,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimaryLight,
        fontFamily: AppTheme.fontFamilyHeading,
      ),
      titleLarge: TextStyle(
        fontSize: AppTheme.fontTitle,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimaryLight,
        fontFamily: AppTheme.fontFamily,
      ),
      titleMedium: TextStyle(
        fontSize: AppTheme.font,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimaryLight,
        fontFamily: AppTheme.fontFamily,
      ),
      titleSmall: TextStyle(
        fontSize: AppTheme.fontBody,
        fontWeight: FontWeight.w500,
        color: AppTheme.textSecondaryLight,
        fontFamily: AppTheme.fontFamily,
      ),
      bodyLarge: TextStyle(
        fontSize: AppTheme.font,
        color: AppTheme.textPrimaryLight,
        fontFamily: AppTheme.fontFamily,
      ),
      bodyMedium: TextStyle(
        fontSize: AppTheme.fontBody,
        color: AppTheme.textPrimaryLight,
        fontFamily: AppTheme.fontFamily,
      ),
      bodySmall: TextStyle(
        fontSize: AppTheme.fontSm,
        color: AppTheme.textSecondaryLight,
        fontFamily: AppTheme.fontFamily,
      ),
      labelLarge: TextStyle(
        fontSize: AppTheme.font,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimaryLight,
        fontFamily: AppTheme.fontFamily,
      ),
      labelMedium: TextStyle(
        fontSize: AppTheme.fontBody,
        fontWeight: FontWeight.w500,
        color: AppTheme.textSecondaryLight,
        fontFamily: AppTheme.fontFamily,
      ),
      labelSmall: TextStyle(
        fontSize: AppTheme.fontSm,
        fontWeight: FontWeight.w500,
        color: AppTheme.textTertiaryLight,
        fontFamily: AppTheme.fontFamily,
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppTheme.backgroundLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      elevation: AppTheme.elevationHigh,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppTheme.backgroundLight,
      elevation: AppTheme.elevationHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      titleTextStyle: TextStyle(
        fontSize: AppTheme.fontTitle,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryLight,
        fontFamily: AppTheme.fontFamilyHeading,
      ),
      contentTextStyle: TextStyle(
        fontSize: AppTheme.fontBody,
        color: AppTheme.textSecondaryLight,
        fontFamily: AppTheme.fontFamily,
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppTheme.elevatedSurfaceLight,
      contentTextStyle: TextStyle(
        color: AppTheme.textPrimaryLight,
        fontFamily: AppTheme.fontFamily,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: AppTheme.elevationLow,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        textStyle: TextStyle(
          fontSize: AppTheme.font,
          fontWeight: FontWeight.w600,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        textStyle: TextStyle(
          fontSize: AppTheme.font,
          fontWeight: FontWeight.w500,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: AppTheme.elevationMedium,
    ),
  );
}
