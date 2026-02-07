import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sono/styles/app_theme.dart';
import 'package:sono/services/settings/developer_settings_service.dart';
import 'package:sono/services/api/api_service.dart';
import 'package:sono/services/api/lastfm_service.dart';
import 'package:sono/services/api/lyrics_service.dart';
import 'package:sono/services/utils/artwork_cache_service.dart';
import 'package:sono/services/utils/crashlytics_service.dart';
import 'package:sono/services/utils/firebase_availability.dart';
import 'package:sono/services/utils/preferences_service.dart';
import 'package:sono/data/database/database_helper.dart';
import 'package:sono/widgets/library/artist_artwork_widget.dart';

/// developer settings page - analytics, API mode, cache, database
class DeveloperSettingsPage extends StatefulWidget {
  const DeveloperSettingsPage({super.key});

  @override
  State<DeveloperSettingsPage> createState() => _DeveloperSettingsPageState();
}

class _DeveloperSettingsPageState extends State<DeveloperSettingsPage> {
  final DeveloperSettingsService _developerSettings =
      DeveloperSettingsService.instance;
  final ApiService _apiService = ApiService();

  bool _useProductionApi = true;
  bool _crashlyticsEnabled = true;
  bool _isLoading = true;
  Map<String, int>? _dbStats;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prodApi = await _apiService.isProductionMode();
    final crashlytics = CrashlyticsService.instance.isEnabled;

