// Firebase config sourced from --dart-define-from-file=firebase-config.json
// at build time. Both firebase-config.json and android/app/google-services.json
// live OUTSIDE git — copy firebase-config.example.json to firebase-config.json
// and fill in your project's values, then build with:
//
//   flutter build apk --debug --dart-define-from-file=firebase-config.json
//   flutter run             --dart-define-from-file=firebase-config.json

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class _Env {
  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String appIdAndroid =
      String.fromEnvironment('FIREBASE_APP_ID_ANDROID');
  static const String appIdIos = String.fromEnvironment('FIREBASE_APP_ID_IOS');
  static const String messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String projectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const String iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.example.babyGuard',
  );
}

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not configured — add web keys to firebase-config.json.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        _assertConfigured(_Env.appIdAndroid, 'FIREBASE_APP_ID_ANDROID');
        return android;
      case TargetPlatform.iOS:
        _assertConfigured(_Env.appIdIos, 'FIREBASE_APP_ID_IOS');
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for $defaultTargetPlatform.',
        );
    }
  }

  static void _assertConfigured(String value, String key) {
    if (value.isEmpty) {
      throw StateError(
        'Firebase $key is empty. Build with '
        '`--dart-define-from-file=firebase-config.json`.',
      );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _Env.apiKey,
    appId: _Env.appIdAndroid,
    messagingSenderId: _Env.messagingSenderId,
    projectId: _Env.projectId,
    storageBucket: _Env.storageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _Env.apiKey,
    appId: _Env.appIdIos,
    messagingSenderId: _Env.messagingSenderId,
    projectId: _Env.projectId,
    storageBucket: _Env.storageBucket,
    iosBundleId: _Env.iosBundleId,
  );
}
