import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sono/services/utils/env_config.dart';

class PreferencesService with ChangeNotifier {
  static const String excludedFoldersKey = 'excluded_folders_v1';
  static const String analyticsEnabledKey = 'analytics_enabled_v1';
  static const String lastKnownVersionKey = 'last_known_app_version_v1';
  static const String crossfadeEnabledKey = 'crossfade_enabled_v1';
  static const String crossfadeDurationKey = 'crossfade_duration_seconds_v1';
  static const String playbackSpeedKey = 'playback_speed_v1';
  static const String playbackPitchKey = 'playback_pitch_v1';
  static const String playlistCoverKeyPrefix = 'playlist_cover_song_id_v1_';
  static const String albumCoverRotationKey = 'album_cover_rotation_v1';
  static const String themeModeKey = 'theme_mode_v1';
  static const String accentColorKey = 'accent_color_v1';
  static const String experimentalThemesEnabledKey =
      'experimental_themes_enabled_v1';
  static const String apiModeIsProdKey = 'api_mode_is_prod_preference_v1';
  static const String backgroundPlaybackEnabledKey =
      'background_playback_enabled_v1';
  static const String resumeAfterRebootEnabledKey =
      'resume_after_reboot_enabled_v1';
  static const String lastfmScrobblingEnabledKey =
      'lastfm_scrobbling_enabled_v1';
  static const String crashlyticsEnabledKey = 'crashlytics_enabled_v1';

  SharedPreferences? _prefs;

  final Map<String, dynamic> _cache = {};
  bool _cacheInitialized = false;

  Future<SharedPreferences> get prefs async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> initializeCache() async {
    if (_cacheInitialized) return;

    try {
      final prefs = await this.prefs;

      _cache[excludedFoldersKey] = prefs.getStringList(excludedFoldersKey);
      _cache[analyticsEnabledKey] = prefs.getBool(analyticsEnabledKey);
      _cache[lastKnownVersionKey] = prefs.getString(lastKnownVersionKey);
      _cache[crossfadeEnabledKey] = prefs.getBool(crossfadeEnabledKey);
      _cache[crossfadeDurationKey] = prefs.getInt(crossfadeDurationKey);
      _cache[playbackSpeedKey] = prefs.getDouble(playbackSpeedKey);
      _cache[playbackPitchKey] = prefs.getDouble(playbackPitchKey);
      _cache[albumCoverRotationKey] = prefs.getBool(albumCoverRotationKey);
      _cache[themeModeKey] = prefs.getInt(themeModeKey);
      _cache[accentColorKey] = prefs.getInt(accentColorKey);
      _cache[experimentalThemesEnabledKey] = prefs.getBool(
        experimentalThemesEnabledKey,
      );
      _cache[apiModeIsProdKey] = prefs.getBool(apiModeIsProdKey);
      _cache[backgroundPlaybackEnabledKey] = prefs.getBool(
        backgroundPlaybackEnabledKey,
      );
      _cache[resumeAfterRebootEnabledKey] = prefs.getBool(
        resumeAfterRebootEnabledKey,
      );

      _cacheInitialized = true;
      debugPrint('PreferencesService: Cache initialized');
    } catch (e) {
      debugPrint('PreferencesService: Error initializing cache: $e');
    }
  }

  Future<T?> _getCachedValue<T>(String key, T? Function() defaultValue) async {
    if (!_cacheInitialized) {
      await initializeCache();
    }

    if (_cache.containsKey(key)) {
      final cachedValue = _cache[key] as T?;
      return cachedValue ?? defaultValue();
    }

    try {
      final prefs = await this.prefs;
      T? value;

      if (T == String) {
        value = prefs.getString(key) as T?;
      } else if (T == int) {
        value = prefs.getInt(key) as T?;
      } else if (T == double) {
        value = prefs.getDouble(key) as T?;
      } else if (T == bool) {
        value = prefs.getBool(key) as T?;
      } else if (T == List<String>) {
        value = prefs.getStringList(key) as T?;
      }

      _cache[key] = value;
      return value ?? defaultValue();
    } catch (e) {
      debugPrint('PreferencesService: Error getting cached value for $key: $e');
      return defaultValue();
    }
  }

