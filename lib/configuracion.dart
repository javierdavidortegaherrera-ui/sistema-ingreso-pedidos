import 'package:firebase_core/firebase_core.dart';

class Configuracion {
  static const usarFirebase = bool.fromEnvironment('USAR_FIREBASE');
  static FirebaseOptions get firebase {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if ([apiKey, appId, sender, project].any((v) => v.isEmpty)) {
      throw StateError(
        'Faltan valores de Firebase. Consulta README.md y firebase.example.json.',
      );
    }
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: sender,
      projectId: project,
      storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    );
  }
}
