import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCBeGTlRh_QUgOv5Ylu7yaB96OimIPY0PA',
    authDomain: 'socmed-33036.firebaseapp.com',
    projectId: 'socmed-33036',
    storageBucket: 'socmed-33036.firebasestorage.app',
    messagingSenderId: '418409734333',
    appId: '1:418409734333:web:85ed7c489a6fdbe59557d4',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBSWddvoWu70F_7i1l3h2HZW5JQIvvot8w',
    appId: '1:418409734333:android:7cc8107cec990a219557d4',
    messagingSenderId: '418409734333',
    projectId: 'socmed-33036',
    storageBucket: 'socmed-33036.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBSWddvoWu70F_7i1l3h2HZW5JQIvvot8w',
    appId: '1:418409734333:ios:c3e6a7f2e1b3d4a8',
    messagingSenderId: '418409734333',
    projectId: 'socmed-33036',
    storageBucket: 'socmed-33036.firebasestorage.app',
    iosBundleId: 'com.example.socMedApp',
  );
}