  Future<void> _setCachedValue<T>(
    String key,
    T value, {
    bool notify = true,
  }) async {
    try {
      final prefs = await this.prefs;
      bool success = false;

      if (T == String) {
        success = await prefs.setString(key, value as String);
      } else if (T == int) {
        success = await prefs.setInt(key, value as int);
      } else if (T == double) {
        success = await prefs.setDouble(key, value as double);
      } else if (T == bool) {
        success = await prefs.setBool(key, value as bool);
      } else if (T == List<String>) {
        success = await prefs.setStringList(key, value as List<String>);
      }

      if (success) {
        _cache[key] = value;
        if (notify) {
          notifyListeners();
        }
      } else {
        debugPrint('PreferencesService: Failed to set $key');
      }
    } catch (e) {
      debugPrint('PreferencesService: Error setting cached value for $key: $e');
      rethrow;
    }
  }

  //--- Excluded Folders ---

  Future<List<String>> getExcludedFolders() async {
    final result = await _getCachedValue<List<String>>(
      excludedFoldersKey,
      () => <String>[],
    );
    return result ?? [];
  }

  Future<void> saveExcludedFolders(List<String> paths) async {
    if (paths.isEmpty) {
      await _setCachedValue<List<String>>(excludedFoldersKey, []);
      return;
    }

    final cleanPaths =
        paths.where((path) => path.trim().isNotEmpty).toSet().toList();
    await _setCachedValue<List<String>>(excludedFoldersKey, cleanPaths);
  }

  Future<void> addExcludedFolder(String path) async {
    if (path.trim().isEmpty) return;

    final current = await getExcludedFolders();
    if (!current.contains(path)) {
      current.add(path);
      await saveExcludedFolders(current);
    }
  }

  Future<void> removeExcludedFolder(String path) async {
    final current = await getExcludedFolders();
    if (current.remove(path)) {
      await saveExcludedFolders(current);
    }
  }

  //--- Analytics Settings ---

  //analytics preference methods
  Future<bool> isAnalyticsEnabled() async {
    final result = await _getCachedValue<bool>(analyticsEnabledKey, () => true);
    return result ?? true;
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    await _setCachedValue<bool>(analyticsEnabledKey, enabled);
  }

  //app version tracking methods
  Future<String?> getLastKnownVersion() async {
    return await getString(lastKnownVersionKey);
  }

  Future<void> setLastKnownVersion(String version) async {
    await setString(lastKnownVersionKey, version);
  }

  //--- Crossfade Settings ---

  Future<bool> isCrossfadeEnabled() async {
    final result = await _getCachedValue<bool>(
      crossfadeEnabledKey,
      () => false,
    );
    return result ?? false;
  }

  Future<void> setCrossfadeEnabled(bool isEnabled) async {
    await _setCachedValue<bool>(crossfadeEnabledKey, isEnabled);
  }

  Future<int> getCrossfadeDurationSeconds() async {
    final result = await _getCachedValue<int>(crossfadeDurationKey, () => 5);
    return (result ?? 5).clamp(1, 30);
  }

  Future<void> setCrossfadeDurationSeconds(int seconds) async {
    final clampedSeconds = seconds.clamp(1, 30);
    await _setCachedValue<int>(crossfadeDurationKey, clampedSeconds);
  }

  //--- Playback Settings ---

  Future<double> getPlaybackSpeed() async {
    final result = await _getCachedValue<double>(playbackSpeedKey, () => 1.0);
    return (result ?? 1.0).clamp(0.25, 3.0);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final clampedSpeed = speed.clamp(0.25, 3.0);
    await _setCachedValue<double>(playbackSpeedKey, clampedSpeed);
  }

  Future<double> getPlaybackPitch() async {
    final result = await _getCachedValue<double>(playbackPitchKey, () => 1.0);
    return (result ?? 1.0).clamp(0.25, 3.0);
  }

  Future<void> setPlaybackPitch(double pitch) async {
    final clampedPitch = pitch.clamp(0.25, 3.0);
    await _setCachedValue<double>(playbackPitchKey, clampedPitch);
  }

  //reset playback settings to defaults
  Future<void> resetPlaybackSettings() async {
    await Future.wait([
      setPlaybackSpeed(1.0),
      setPlaybackPitch(1.0),
      setCrossfadeEnabled(false),
      setCrossfadeDurationSeconds(5),
    ]);
  }

  Future<bool> isBackgroundPlaybackEnabled() async {
    final result = await _getCachedValue<bool>(
      backgroundPlaybackEnabledKey,
      () => true,
    );
    return result ?? true;
  }

  Future<void> setBackgroundPlaybackEnabled(bool enabled) async {
    await _setCachedValue<bool>(backgroundPlaybackEnabledKey, enabled);
  }

