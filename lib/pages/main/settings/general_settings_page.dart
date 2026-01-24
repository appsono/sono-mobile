import 'package:flutter/material.dart';
import 'package:sono/services/settings/ui_settings_service.dart';
import 'package:sono/services/settings/library_settings_service.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/widgets/global/bottom_sheet.dart';

/// general settings page (theme, appearance, library)
class GeneralSettingsPage extends StatefulWidget {
  const GeneralSettingsPage({super.key});

  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  final UISettingsService _uiSettings = UISettingsService.instance;
  final LibrarySettingsService _librarySettings =
      LibrarySettingsService.instance;

  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = const Color(0xFFE91E63);
  bool _coverRotation = true;
  bool _autoUpdate = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final themeMode = await _uiSettings.getThemeMode();
    final accentColor = await _uiSettings.getAccentColor();
    final coverRotation = await _librarySettings.getCoverRotationEnabled();
    final autoUpdate = await _librarySettings.getAutoUpdateEnabled();

    setState(() {
      _themeMode = themeMode;
      _accentColor = accentColor;
      _coverRotation = coverRotation;
      _autoUpdate = autoUpdate;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'General',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'VarelaRound',
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'APP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSwitchTile(
                    icon: Icons.update_rounded,
                    title: 'Auto Update',
                    subtitle: 'Automatically check for App Updates',
                    value: _autoUpdate,
                    onChanged: (value) async {
                      setState(() => _autoUpdate = value);
                      await _librarySettings.setAutoUpdateEnabled(value);
                    },
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'APPEARANCE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildNavigationTile(
                    icon: Icons.brightness_6_rounded,
                    title: 'Theme Mode (not working atm)',
                    subtitle: _getThemeModeLabel(_themeMode),
                    onTap: () => _showThemeModeDialog(),
                  ),
                  const SizedBox(height: 8),

                  _buildColorTile(
                    color: _accentColor,
                    title: 'Accent Color (not working atm)',
                    subtitle: '#${_accentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                    onTap: () => _showAccentColorDialog(),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'LIBRARY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSwitchTile(
                    icon: Icons.album_rounded,
                    title: 'Album Cover Rotation',
                    subtitle: 'Animate album covers in the player',
                    value: _coverRotation,
                    onChanged: (value) async {
                      setState(() => _coverRotation = value);
                      await _librarySettings.setCoverRotationEnabled(value);
                    },
                  ),
                ],
              ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
          width: 0.5,
        ),
      ),
      child: SwitchListTile(
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                value
                    ? AppTheme.brandPink.withAlpha((0.15 * 255).round())
                    : Colors.white.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            icon,
            color:
                value
                    ? AppTheme.brandPink
                    : Colors.white.withAlpha((0.7 * 255).round()),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'VarelaRound',
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withAlpha((0.7 * 255).round()),
            fontFamily: 'VarelaRound',
          ),
        ),
        value: value,
        activeTrackColor: AppTheme.brandPink.withAlpha((0.5 * 255).round()),
        activeThumbColor: AppTheme.brandPink,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.05 * 255).round()),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        fontSize: 14,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withAlpha((0.5 * 255).round()),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorTile({
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.05 * 255).round()),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(Icons.palette_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        fontSize: 14,
                        fontFamily: 'VarelaRound',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withAlpha((0.5 * 255).round()),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  Future<void> _showThemeModeDialog() async {
    final result = await showSonoBottomSheet<ThemeMode>(
      context: context,
      title: 'Theme Mode',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildThemeModeOption(
            ThemeMode.system,
            'System Default',
            Icons.brightness_auto_rounded,
          ),
          const Divider(height: 1),
          _buildThemeModeOption(ThemeMode.light, 'Light', Icons.light_mode_rounded),
          const Divider(height: 1),
          _buildThemeModeOption(ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
        ],
      ),
    );

    if (result != null) {
      setState(() => _themeMode = result);
      await _uiSettings.setThemeMode(result);
    }
  }

  Widget _buildThemeModeOption(ThemeMode mode, String label, IconData icon) {
    final isSelected = _themeMode == mode;
    return InkWell(
      onTap: () => Navigator.pop(context, mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  isSelected
                      ? AppTheme.brandPink
                      : Colors.white.withAlpha((0.7 * 255).round()),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.brandPink : Colors.white,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontFamily: 'VarelaRound',
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: AppTheme.brandPink, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _showAccentColorDialog() async {
    final List<Color> presetColors = [
      const Color(0xFFFF4893),
      const Color(0xFFF44336),
      const Color(0xFF9C27B0),
      const Color(0xFF673AB7),
      const Color(0xFF3F51B5),
      const Color(0xFF2196F3),
      const Color(0xFF03A9F4),
      const Color(0xFF00BCD4),
      const Color(0xFF009688),
      const Color(0xFF4CAF50),
      const Color(0xFF8BC34A),
      const Color(0xFFCDDC39),
      const Color(0xFFFFEB3B),
      const Color(0xFFFFC107),
      const Color(0xFFFF9800),
      const Color(0xFFFF5722),
    ];

    await showSonoBottomSheet(
      context: context,
      title: 'Accent Color',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              presetColors.map((color) {
                final isSelected = _accentColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () async {
                    setState(() => _accentColor = color);
                    await _uiSettings.setAccentColor(color);
                    if (mounted) Navigator.pop(context);
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child:
                        isSelected
                            ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 28,
                            )
                            : null,
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }
}