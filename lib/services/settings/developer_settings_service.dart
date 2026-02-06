import 'package:sono/services/settings/base_settings_service.dart';

/// Service for managing developer/experimental settings
class DeveloperSettingsService extends BaseSettingsService {
  DeveloperSettingsService._();
  static final DeveloperSettingsService instance = DeveloperSettingsService._();

  @override
  String get category => 'developer';

  // Setting keys
  static const String _keyExperimentalFeatures = 'experimental_features';
  static const String _keySetupCompleted = 'setup_completed';

  /// Gets whether experimental features are enabled
  Future<bool> getExperimentalFeaturesEnabled() async {
    return await getSetting<bool>(_keyExperimentalFeatures, false);
  }

  /// Sets whether experimental features are enabled
  Future<void> setExperimentalFeaturesEnabled(bool enabled) async {
    await setSetting<bool>(_keyExperimentalFeatures, enabled);
  }

  /// Gets whether the initial setup flow has been completed
  Future<bool> getSetupCompleted() async {
    return await getSetting<bool>(_keySetupCompleted, false);
  }

  /// Sets whether the initial setup flow has been completed
  Future<void> setSetupCompleted(bool completed) async {
    await setSetting<bool>(_keySetupCompleted, completed);
  }
}