  Future<bool> isResumeAfterRebootEnabled() async {
    final result = await _getCachedValue<bool>(
      resumeAfterRebootEnabledKey,
      () => true,
    );
    return result ?? true;
  }

  Future<void> setResumeAfterRebootEnabled(bool enabled) async {
    await _setCachedValue<bool>(resumeAfterRebootEnabledKey, enabled);
  }

  //--- Generic Getters/Setters ---

  Future<bool?> getBool(String key, {bool? defaultValue}) async {
    if (!_cacheInitialized) await initializeCache();

    try {
      final prefs = await this.prefs;
      final value = prefs.getBool(key) ?? defaultValue;
      _cache[key] = value;
      return value;
    } catch (e) {
      debugPrint('PreferencesService: Error getting bool for $key: $e');
      return defaultValue;
    }
  }

  Future<void> setBool(String key, bool value, {bool notify = true}) async {
    await _setCachedValue<bool>(key, value, notify: notify);
  }

  Future<int?> getInt(String key, {int? defaultValue}) async {
    if (!_cacheInitialized) await initializeCache();

    try {
      final prefs = await this.prefs;
      final value = prefs.getInt(key) ?? defaultValue;
      _cache[key] = value;
      return value;
    } catch (e) {
      debugPrint('PreferencesService: Error getting int for $key: $e');
      return defaultValue;
    }
  }

  Future<void> setInt(String key, int value, {bool notify = true}) async {
    await _setCachedValue<int>(key, value, notify: notify);
  }

  Future<double?> getDouble(String key, {double? defaultValue}) async {
    if (!_cacheInitialized) await initializeCache();

    try {
      final prefs = await this.prefs;
      final value = prefs.getDouble(key) ?? defaultValue;
      _cache[key] = value;
      return value;
    } catch (e) {
      debugPrint('PreferencesService: Error getting double for $key: $e');
      return defaultValue;
    }
  }

  Future<void> setDouble(String key, double value, {bool notify = true}) async {
    await _setCachedValue<double>(key, value, notify: notify);
  }

  Future<String?> getString(String key, {String? defaultValue}) async {
    if (!_cacheInitialized) await initializeCache();

    try {
      final prefs = await this.prefs;
      final value = prefs.getString(key) ?? defaultValue;
      _cache[key] = value;
      return value;
    } catch (e) {
      debugPrint('PreferencesService: Error getting string for $key: $e');
      return defaultValue;
    }
  }

  Future<void> setString(String key, String value, {bool notify = true}) async {
    await _setCachedValue<String>(key, value, notify: notify);
  }

  //--- Playlist Cover Settings ---

  Future<void> setPlaylistCover(int playlistId, int songId) async {
    if (playlistId <= 0 || songId <= 0) {
      debugPrint(
        'PreferencesService: Invalid playlist ID ($playlistId) or song ID ($songId)',
      );
      return;
    }

    await _setCachedValue<int>(
      '$playlistCoverKeyPrefix$playlistId',
      songId,
      notify: false,
    );
  }

  Future<int?> getPlaylistCover(int playlistId) async {
    if (playlistId <= 0) return null;

    return await _getCachedValue<int>(
      '$playlistCoverKeyPrefix$playlistId',
      () => null,
    );
  }

  Future<void> removePlaylistCover(int playlistId) async {
    if (playlistId <= 0) return;

    try {
      final prefs = await this.prefs;
      final key = '$playlistCoverKeyPrefix$playlistId';
      await prefs.remove(key);
      _cache.remove(key);
      debugPrint(
        'PreferencesService: Removed playlist cover for playlist $playlistId',
      );
    } catch (e) {
      debugPrint('PreferencesService: Error removing playlist cover: $e');
    }
  }

  //get all playlist covers
  Future<Map<int, int>> getAllPlaylistCovers() async {
    try {
      final prefs = await this.prefs;
      final Map<int, int> covers = {};

      for (final key in prefs.getKeys()) {
        if (key.startsWith(playlistCoverKeyPrefix)) {
          final playlistIdStr = key.substring(playlistCoverKeyPrefix.length);
          final playlistId = int.tryParse(playlistIdStr);
          final songId = prefs.getInt(key);

          if (playlistId != null &&
              songId != null &&
              playlistId > 0 &&
              songId > 0) {
            covers[playlistId] = songId;
          }
        }
      }

      return covers;
    } catch (e) {
      debugPrint('PreferencesService: Error getting all playlist covers: $e');
      return {};
    }
  }