    setState(() {
      _useProductionApi = prodApi;
      _crashlyticsEnabled = crashlytics;
      _isLoading = false;
    });
  }

  Future<void> _loadDatabaseStats() async {
    try {
      final stats = await SonoDatabaseHelper.instance.getDatabaseStats();
      setState(() => _dbStats = stats);
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          message: 'Error loading database stats: $e',
          isError: true,
        );
      }
    }
  }

  void _showSnackBar({required String message, required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'VarelaRound'),
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Developer',
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
                    'API & SERVICES',
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
                    icon: Icons.cloud_rounded,
                    title: 'Production API Mode',
                    subtitle:
                        _useProductionApi
                            ? 'Using production Sono API'
                            : 'Using development Sono API',
                    value: _useProductionApi,
                    onChanged: (value) async {
                      setState(() => _useProductionApi = value);
                      await _apiService.setApiMode(useProduction: value);

                      if (mounted) {
                        _showSnackBar(
                          message:
                              'API mode changed to ${value ? "production" : "development"}. Restart may be required.',
                          isError: false,
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'PRIVACY',
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
                    icon: Icons.bug_report_outlined,
                    title: 'Crash Reporting',
                    subtitle:
                        _crashlyticsEnabled
                            ? 'Send crash reports to help fix bugs'
                            : 'Crash reports disabled',
                    value: _crashlyticsEnabled,
                    onChanged: (value) async {
                      setState(() => _crashlyticsEnabled = value);
                      await CrashlyticsService.instance.setEnabled(value);

                      if (mounted) {
                        _showSnackBar(
                          message:
                              value
                                  ? 'Crash reporting enabled. Restart app for full effect.'
                                  : 'Crash reporting disabled. Restart app for full effect.',
                          isError: false,
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'CACHE MANAGEMENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildActionTile(
                    icon: Icons.cleaning_services_rounded,
                    iconColor: AppTheme.warning,
                    title: 'Clear Last.fm Cache',
                    subtitle: 'Remove cached Last.fm data',
                    trailing: Icon(
                      Icons.delete_outline,
                      color: Colors.white.withAlpha((0.5 * 255).round()),
                      size: 20,
                    ),
                    onTap: () => _confirmClearLastfmCache(),
                  ),
                  const SizedBox(height: 8),

                  _buildActionTile(
                    icon: Icons.delete_sweep_rounded,
                    iconColor: AppTheme.warning,
                    title: 'Clear All Cache',
                    subtitle: 'Remove all cached data including artwork',
                    trailing: Icon(
                      Icons.delete_outline,
                      color: Colors.white.withAlpha((0.5 * 255).round()),
                      size: 20,
                    ),
                    onTap: () => _confirmClearAllCache(),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'DEBUGGING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildActionTile(
                    icon: Icons.bug_report_rounded,
                    iconColor: AppTheme.error,
                    title: 'Test Crash',
                    subtitle: 'Trigger a test crash for Crashlytics',
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withAlpha((0.5 * 255).round()),
                      size: 20,
                    ),
                    onTap: () => _confirmTestCrash(),
                  ),
                  const SizedBox(height: 8),

                  _buildActionTile(
                    icon: Icons.restart_alt_rounded,
                    iconColor: AppTheme.info,
                    title: 'Reset Setup Flow',
                    subtitle: 'Show the setup wizard on next app launch',
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withAlpha((0.5 * 255).round()),
                      size: 20,
                    ),
                    onTap: () => _resetSetupFlow(),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'DATABASE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: 'VarelaRound',
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildActionTile(
                    icon: Icons.storage_rounded,
                    iconColor: AppTheme.info,
                    title: 'Database Statistics',
                    subtitle:
                        _dbStats == null
                            ? 'Tap to load statistics'
                            : _formatDbStats(_dbStats!),
                    trailing: Icon(
                      Icons.refresh_rounded,
                      color: Colors.white.withAlpha((0.5 * 255).round()),
                      size: 20,
                    ),
                    onTap: _loadDatabaseStats,
                  ),
                  const SizedBox(height: 8),

                  _buildActionTile(
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppTheme.error,
                    title: 'Clear Database',
                    subtitle: 'Delete all app data (irreversible)',
                    trailing: Icon(
                      Icons.delete_forever_rounded,
                      color: AppTheme.error.withAlpha((0.7 * 255).round()),
                      size: 20,
                    ),
                    onTap: () => _confirmClearDatabase(),
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
    Color? iconColor,
  }) {
    final activeColor = iconColor ?? AppTheme.brandPink;
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
                    ? activeColor.withAlpha((0.15 * 255).round())
                    : Colors.white.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            icon,
            color:
                value
                    ? activeColor
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

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
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
                  color: iconColor.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, color: iconColor, size: 20),
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
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  String _formatDbStats(Map<String, int> stats) {
    final entries = stats.entries.toList();
    if (entries.isEmpty) return 'Database is empty';

    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    return '$total total entries across ${entries.length} tables';
  }

  Future<void> _confirmClearLastfmCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.backgroundDark,
            title: const Text(
              'Clear Last.fm Cache',
              style: TextStyle(color: Colors.white, fontFamily: 'VarelaRound'),
            ),
            content: Text(
              'This will remove all cached Last.fm data. Are you sure?',
              style: TextStyle(
                color: Colors.white.withAlpha((0.8 * 255).round()),
                fontFamily: 'VarelaRound',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Clear',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      try {
        await LastfmService().clearCache();
        if (mounted) {
          _showSnackBar(message: 'Last.fm cache cleared', isError: false);
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar(message: 'Error clearing cache: $e', isError: true);
        }
      }
    }
  }

  Future<void> _confirmClearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.backgroundDark,
            title: const Text(
              'Clear All Cache',
              style: TextStyle(color: Colors.white, fontFamily: 'VarelaRound'),
            ),
            content: Text(
              'This will remove all cached data including artwork. Are you sure?',
              style: TextStyle(
                color: Colors.white.withAlpha((0.8 * 255).round()),
                fontFamily: 'VarelaRound',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Clear',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      try {
        await LastfmService().clearCache();
        LyricsCacheService.instance.clearCache();
        ArtworkCacheService.instance.clearAllCache();
        ArtistArtworkWidget.clearAllCache();
        await CachedNetworkImage.evictFromCache('');
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        PreferencesService().clearCache();

        if (mounted) {
          _showSnackBar(
            message: 'All cache cleared successfully',
            isError: false,
          );
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar(message: 'Error clearing cache: $e', isError: true);
        }
      }
    }
  }

  Future<void> _confirmClearDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.backgroundDark,
            title: const Text(
              'Clear Database',
              style: TextStyle(color: Colors.white, fontFamily: 'VarelaRound'),
            ),
            content: Text(
              'This will delete ALL app data including favorites, playlists, and listening history. This action cannot be undone!\n\nAre you absolutely sure?',
              style: TextStyle(
                color: Colors.white.withAlpha((0.8 * 255).round()),
                fontFamily: 'VarelaRound',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text(
                  'DELETE ALL DATA',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      try {
        await SonoDatabaseHelper.instance.clearAllData();
        setState(() => _dbStats = null);
        if (mounted) {
          _showSnackBar(
            message: 'Database cleared successfully',
            isError: false,
          );
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar(message: 'Error clearing database: $e', isError: true);
        }
      }
    }
  }

  Future<void> _confirmTestCrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.backgroundDark,
            title: const Text(
              'Test Crash',
              style: TextStyle(color: Colors.white, fontFamily: 'VarelaRound'),
            ),
            content: Text(
              'This will trigger a test crash to verify Crashlytics is working correctly. The app will crash immediately.\n\nAre you sure?',
              style: TextStyle(
                color: Colors.white.withAlpha((0.8 * 255).round()),
                fontFamily: 'VarelaRound',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text(
                  'Crash App',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      if (!FirebaseAvailability.instance.isAvailable) {
        _showSnackBar(
          message: 'Firebase is not available, cannot test crash',
          isError: true,
        );
        return;
      }
      FirebaseCrashlytics.instance.crash();
    }
  }

  Future<void> _resetSetupFlow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.backgroundDark,
            title: const Text(
              'Reset Setup Flow',
              style: TextStyle(color: Colors.white, fontFamily: 'VarelaRound'),
            ),
            content: Text(
              'The setup wizard will be shown the next time you open the app.\n\nDo you want to continue?',
              style: TextStyle(
                color: Colors.white.withAlpha((0.8 * 255).round()),
                fontFamily: 'VarelaRound',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Reset',
                  style: TextStyle(fontFamily: 'VarelaRound'),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      await _developerSettings.setSetupCompleted(false);
      _showSnackBar(
        message: 'Setup flow will show on next app launch',
        isError: false,
      );
    }
  }
}
