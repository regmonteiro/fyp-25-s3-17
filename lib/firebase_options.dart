import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDst5g_tOob8aTDeKejRNVEY-JXQUB6hy0',
    appId: '1:598007516552:web:6d1e98e2d21686d187fe3d',
    messagingSenderId: '598007516552',
    projectId: 'elderly-aiassistant',
    authDomain: 'elderly-aiassistant.firebaseapp.com',
    databaseURL: 'https://elderly-aiassistant-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'elderly-aiassistant.firebasestorage.app',
    measurementId: 'G-54B83PF5YV',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDxf2NywtwXc6jnAIIRBsh0M2dSMexkf-U',
    appId: '1:598007516552:android:66cc00b51c06bfc787fe3d',
    messagingSenderId: '598007516552',
    projectId: 'elderly-aiassistant',
    databaseURL: 'https://elderly-aiassistant-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'elderly-aiassistant.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB7P146Rzi--CREAz4D1l3R0KW1tS5voRs',
    appId: '1:598007516552:ios:806773a55f28469a87fe3d',
    messagingSenderId: '598007516552',
    projectId: 'elderly-aiassistant',
    databaseURL: 'https://elderly-aiassistant-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'elderly-aiassistant.firebasestorage.app',
    iosBundleId: 'com.allcare.allcare',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB7P146Rzi--CREAz4D1l3R0KW1tS5voRs',
    appId: '1:598007516552:ios:ae12b4ab75d6af7b87fe3d',
    messagingSenderId: '598007516552',
    projectId: 'elderly-aiassistant',
    databaseURL: 'https://elderly-aiassistant-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'elderly-aiassistant.firebasestorage.app',
    iosBundleId: 'com.allcare.allcare.macos',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDst5g_tOob8aTDeKejRNVEY-JXQUB6hy0',
    appId: '1:598007516552:web:8294db7133f4de9487fe3d',
    messagingSenderId: '598007516552',
    projectId: 'elderly-aiassistant',
    authDomain: 'elderly-aiassistant.firebaseapp.com',
    databaseURL: 'https://elderly-aiassistant-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'elderly-aiassistant.firebasestorage.app',
    measurementId: 'G-505ZBS5V0F',
  );
}
