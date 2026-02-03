import 'base_settings_service.dart';

///manages audio effects settings (equalizer)
class AudioEffectsService extends BaseSettingsService {
  static final AudioEffectsService instance = AudioEffectsService._internal();

  AudioEffectsService._internal();

  @override
  String get category => 'audio_effects';

  //default values
  static const bool _defaultEqualizerEnabled = false;

  ///gets whether equalizer is enabled
  Future<bool> getEqualizerEnabled() async {
    return await getSetting<bool>(
      'equalizer_enabled',
      _defaultEqualizerEnabled,
    );
  }

  ///sets whether equalizer is enabled
  Future<void> setEqualizerEnabled(bool enabled) async {
    await setSetting<bool>('equalizer_enabled', enabled);
  }

  ///gets the equalizer band level for a specific band index
  ///returns gain in decibels (dB)
  Future<double?> getEqualizerBandLevel(int bandIndex) async {
    final key = 'eq_band_$bandIndex';
    try {
      return await getSetting<double>(key, 0.0);
    } catch (e) {
      return null;
    }
  }

  ///sets the equalizer band level for a specific band index
  ///gain is in decibels (dB)
  Future<void> setEqualizerBandLevel(int bandIndex, double gain) async {
    final key = 'eq_band_$bandIndex';
    await setSetting<double>(key, gain);
  }

  ///gets all equalizer band levels as a map of band index to gain
  Future<Map<int, double>> getAllEqualizerBandLevels() async {
    final settings = await getAllSettings();
    final bandLevels = <int, double>{};

    for (final entry in settings.entries) {
      if (entry.key.startsWith('eq_band_')) {
        final bandIndex = int.tryParse(entry.key.replaceFirst('eq_band_', ''));
        if (bandIndex != null) {
          bandLevels[bandIndex] = entry.value as double;
        }
      }
    }

    return bandLevels;
  }

  ///resets all equalizer bands to flat (0 dB)
  Future<void> resetEqualizerToFlat() async {
    final bandLevels = await getAllEqualizerBandLevels();
    for (final bandIndex in bandLevels.keys) {
      await setEqualizerBandLevel(bandIndex, 0.0);
    }
  }
}
