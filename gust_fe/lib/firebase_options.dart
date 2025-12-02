import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration for the Gust app.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBCUii5_z-i8sSwCuqeX11PeORjWrWC_OQ',
    appId: '1:625687106738:web:PLACEHOLDER',
    messagingSenderId: '625687106738',
    projectId: 'gust-a84cd',
    authDomain: 'gust-a84cd.firebaseapp.com',
    storageBucket: 'gust-a84cd.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBCUii5_z-i8sSwCuqeX11PeORjWrWC_OQ',
    appId: '1:625687106738:android:9d5279155fed6d0f4425ab',
    messagingSenderId: '625687106738',
    projectId: 'gust-a84cd',
    storageBucket: 'gust-a84cd.firebasestorage.app',
  );
}
