// Firebase configuration loaded from environment variables.
// This file intentionally avoids hardcoding secrets so keys are not exposed
// in source control or in compiled assets. Populate your `.env` with the
// required FIREBASE_* variables and ensure `.env` is NOT bundled in
// `pubspec.yaml` assets.
//
// Example env keys (you can choose your own names, but update .env accordingly):
// FIREBASE_API_KEY_WEB, FIREBASE_APP_ID_WEB, FIREBASE_MESSAGING_SENDER_ID_WEB,
// FIREBASE_AUTH_DOMAIN, FIREBASE_STORAGE_BUCKET, FIREBASE_PROJECT_ID
// FIREBASE_API_KEY_ANDROID, FIREBASE_APP_ID_ANDROID, FIREBASE_MESSAGING_SENDER_ID
// FIREBASE_API_KEY_IOS, FIREBASE_APP_ID_IOS, FIREBASE_IOS_CLIENT_ID, FIREBASE_IOS_BUNDLE_ID

// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:sono/services/utils/env_config.dart';

/// Default [FirebaseOptions] for use with your Firebase apps. Values are read
/// from environment variables (via `EnvConfig`). If a required variable is
/// missing the getter will return an instance with empty strings, and
/// Firebase.initializeApp will likely throw—this is intentional so you don't
/// accidentally ship builds without config.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'configure FIREBASE_* variables in your .env and adapt this file.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'configure FIREBASE_* variables in your .env and adapt this file.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'configure FIREBASE_* variables in your .env and adapt this file.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web {
    return FirebaseOptions(
      apiKey: EnvConfig.get('FIREBASE_API_KEY_WEB') ?? '',
      appId: EnvConfig.get('FIREBASE_APP_ID_WEB') ?? '',
      messagingSenderId:
          EnvConfig.get('FIREBASE_MESSAGING_SENDER_ID_WEB') ?? '',
      projectId: EnvConfig.get('FIREBASE_PROJECT_ID') ?? '',
      authDomain: EnvConfig.get('FIREBASE_AUTH_DOMAIN') ?? '',
      storageBucket: EnvConfig.get('FIREBASE_STORAGE_BUCKET') ?? '',
    );
  }

  static FirebaseOptions get android {
    return FirebaseOptions(
      apiKey: EnvConfig.get('FIREBASE_API_KEY_ANDROID') ?? '',
      appId: EnvConfig.get('FIREBASE_APP_ID_ANDROID') ?? '',
      messagingSenderId: EnvConfig.get('FIREBASE_MESSAGING_SENDER_ID') ?? '',
      projectId: EnvConfig.get('FIREBASE_PROJECT_ID') ?? '',
      storageBucket: EnvConfig.get('FIREBASE_STORAGE_BUCKET') ?? '',
    );
  }

  static FirebaseOptions get ios {
    return FirebaseOptions(
      apiKey: EnvConfig.get('FIREBASE_API_KEY_IOS') ?? '',
      appId: EnvConfig.get('FIREBASE_APP_ID_IOS') ?? '',
      messagingSenderId: EnvConfig.get('FIREBASE_MESSAGING_SENDER_ID') ?? '',
      projectId: EnvConfig.get('FIREBASE_PROJECT_ID') ?? '',
      storageBucket: EnvConfig.get('FIREBASE_STORAGE_BUCKET') ?? '',
      iosClientId: EnvConfig.get('FIREBASE_IOS_CLIENT_ID') ?? '',
      iosBundleId: EnvConfig.get('FIREBASE_IOS_BUNDLE_ID') ?? '',
    );
  }
}
