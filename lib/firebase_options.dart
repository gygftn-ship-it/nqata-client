import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Identifiants Firebase de l'app Android (ce ne sont pas des secrets : ils sont embarqués dans l'APK).
class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAdymeGfWjpqKng_0Bp_T7P2mQhxuaZU-g',
    appId: '1:461393306115:android:ab8f885c2bbefd7ddfe436',
    messagingSenderId: '461393306115',
    projectId: 'nqata-dc83f',
    storageBucket: 'nqata-dc83f.firebasestorage.app',
  );
}
