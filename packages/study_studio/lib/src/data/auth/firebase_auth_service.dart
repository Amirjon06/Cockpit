import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

/// Real [AuthService] backed by Firebase Auth (Octopilot's Firebase project).
///
/// Enabled only when the Firebase config is provided (see [initStudioFirebase]);
/// otherwise the app uses [StubAuthService]. The ID token it returns is sent by
/// the SseClient as `Authorization: Bearer …` and verified by the backend.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService([FirebaseAuth? auth])
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<String?> idToken() async => _auth.currentUser?.getIdToken();

  @override
  bool get isSignedIn => _auth.currentUser != null;

  @override
  Future<void> signIn() async {
    // Google is Octopilot's primary provider. On web, popup; elsewhere the
    // platform Google flow (wire google_sign_in for mobile when needed).
    final provider = GoogleAuthProvider();
    await _auth.signInWithPopup(provider);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
