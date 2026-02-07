/// Tracks whether Firebase was successfully initialized.
/// All Firebase-dependent code should check [isAvailable] before
/// calling any Firebase API.
class FirebaseAvailability {
  FirebaseAvailability._();
  static final FirebaseAvailability instance = FirebaseAvailability._();

  bool _initialized = false;

  /// Whether Firebase.initializeApp completed without error.
  bool get isAvailable => _initialized;

  /// Called once after a successful Firebase.initializeApp.
  void markAvailable() => _initialized = true;
}