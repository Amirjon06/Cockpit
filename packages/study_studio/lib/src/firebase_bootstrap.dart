import 'package:firebase_core/firebase_core.dart';

import 'application/config.dart';

/// Initializes Firebase from the injected config, if present. Safe to call
/// unconditionally from the host app's `main()` — a no-op when Firebase isn't
/// configured (offline/dev), so the app runs without any Firebase setup.
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await initStudioFirebase();
///   runApp(const ProviderScope(child: CockpitApp()));
/// }
/// ```
Future<void> initStudioFirebase() async {
  if (!StudioConfig.firebaseConfigured) return;
  final projectId = StudioConfig.firebaseProjectId;
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: StudioConfig.firebaseApiKey,
      appId: StudioConfig.firebaseAppId,
      projectId: projectId,
      messagingSenderId: StudioConfig.firebaseMessagingSenderId,
      authDomain: StudioConfig.firebaseAuthDomain.isNotEmpty
          ? StudioConfig.firebaseAuthDomain
          : '$projectId.firebaseapp.com',
      storageBucket: StudioConfig.firebaseStorageBucket.isNotEmpty
          ? StudioConfig.firebaseStorageBucket
          : '$projectId.appspot.com',
    ),
  );
}
