import 'base_settings_service.dart';

///manages analytics-related settings
class AnalyticsSettingsService extends BaseSettingsService {
  static final AnalyticsSettingsService instance =
      AnalyticsSettingsService._internal();

  AnalyticsSettingsService._internal();

  @override
  String get category => 'analytics';

  //default values
  static const bool _defaultEnabled = true;

  ///gets whether analytics is enabled
  Future<bool> getEnabled() async {
    return await getSetting<bool>('enabled', _defaultEnabled);
  }

  ///sets whether analytics is enabled
  Future<void> setEnabled(bool enabled) async {
    await setSetting<bool>('enabled', enabled);
  }
}
