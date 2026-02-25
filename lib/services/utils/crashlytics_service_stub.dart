/// No-op stub used in F-Droid builds where Firebase is not available.
/// Matches the public API of CrashlyticsService exactly.
class CrashlyticsService {
  static final CrashlyticsService _instance = CrashlyticsService._internal();
  static CrashlyticsService get instance => _instance;

  CrashlyticsService._internal();

  bool get isEnabled => false;

  Future<void> initialize() async {}
  Future<void> setEnabled(bool enabled) async {}
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {}
  Future<void> log(String message) async {}
  Future<void> setCustomKey(String key, dynamic value) async {}
  void crash() {}
}
