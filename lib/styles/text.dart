import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Legacy text styles
class AppStyles {
  AppStyles._();

  static const TextStyle sonoHeading = TextStyle(
    color: AppTheme.textPrimaryDark,
    fontSize: AppTheme.fontHeading,
    fontWeight: FontWeight.bold,
    fontFamily: AppTheme.fontFamily,
  );

  static const TextStyle sonoButtonText = TextStyle(
    fontFamily: AppTheme.fontFamily,
    color: AppTheme.textPrimaryDark,
    fontSize: AppTheme.fontTitle,
  );

  static const TextStyle sonoNavbarText = TextStyle(
    fontFamily: AppTheme.fontFamily,
    color: AppTheme.textPrimaryDark,
    fontSize: 6,
  );

  static const TextStyle sonoButtonTextSmaller = TextStyle(
    fontFamily: AppTheme.fontFamily,
    color: AppTheme.textPrimaryDark,
    fontSize: AppTheme.fontSm,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle sonoPlayerTitle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    color: AppTheme.textPrimaryDark,
    fontSize: AppTheme.fontBody,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle sonoPlayerArtist = TextStyle(
    fontFamily: AppTheme.fontFamily,
    color: AppTheme.textSecondaryDark,
    fontSize: AppTheme.fontBody,
    fontWeight: FontWeight.w500,
  );

  static ButtonStyle sonoButtonStyle = TextButton.styleFrom(
    padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingSm),
    backgroundColor: AppTheme.surfaceDark,
    side: BorderSide(
      color: AppTheme.borderDark,
      width: 2.0,
      style: BorderStyle.solid,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
    ),
  );

  static const TextStyle sonoButtonTextSmall = TextStyle(
    fontFamily: AppTheme.fontFamily,
    color: AppTheme.textPrimaryDark,
    fontSize: AppTheme.font,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle sonoListItemTitle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    color: AppTheme.textPrimaryDark,
    fontSize: AppTheme.font,
  );

  static const TextStyle sonoListItemSubtitle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    color: AppTheme.textSecondaryDark,
    fontSize: AppTheme.fontBody,
  );

  ///deprecated
  static const Color backgroundColor = AppTheme.backgroundDark;

  ///deprecated
  static const Color brandPink = AppTheme.brandPink;
}