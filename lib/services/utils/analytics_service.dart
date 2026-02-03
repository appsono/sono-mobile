import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sono/services/utils/preferences_service.dart';

class AnalyticsService {
  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: _analytics,
  );

  static final PreferencesService _prefsService = PreferencesService();

  static const String _analyticsEnabledKey = 'analytics_enabled_v1';
  static String? _cachedAppVersion;

  static Future<String> _getAppVersion() async {
    if (_cachedAppVersion != null) return _cachedAppVersion!;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _cachedAppVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      return _cachedAppVersion!;
    } catch (e) {
      if (kDebugMode) print('Analytics: Error getting app version: $e');
      _cachedAppVersion = 'unknown';
      return _cachedAppVersion!;
    }
  }

  static Future<bool> isAnalyticsEnabled() async {
    try {
      final result = await _prefsService.getBool(
        _analyticsEnabledKey,
        defaultValue: true,
      );
      return result ?? true;
    } catch (e) {
      if (kDebugMode) {
        print('Analytics: Error checking preference, defaulting to enabled');
      }
      return true;
    }
  }

  static Future<void> setAnalyticsEnabled(bool enabled) async {
    try {
      await _prefsService.setBool(_analyticsEnabledKey, enabled);
      await _analytics.setAnalyticsCollectionEnabled(enabled);

      if (kDebugMode) {
        print('Analytics: ${enabled ? 'Enabled' : 'Disabled'} by user');
      }
    } catch (e) {
      if (kDebugMode) print('Analytics: Error setting preference: $e');
    }
  }

  static Future<void> initialize() async {
    final isEnabled = await isAnalyticsEnabled();
    await _analytics.setAnalyticsCollectionEnabled(isEnabled);

    if (isEnabled) {
      final appVersion = await _getAppVersion();
      await _analytics.setUserProperty(name: 'app_version', value: appVersion);
    }

    if (kDebugMode) {
      print(
        'Analytics: Initialized with collection ${isEnabled ? 'enabled' : 'disabled'}',
      );
    }
  }

  static Future<bool> _shouldLogEvent() async {
    return await isAnalyticsEnabled();
  }

  static Future<void> logEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
  }) async {
    if (!await _shouldLogEvent()) return;

    final Map<String, Object>? safeParameters =
        parameters == null
            ? null
            : Map.fromEntries(
              parameters.entries
                  .where((e) => e.value != null)
                  .map((e) => MapEntry(e.key, e.value as Object)),
            );

    await _analytics.logEvent(name: eventName, parameters: safeParameters);
    if (kDebugMode) {
      print(
        'Analytics: Event logged - $eventName ${parameters != null ? 'with parameters' : ''}',
      );
    }
  }

  static Future<void> logAppOpen() async {
    if (!await _shouldLogEvent()) return;

    final appVersion = await _getAppVersion();

    await _analytics.logEvent(
      name: 'app_open',
      parameters: {
        'app_version': appVersion,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      },
    );
    if (kDebugMode) print('Analytics: App opened (v$appVersion)');
  }

  static Future<void> logScreenView(String screenName) async {
    if (!await _shouldLogEvent()) return;

    await _analytics.logScreenView(screenName: screenName);
    if (kDebugMode) print('Analytics: Screen view - $screenName');
  }

  static Future<void> logSongPlay({
    required String songTitle,
    required String artist,
    required String album,
  }) async {
    if (!await _shouldLogEvent()) return;

    await _analytics.logEvent(
      name: 'song_play',
      parameters: {
        'song_title':
            songTitle.length > 36
                ? '${songTitle.substring(0, 33)}...'
                : songTitle,
        'artist': artist.length > 36 ? '${artist.substring(0, 33)}...' : artist,
        'album': album.length > 36 ? '${album.substring(0, 33)}...' : album,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    if (kDebugMode) print('Analytics: Song played - $songTitle by $artist');
  }

  static Future<void> logSongSkip({
    required String songTitle,
    required int playDurationSeconds,
  }) async {
    if (!await _shouldLogEvent()) return;

    await _analytics.logEvent(
      name: 'song_skip',
      parameters: {
        'song_title':
            songTitle.length > 36
                ? '${songTitle.substring(0, 33)}...'
                : songTitle,
        'play_duration_seconds': playDurationSeconds,
        'skip_percentage':
            playDurationSeconds > 0
                ? (playDurationSeconds / 180 * 100).round()
                : 0,
      },
    );
    if (kDebugMode) {
      print(
        'Analytics: Song skipped - $songTitle after ${playDurationSeconds}s',
      );
    }
  }

  static Future<void> logPlaylistAction({
    required String action,
    required int songCount,
    String? playlistName,
  }) async {
    if (!await _shouldLogEvent()) return;

    final parameters = {'action': action, 'song_count': songCount};

    if (playlistName != null && playlistName.isNotEmpty) {
      parameters['playlist_type'] =
          playlistName.toLowerCase().contains('favorite')
              ? 'favorites'
              : 'custom';
    }

    await _analytics.logEvent(name: 'playlist_action', parameters: parameters);
    if (kDebugMode) print('Analytics: Playlist $action with $songCount songs');
  }

  static Future<void> logSASStart({required bool isHost}) async {
    if (!await _shouldLogEvent()) return;

    await _analytics.logEvent(
      name: 'sas_session_start',
      parameters: {
        'is_host': isHost.toString(),
        'session_type': isHost ? 'host' : 'client',
      },
    );
    if (kDebugMode) {
      print('Analytics: SAS session started (${isHost ? 'Host' : 'Client'})');
    }
  }

  static Future<void> logSASEnd({
    required int durationMinutes,
    required int participantCount,
    required bool wasHost,
  }) async {
    if (!await _shouldLogEvent()) return;

    await _analytics.logEvent(
      name: 'sas_session_end',
      parameters: {
        'duration_minutes': durationMinutes,
        'participant_count': participantCount,
        'was_host': wasHost.toString(),
        'session_success': (durationMinutes > 1).toString(),
      },
    );
    if (kDebugMode) {
      print(
        'Analytics: SAS session ended - ${durationMinutes}min, $participantCount participants',
      );
    }
  }

  static Future<void> logSearch({
    required String searchType,
    required int resultCount,
  }) async {
    if (!await _shouldLogEvent()) return;

    await _analytics.logEvent(
      name: 'search_performed',
      parameters: {
        'search_type': searchType,
        'result_count': resultCount,
        'has_results': (resultCount > 0).toString(),
      },
    );
    if (kDebugMode) {
      print('Analytics: Search performed - $searchType ($resultCount results)');
    }
  }

  static Future<void> logSettingsChange({
    required String settingName,
    required String newValue,
  }) async {
    if (!await _shouldLogEvent()) return;

    if (settingName.contains('password') ||
        settingName.contains('token') ||
        settingName.contains('key')) {
      return;
    }

    await _analytics.logEvent(
      name: 'settings_change',
      parameters: {'setting_name': settingName, 'new_value': newValue},
    );
    if (kDebugMode) {
      print('Analytics: Setting changed - $settingName = $newValue');
    }
  }

  static Future<void> logFeatureUsage({required String featureName}) async {
    if (!await _shouldLogEvent()) return;

    await _analytics.logEvent(
      name: 'feature_usage',
      parameters: {
        'feature_name': featureName,
        'usage_timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    if (kDebugMode) print('Analytics: Feature used - $featureName');
  }

  static Future<void> logError({
    required String errorType,
    required String errorContext,
  }) async {
    if (!await _shouldLogEvent()) return;

    final appVersion = await _getAppVersion();

    await _analytics.logEvent(
      name: 'app_error',
      parameters: {
        'error_type': errorType,
        'error_context': errorContext,
        'app_version': appVersion,
      },
    );
    if (kDebugMode) {
      print(
        'Analytics: Error logged - $errorType in $errorContext (v$appVersion)',
      );
    }
  }

  static Future<void> setUserProperties({
    String? userType,
    String? preferredTheme,
    bool? hasSASFeature,
  }) async {
    if (!await _shouldLogEvent()) return;

    if (userType != null) {
      await _analytics.setUserProperty(name: 'user_type', value: userType);
    }
    if (preferredTheme != null) {
      await _analytics.setUserProperty(
        name: 'theme_preference',
        value: preferredTheme,
      );
    }
    if (hasSASFeature != null) {
      await _analytics.setUserProperty(
        name: 'sas_user',
        value: hasSASFeature.toString(),
      );
    }
  }

  static Future<void> logAnalyticsPreferenceChanged(bool enabled) async {
    await _analytics.logEvent(
      name: 'analytics_preference_changed',
      parameters: {
        'analytics_enabled': enabled.toString(),
        'change_timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    if (kDebugMode) {
      print(
        'Analytics: Preference changed to ${enabled ? 'enabled' : 'disabled'}',
      );
    }
  }

  static Future<void> checkForAppUpdate() async {
    if (!await _shouldLogEvent()) return;

    try {
      const lastKnownVersionKey = 'last_known_app_version_v1';
      final currentVersion = await _getAppVersion();
      final lastKnownVersion = await _prefsService.getString(
        lastKnownVersionKey,
        defaultValue: null,
      );

      if (lastKnownVersion != null && lastKnownVersion != currentVersion) {
        await _analytics.logEvent(
          name: 'app_updated',
          parameters: {
            'previous_version': lastKnownVersion,
            'current_version': currentVersion,
            'update_timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        );

        if (kDebugMode) {
          print(
            'Analytics: App updated from $lastKnownVersion to $currentVersion',
          );
        }
      }

      await _prefsService.setString(lastKnownVersionKey, currentVersion);
    } catch (e) {
      if (kDebugMode) print('Analytics: Error checking app update: $e');
    }
  }

  static Future<void> logDebugInfo() async {
    if (!kDebugMode) return;

    final appVersion = await _getAppVersion();
    final analyticsEnabled = await isAnalyticsEnabled();

    if (kDebugMode) {
      print('Analytics Debug Info:');
      print('   App Version: $appVersion');
      print('   Analytics Enabled: $analyticsEnabled');
      print('   Platform: ${kIsWeb ? 'Web' : Platform.operatingSystem}');
    }
  }
}
