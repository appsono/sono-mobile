import 'base_settings_service.dart';

///manages scrobbling-related settings (Last.fm API mode)
class ScrobblingSettingsService extends BaseSettingsService {
  static final ScrobblingSettingsService instance =
      ScrobblingSettingsService._internal();

  ScrobblingSettingsService._internal();

  @override
  String get category => 'scrobbling';

  //default values
  static const bool _defaultApiModeProd = true;

  ///gets whether API mode is production (true) or development (false)
  Future<bool> getApiModeProd() async {
    return await getSetting<bool>('api_mode_prod', _defaultApiModeProd);
  }

  ///sets whether API mode is production (true) or development (false)
  Future<void> setApiModeProd(bool isProd) async {
    await setSetting<bool>('api_mode_prod', isProd);
  }
}