  //--- UI Settings ---

  Future<bool> isAlbumCoverRotationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('album_cover_rotation_v1') ?? true;
  }

  Future<void> setAlbumCoverRotationEnabled(bool isEnabled) async {
    await _setCachedValue<bool>(albumCoverRotationKey, isEnabled);
  }

  Future<bool> areExperimentalThemesEnabled() async {
    final result = await _getCachedValue<bool>(
      experimentalThemesEnabledKey,
      () => false,
    );
    return result ?? false;
  }

  Future<void> setExperimentalThemesEnabled(bool isEnabled) async {
    await _setCachedValue<bool>(experimentalThemesEnabledKey, isEnabled);
  }

  //--- API Settings ---

  Future<bool> isApiModeProduction() async {
    final result = await _getCachedValue<bool>(apiModeIsProdKey, () => true);
    return result ?? true;
  }

  Future<void> setApiMode({required bool useProduction}) async {
    await _setCachedValue<bool>(apiModeIsProdKey, useProduction);
  }

  //--- Batch Operations ---

  Future<void> updateMultiplePreferences(
    Map<String, dynamic> updates, {
    bool notify = true,
  }) async {
    if (updates.isEmpty) return;

    try {
      final prefs = await this.prefs;

      for (final entry in updates.entries) {
        final key = entry.key;
        final value = entry.value;

        bool success = false;
        if (value is String) {
          success = await prefs.setString(key, value);
        } else if (value is int) {
          success = await prefs.setInt(key, value);
        } else if (value is double) {
          success = await prefs.setDouble(key, value);
        } else if (value is bool) {
          success = await prefs.setBool(key, value);
        } else if (value is List<String>) {
          success = await prefs.setStringList(key, value);
        }

        if (success) {
          _cache[key] = value;
        }
      }

      if (notify) {
        notifyListeners();
      }

      debugPrint('PreferencesService: Updated ${updates.length} preferences');
    } catch (e) {
      debugPrint('PreferencesService: Error updating multiple preferences: $e');
      rethrow;
    }
  }

  //--- Last.fm Scrobbling ---

  Future<bool> isLastfmScrobblingEnabled() async {
    return await _getCachedValue<bool>(
          lastfmScrobblingEnabledKey,
          () => true,
        ) ??
        true;
  }

  Future<void> setLastfmScrobblingEnabled(bool enabled) async {
    await _setCachedValue<bool>(lastfmScrobblingEnabledKey, enabled);
  }

  //--- Crashlytics Settings ---

  Future<bool> isCrashlyticsEnabled() async {
    final defaultValue = EnvConfig.crashlyticsEnabledDefault;
    return await _getCachedValue<bool>(
          crashlyticsEnabledKey,
          () => defaultValue,
        ) ??
        defaultValue;
  }

  Future<void> setCrashlyticsEnabled(bool enabled) async {
    await _setCachedValue<bool>(crashlyticsEnabledKey, enabled);
  }

  //--- Utility Methods ---

  Future<void> clearAllPreferences() async {
    try {
      final prefs = await this.prefs;
      await prefs.clear();
      _cache.clear();
      _cacheInitialized = false;
      notifyListeners();
      debugPrint('PreferencesService: All preferences cleared');
    } catch (e) {
      debugPrint('PreferencesService: Error clearing preferences: $e');
      rethrow;
    }
  }

  void clearCache() {
    _cache.clear();
    _cacheInitialized = false;
    debugPrint('PreferencesService: Cache cleared');
  }

  //get all preference keys
  Future<Set<String>> getAllKeys() async {
    try {
      final prefs = await this.prefs;
      return prefs.getKeys();
    } catch (e) {
      debugPrint('PreferencesService: Error getting all keys: $e');
      return <String>{};
    }
  }

  //export preferences as a map
  Future<Map<String, dynamic>> exportPreferences() async {
    try {
      final prefs = await this.prefs;
      final Map<String, dynamic> exported = {};

      for (final key in prefs.getKeys()) {
        final value = prefs.get(key);
        if (value != null) {
          exported[key] = value;
        }
      }

      return exported;
    } catch (e) {
      debugPrint('PreferencesService: Error exporting preferences: $e');
      return {};
    }
  }

  //get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cache_initialized': _cacheInitialized,
      'cached_items': _cache.length,
      'cache_keys': _cache.keys.toList(),
    };
  }
}
