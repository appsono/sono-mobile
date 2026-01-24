import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

//============ RESPONSIVE UTILITIES =============

/// Screen size categories for responsive scaling
enum ScreenSize {
  /// Small screens: < 360dp width (iPhone SE, compact Android devices)
  small,

  /// Standard screens: 360-600dp width (most modern phones)
  standard,
}

/// Responsive breakpoints for screen size detection
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  /// Small screen maximum width (360dp)
  static const double smallMax = 360.0;

  /// Standard screen maximum width (600dp)
  static const double standardMax = 600.0;

  /// Set screen size category based on current context
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < smallMax) return ScreenSize.small;
    return ScreenSize.standard;
  }
}

/// Responsive scaling utilities for dimensions, fonts, and spacing
class ResponsiveScale {
  ResponsiveScale._();

  /// Set scale factor based on screen size
  /// Returns 0.85 for small screens, 1.0 for standard screens
  static double getScaleFactor(BuildContext context) {
    final screenSize = ResponsiveBreakpoints.getScreenSize(context);
    return screenSize == ScreenSize.small ? 0.85 : 1.0;
  }

  /// Set scaled spacing value
  static double spacing(BuildContext context, double baseValue) {
    return baseValue * getScaleFactor(context);
  }

  /// Set scaled font size with optional min/max constraints
  static double fontSize(
    BuildContext context,
    double baseSize, {
    double? min,
    double? max,
  }) {
    final scaled = baseSize * getScaleFactor(context);
    if (min != null && scaled < min) return min;
    if (max != null && scaled > max) return max;
    return scaled;
  }

  /// Set scaled icon size with minimum constraint
  static double iconSize(
    BuildContext context,
    double baseSize, {
    double min = 24.0,
  }) {
    final scaled = baseSize * getScaleFactor(context);
    return scaled < min ? min : scaled;
  }

  /// Set scaled dimension (general purpose)
  static double dimension(BuildContext context, double baseDimension) {
    return baseDimension * getScaleFactor(context);
  }
}

/// Sono App Theme Constants
/// Centralized theme configuration
class AppTheme {
  AppTheme._();

  //============ BRAND COLORS =============

  /// Primary color
  static const Color brandPink = Color(0xFFFF4893);

  /// Brand pink as MaterialColor for theme
  static const MaterialColor brandPinkSwatch =
      MaterialColor(0xFFFF4893, <int, Color>{
        50: Color(0xFFFFE9F2),
        100: Color(0xFFFFD2E5),
        200: Color(0xFFFFB3D6),
        300: Color(0xFFFF94C7),
        400: Color(0xFFFF6EAD),
        500: Color(0xFFFF4893),
        600: Color(0xFFE64184),
        700: Color(0xFFCC3A75),
        800: Color(0xFFB33366),
        900: Color(0xFF992B57),
      });

