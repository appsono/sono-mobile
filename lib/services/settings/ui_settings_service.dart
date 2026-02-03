import 'package:flutter/material.dart';
import 'base_settings_service.dart';

///manages UI-related settings (theme, accent color, experimental features)
class UISettingsService extends BaseSettingsService {
  static final UISettingsService instance = UISettingsService._internal();

  UISettingsService._internal();

  @override
  String get category => 'ui';

  //default values
  static const int _defaultThemeMode = 0; //ThemeMode.system
  static const int _defaultAccentColor = 0xFFE91E63; //pink
  static const bool _defaultExperimentalThemes = false;

  ///gets the current theme mode (0: system, 1: light, 2: dark)
  Future<ThemeMode> getThemeMode() async {
    final value = await getSetting<int>('theme_mode', _defaultThemeMode);
    return ThemeMode.values[value];
  }

  ///sets the theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    await setSetting<int>('theme_mode', mode.index);
  }

  ///gets the accent color
  Future<Color> getAccentColor() async {
    final value = await getSetting<int>('accent_color', _defaultAccentColor);
    return Color(value);
  }

  ///sets the accent color
  Future<void> setAccentColor(Color color) async {
    await setSetting<int>('accent_color', color.toARGB32());
  }

  ///gets whether experimental themes are enabled
  Future<bool> getExperimentalThemesEnabled() async {
    return await getSetting<bool>(
      'experimental_themes',
      _defaultExperimentalThemes,
    );
  }

  ///sets whether experimental themes are enabled
  Future<void> setExperimentalThemesEnabled(bool enabled) async {
    await setSetting<bool>('experimental_themes', enabled);
  }
}
