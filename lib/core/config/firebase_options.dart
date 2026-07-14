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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyC9oBBsgfiUxZr2K7AjbFG6uR45GHCW4h8',
    appId: '1:797110136734:android:8ea023d231c7cb34d4308f',
    messagingSenderId: '797110136734',
    projectId: 'intership-96534',
    authDomain: 'intership-96534.firebaseapp.com',
    storageBucket: 'intership-96534.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC9oBBsgfiUxZr2K7AjbFG6uR45GHCW4h8',
    appId: '1:797110136734:android:8ea023d231c7cb34d4308f',
    messagingSenderId: '797110136734',
    projectId: 'intership-96534',
    storageBucket: 'intership-96534.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBtdRinOKnqtZe7H6TuhNMHgZ9SF1MXp_g',
    // TODO: Replace with the real iOS appId from google-services.plist
    // (run `flutterfire configure` to regenerate for iOS)
    appId: '1:797110136734:ios:REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '797110136734',
    projectId: 'intership-96534',
    storageBucket: 'intership-96534.appspot.com',
    // TODO: Replace with the real OAuth 2.0 client ID from google-services.plist
    iosClientId: 'REPLACE_WITH_IOS_CLIENT_ID',
    iosBundleId: 'com.swastik',
  );
}