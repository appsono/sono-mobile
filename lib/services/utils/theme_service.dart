import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService with ChangeNotifier {
  static const String _themeModeKey = 'theme_mode_v1';
  static const String _accentColorKey = 'accent_color_v1';
  static const String _customColorKey = 'custom_accent_color_v1';
  static const String _useCustomColorKey = 'use_custom_accent_color_v1';

  //cache for SharedPreferences
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  ThemeMode _themeMode = ThemeMode.dark;
  MaterialColor _accentColor = _defaultAccentColor;
  Color? _customAccentColor;
  bool _useCustomColor = false;

  //default accent color
  static const MaterialColor _defaultAccentColor =
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

  ThemeMode get themeMode => _themeMode;
  MaterialColor get accentColor => _accentColor;
  Color? get customAccentColor => _customAccentColor;
  bool get useCustomColor => _useCustomColor;
  bool get isInitialized => _isInitialized;

  ///get the currently active accent color (custom or predefined)
  Color get activeAccentColor =>
      _useCustomColor && _customAccentColor != null
          ? _customAccentColor!
          : _accentColor;

  final List<MaterialColor> availableColors = [
    _defaultAccentColor,
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.teal,
    Colors.cyan,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
  ];

  ///color names for UI display
  final Map<MaterialColor, String> colorNames = {
    _defaultAccentColor: 'Sono Pink',
    Colors.red: 'Red',
    Colors.orange: 'Orange',
    Colors.amber: 'Amber',
    Colors.green: 'Green',
    Colors.teal: 'Teal',
    Colors.cyan: 'Cyan',
    Colors.blue: 'Blue',
    Colors.indigo: 'Indigo',
    Colors.purple: 'Purple',
  };

  ThemeService() {
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    await loadPreferences();
  }

  Future<SharedPreferences> get prefs async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    try {
      _themeMode = mode;
      notifyListeners();

      final prefs = await this.prefs;
      await prefs.setInt(_themeModeKey, mode.index);

      debugPrint('ThemeService: Theme mode set to ${mode.name}');
    } catch (e) {
      debugPrint('ThemeService: Error setting theme mode: $e');
      rethrow;
    }
  }

  Future<void> setAccentColor(MaterialColor color) async {
    if (!availableColors.contains(color)) {
      debugPrint('ThemeService: Invalid accent color provided');
      return;
    }

    if (_accentColor == color && !_useCustomColor) return;

    try {
      _accentColor = color;
      _useCustomColor = false;
      notifyListeners();

      final prefs = await this.prefs;
      await Future.wait([
        prefs.setInt(_accentColorKey, availableColors.indexOf(color)),
        prefs.setBool(_useCustomColorKey, false),
      ]);

      debugPrint(
        'ThemeService: Accent color set to ${colorNames[color] ?? color.toString()}',
      );
    } catch (e) {
      debugPrint('ThemeService: Error setting accent color: $e');
      rethrow;
    }
  }

  Future<void> setCustomAccentColor(Color color) async {
    if (_customAccentColor == color && _useCustomColor) return;

    try {
      _customAccentColor = color;
      _useCustomColor = true;
      notifyListeners();

      final prefs = await this.prefs;
      final colorValue = color.toARGB32();

      await Future.wait([
        prefs.setInt(_customColorKey, colorValue),
        prefs.setBool(_useCustomColorKey, true),
      ]);

      debugPrint(
        'ThemeService: Custom accent color set to #${colorValue.toRadixString(16).padLeft(8, '0').toUpperCase()}',
      );
    } catch (e) {
      debugPrint('ThemeService: Error setting custom accent color: $e');
      rethrow;
    }
  }

  ///toggle between light and dark modes
  Future<void> toggleThemeMode() async {
    switch (_themeMode) {
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.light);
        break;
      case ThemeMode.system:
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        await setThemeMode(
          brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
        );
        break;
    }
  }

  ///set the next available accent color in the list
  Future<void> nextAccentColor() async {
    if (_useCustomColor) {
      await setAccentColor(availableColors.first);
      return;
    }

    final currentIndex = availableColors.indexOf(_accentColor);
    final nextIndex = (currentIndex + 1) % availableColors.length;
    await setAccentColor(availableColors[nextIndex]);
  }

  ///set the previous available accent color in the list
  Future<void> previousAccentColor() async {
    if (_useCustomColor) {
      await setAccentColor(availableColors.last);
      return;
    }

    final currentIndex = availableColors.indexOf(_accentColor);
    final previousIndex =
        currentIndex == 0 ? availableColors.length - 1 : currentIndex - 1;
    await setAccentColor(availableColors[previousIndex]);
  }

  Future<void> loadPreferences() async {
    try {
      final prefs = await this.prefs;

      //load ThemeMode
      final themeIndex = prefs.getInt(_themeModeKey);
      if (themeIndex != null &&
          themeIndex >= 0 &&
          themeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[themeIndex];
      } else {
        _themeMode = ThemeMode.dark;
      }

      //load custom color settings
      _useCustomColor = prefs.getBool(_useCustomColorKey) ?? false;

      if (_useCustomColor) {
        final customColorValue = prefs.getInt(_customColorKey);
        if (customColorValue != null) {
          _customAccentColor = Color(customColorValue);
        } else {
          //fallback if custom color is corrupted
          _useCustomColor = false;
        }
      }

      if (!_useCustomColor) {
        //load predefined accent color
        final colorIndex = prefs.getInt(_accentColorKey) ?? 0;
        final clampedIndex = colorIndex.clamp(0, availableColors.length - 1);
        _accentColor = availableColors[clampedIndex];
      }

      _isInitialized = true;
      notifyListeners();

      debugPrint(
        'ThemeService: Preferences loaded - Theme: ${_themeMode.name}, Custom Color: $_useCustomColor',
      );
    } catch (e) {
      debugPrint('ThemeService: Error loading preferences: $e');
      //set safe defaults on error
      _themeMode = ThemeMode.dark;
      _accentColor = _defaultAccentColor;
      _useCustomColor = false;
      _customAccentColor = null;
      _isInitialized = true;
      notifyListeners();
    }
  }

  ///reset theme settings to defaults
  Future<void> resetToDefaults() async {
    try {
      final prefs = await this.prefs;

      //remove theme-related keys
      await Future.wait([
        prefs.remove(_themeModeKey),
        prefs.remove(_accentColorKey),
        prefs.remove(_customColorKey),
        prefs.remove(_useCustomColorKey),
      ]);

      //reset to defaults
      _themeMode = ThemeMode.dark;
      _accentColor = _defaultAccentColor;
      _useCustomColor = false;
      _customAccentColor = null;

      notifyListeners();
      debugPrint('ThemeService: Reset to default settings');
    } catch (e) {
      debugPrint('ThemeService: Error resetting to defaults: $e');
      rethrow;
    }
  }

  Future<void> setRandomAccentColor() async {
    final randomIndex =
        DateTime.now().millisecondsSinceEpoch % availableColors.length;
    await setAccentColor(availableColors[randomIndex]);
  }

  bool isColorAvailable(MaterialColor color) {
    return availableColors.contains(color);
  }

  String getColorName(MaterialColor color) {
    return colorNames[color] ?? 'Unknown';
  }

  static MaterialColor createMaterialColor(Color color) {
    final int red = (color.r * 255.0).round() & 0xff;
    final int green = (color.g * 255.0).round() & 0xff;
    final int blue = (color.b * 255.0).round() & 0xff;
    final int colorValue = color.toARGB32();

    return MaterialColor(colorValue, <int, Color>{
      50: Color.fromRGBO(red, green, blue, 0.1),
      100: Color.fromRGBO(red, green, blue, 0.2),
      200: Color.fromRGBO(red, green, blue, 0.3),
      300: Color.fromRGBO(red, green, blue, 0.4),
      400: Color.fromRGBO(red, green, blue, 0.5),
      500: Color.fromRGBO(red, green, blue, 0.6),
      600: Color.fromRGBO(red, green, blue, 0.7),
      700: Color.fromRGBO(red, green, blue, 0.8),
      800: Color.fromRGBO(red, green, blue, 0.9),
      900: Color.fromRGBO(red, green, blue, 1.0),
    });
  }

  Future<Map<String, dynamic>> exportSettings() async {
    try {
      return {
        'theme_mode': _themeMode.name,
        'accent_color_index': availableColors.indexOf(_accentColor),
        'use_custom_color': _useCustomColor,
        'custom_color_value': _customAccentColor?.toARGB32(),
        'available_colors_count': availableColors.length,
      };
    } catch (e) {
      debugPrint('ThemeService: Error exporting settings: $e');
      return {};
    }
  }

  Future<void> importSettings(Map<String, dynamic> settings) async {
    try {
      if (settings.containsKey('theme_mode')) {
        final themeName = settings['theme_mode'] as String?;
        if (themeName != null) {
          final themeMode = ThemeMode.values.firstWhere(
            (mode) => mode.name == themeName,
            orElse: () => ThemeMode.dark,
          );
          await setThemeMode(themeMode);
        }
      }

      final useCustom = settings['use_custom_color'] as bool? ?? false;

      if (useCustom) {
        final colorValue = settings['custom_color_value'] as int?;
        if (colorValue != null) {
          await setCustomAccentColor(Color(colorValue));
        }
      } else {
        final colorIndex = settings['accent_color_index'] as int? ?? 0;
        final clampedIndex = colorIndex.clamp(0, availableColors.length - 1);
        await setAccentColor(availableColors[clampedIndex]);
      }

      debugPrint('ThemeService: Settings imported successfully');
    } catch (e) {
      debugPrint('ThemeService: Error importing settings: $e');
      rethrow;
    }
  }

  Map<String, dynamic> getThemeInfo() {
    return {
      'is_initialized': _isInitialized,
      'current_theme_mode': _themeMode.name,
      'uses_custom_color': _useCustomColor,
      'active_color':
          useCustomColor
              ? '#${activeAccentColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}'
              : getColorName(_accentColor),
      'available_colors_count': availableColors.length,
    };
  }
}