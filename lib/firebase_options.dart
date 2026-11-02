import 'package:firebase_core/firebase_core.dart';

/// Configuración pública de Firebase para la PWA.
///
/// No contiene secretos privados. La cuenta de servicio que envía los push
/// vive únicamente en Supabase Edge Functions.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDAOBQG8FbJDff-GzRVqrKvYlBzS3aUTkc',
    appId: '1:916723097837:web:9f184deee93aeb52502ce4',
    messagingSenderId: '916723097837',
    projectId: 'mensajeria911-e84c7',
    authDomain: 'mensajeria911-e84c7.firebaseapp.com',
    storageBucket: 'mensajeria911-e84c7.firebasestorage.app',
  );
}

/// Se pasa al build de la PWA después de generar la clave en Firebase:
/// --dart-define=FIREBASE_WEB_VAPID_KEY=...
const firebaseWebVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');