  //============ BACKGROUND COLORS =============

  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color elevatedSurfaceDark = Color(0xFF252525);
  static const Color cardDark = Color(0xFF1A1A1A);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF5F5F5);
  static const Color elevatedSurfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFAFAFA);

  //============ TEXT COLORS =============

  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xB3FFFFFF); //0% white
  static const Color textTertiaryDark = Color(0x80FFFFFF); //0% white
  static const Color textDisabledDark = Color(0x4DFFFFFF); //0% white
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xB3000000); //0% black
  static const Color textTertiaryLight = Color(0x80000000); //0% black
  static const Color textDisabledLight = Color(0x4D000000); //0% black

  //============ SEMANTIC COLORS =============

  static const Color success = Color(0xFF4CAF50);
  static const Color successBackground = Color(0xFF1B5E20);
  static const Color error = Color(0xFFF44336);
  static const Color errorBackground = Color(0xFFB71C1C);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningBackground = Color(0xFFE65100);
  static const Color info = Color(0xFF2196F3);
  static const Color infoBackground = Color(0xFF0D47A1);

  //============ BORDER & DIVIDER COLORS =============

  static const Color borderDark = Color(0x1FFFFFFF); //2% white
  static const Color borderLight = Color(0x1F000000); //2% black
  static const Color dividerDark = Color(0x1FFFFFFF);
  static const Color dividerLight = Color(0x1F000000);

  //============ OVERLAY COLORS =============

  static const Color scrimDark = Color(0x99000000); //0% black
  static const Color scrimLight = Color(0x4D000000); //0% black
  static const Color modalBackground = Color(0xFF1E1E1E);
  static const Color bottomSheetBackground = Color(0xFF252525);

  //============ PLAYER COLORS =============

  static const Color playerGradientStart = Color(0xFF1A1A1A);
  static const Color playerGradientEnd = Color(0xFF0A0A0A);
  static const Color miniPlayerBackground = Color(0xFF1E1E1E);
  static const Color miniPlayerProgressFill = Color(0xFF474747);
  static const List<Color> miniPlayerProgress = [
    miniPlayerProgressFill,
    miniPlayerProgressFill,
  ];
  static const Color progressInactive = Color(0x4DFFFFFF);
  static const Color progressBuffer = Color(0x80FFFFFF);

  //============ SPACING =============

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacing = 16.0;
  static const double spacingLg = 20.0;
  static const double spacingXl = 24.0;
  static const double spacing2xl = 32.0;
  static const double spacing3xl = 48.0;

  //============ BORDER RADIUS =============

  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radius = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusCircle = 999.0;

  //============ ICON SIZES =============

  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double icon = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
  static const double iconHero = 64.0;

  //============ FONT FAMILY =============

  static const String fontFamily = 'VarelaRound';
  static const String fontFamilyHeading = 'Poppins';

  //============ FONT SIZES =============

  static const double fontCaption = 10.0;
  static const double fontSm = 12.0;
  static const double fontBody = 14.0;
  static const double font = 16.0;
  static const double fontSubtitle = 18.0;
  static const double fontTitle = 20.0;
  static const double fontHeading = 24.0;
  static const double fontDisplay = 32.0;

  //============ ANIMATION DURATIONS =============

  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animation = Duration(milliseconds: 250);
  static const Duration animationSlow = Duration(milliseconds: 400);

  //============ ELEVATION =============

  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  //============ SPECIFIC DIMENSIONS =============

  static const double miniPlayerHeight = 64.0;
  static const double bottomNavHeight = 56.0;
  static const double appBarHeight = 56.0;
  static const double listItemHeight = 72.0;
  static const double artworkSm = 56.0;
  static const double artworkMd = 64.0;
  static const double artwork = 72.0;
  static const double artworkLg = 120.0;
  static const double artworkXl = 200.0;
  static const double artworkHero = 280.0;

  //============ HELPER METHODS =============

  static Color textPrimary(Brightness brightness) =>
      brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(Brightness brightness) =>
      brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight;
  static Color background(Brightness brightness) =>
      brightness == Brightness.dark ? backgroundDark : backgroundLight;
  static Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? surfaceDark : surfaceLight;
  static Color border(Brightness brightness) =>
      brightness == Brightness.dark ? borderDark : borderLight;
  static Color card(Brightness brightness) =>
      brightness == Brightness.dark ? cardDark : cardLight;

  static BoxDecoration cardDecoration({
    Brightness brightness = Brightness.dark,
    double borderRadius = radius,
  }) {
    return BoxDecoration(
      color: card(brightness),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: border(brightness)),
    );
  }

  static BoxDecoration bottomSheetDecoration({
    Brightness brightness = Brightness.dark,
  }) {
    return BoxDecoration(
      color:
          brightness == Brightness.dark
              ? bottomSheetBackground
              : backgroundLight,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(radiusLg)),
    );
  }

  static BoxDecoration playerGradientDecoration({Color? accentColor}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor?.withValues(alpha: 0.3) ?? playerGradientStart,
          playerGradientEnd,
        ],
      ),
    );
  }

  //============ RESPONSIVE METHODS =============

  static double responsiveSpacing(BuildContext context, double baseSpacing) {
    return baseSpacing.w;
  }

  static double responsiveFontSize(
    BuildContext context,
    double baseFontSize, {
    double? min,
    double? max,
  }) {
    final scaled = baseFontSize.sp;
    if (min != null && scaled < min) return min;
    if (max != null && scaled > max) return max;
    return scaled;
  }

  static double responsiveIconSize(
    BuildContext context,
    double baseIconSize, {
    double min = 24.0,
  }) {
    final scaled = baseIconSize.w;
    return scaled < min ? min : scaled;
  }

  static double responsiveArtworkSize(
    BuildContext context,
    double baseSize, {
    double? minSize,
    double? maxSize,
  }) {
    if (baseSize >= artworkLg) {
      return 330.w;
    }

    return baseSize.w;
  }

  static double responsiveDimension(
    BuildContext context,
    double baseDimension,
  ) {
    return baseDimension.w;
  }

  static bool isSmallScreen(BuildContext context) {
    return ResponsiveBreakpoints.getScreenSize(context) == ScreenSize.small;
  }

  static ScreenSize getScreenSize(BuildContext context) {
    return ResponsiveBreakpoints.getScreenSize(context);
  }
}

extension ColorOpacity on Color {
  Color withOpacityValue(double opacity) => withValues(alpha: opacity);

  ///0% opacity
  Color get opacity10 => withValues(alpha: 0.1);

  ///0% opacity
  Color get opacity20 => withValues(alpha: 0.2);

  ///0% opacity
  Color get opacity30 => withValues(alpha: 0.3);

  ///0% opacity
  Color get opacity50 => withValues(alpha: 0.5);

  ///0% opacity
  Color get opacity70 => withValues(alpha: 0.7);

  ///0% opacity
  Color get opacity80 => withValues(alpha: 0.8);
}