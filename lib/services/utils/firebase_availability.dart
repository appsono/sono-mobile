/// Tracks whether Firebase was successfully initialized
class FirebaseAvailability {
  FirebaseAvailability._();
  static final FirebaseAvailability instance = FirebaseAvailability._();

  bool _initialized = false;

  /// Whether Firebase.initializeApp completed without error
  bool get isAvailable => _initialized;

  /// Called once after successful Firebase.initializeApp
  void markAvailable() => _initialized = true;
}
