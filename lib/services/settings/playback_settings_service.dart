import 'base_settings_service.dart';

///manages playback-related settings (speed, pitch, crossfade, background playback)
class PlaybackSettingsService extends BaseSettingsService {
  static final PlaybackSettingsService instance =
      PlaybackSettingsService._internal();

  PlaybackSettingsService._internal();

  @override
  String get category => 'playback';

  //default values
  static const bool _defaultBackgroundPlayback = true;
  static const bool _defaultResumeAfterReboot = false;
  static const bool _defaultCrossfadeEnabled = false;
  static const int _defaultCrossfadeDuration = 5; //seconds
  static const double _defaultSpeed = 1.0;
  static const double _defaultPitch = 1.0;

  ///gets whether background playback is enabled
  Future<bool> getBackgroundPlaybackEnabled() async {
    return await getSetting<bool>(
      'background_playback',
      _defaultBackgroundPlayback,
    );
  }

  ///sets whether background playback is enabled
  Future<void> setBackgroundPlaybackEnabled(bool enabled) async {
    await setSetting<bool>('background_playback', enabled);
  }

  ///gets whether resume after reboot is enabled
  Future<bool> getResumeAfterRebootEnabled() async {
    return await getSetting<bool>(
      'resume_after_reboot',
      _defaultResumeAfterReboot,
    );
  }

  ///sets whether resume after reboot is enabled
  Future<void> setResumeAfterRebootEnabled(bool enabled) async {
    await setSetting<bool>('resume_after_reboot', enabled);
  }

  ///gets whether crossfade is enabled
  Future<bool> getCrossfadeEnabled() async {
    return await getSetting<bool>(
      'crossfade_enabled',
      _defaultCrossfadeEnabled,
    );
  }

  ///sets whether crossfade is enabled
  Future<void> setCrossfadeEnabled(bool enabled) async {
    await setSetting<bool>('crossfade_enabled', enabled);
  }

  ///gets the crossfade duration in seconds
  Future<int> getCrossfadeDuration() async {
    return await getSetting<int>(
      'crossfade_duration',
      _defaultCrossfadeDuration,
    );
  }

  ///sets the crossfade duration in seconds
  Future<void> setCrossfadeDuration(int seconds) async {
    await setSetting<int>('crossfade_duration', seconds);
  }

  ///gets the playback speed
  Future<double> getSpeed() async {
    return await getSetting<double>('speed', _defaultSpeed);
  }

  ///sets the playback speed
  Future<void> setSpeed(double speed) async {
    await setSetting<double>('speed', speed);
  }

  ///gets the playback pitch
  Future<double> getPitch() async {
    return await getSetting<double>('pitch', _defaultPitch);
  }

  ///sets the playback pitch
  Future<void> setPitch(double pitch) async {
    await setSetting<double>('pitch', pitch);
  }
}