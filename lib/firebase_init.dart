import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:sono/services/utils/crashlytics_service.dart';
import 'package:sono/services/utils/firebase_availability.dart';
import 'firebase_options.dart';

Future<void> initializeFirebase() async {
  try {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    FirebaseAvailability.instance.markAvailable();
    await CrashlyticsService.instance.initialize();

    if (CrashlyticsService.instance.isEnabled) {
      FlutterError.onError = (FlutterErrorDetails details) {
        if (FirebaseAvailability.instance.isAvailable) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        }
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        if (FirebaseAvailability.instance.isAvailable) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        }
        return true;
      };
    }
  } catch (e) {
    if (e.toString().contains('already exists')) {
      FirebaseAvailability.instance.markAvailable();
    } else {
      debugPrint('[Firebase] Init FAILED: $e');
    }
  }
}
