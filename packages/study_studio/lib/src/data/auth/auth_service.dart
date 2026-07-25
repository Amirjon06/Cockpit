/// Auth boundary for the app.
///
/// The backend accepts a Firebase ID token as `Authorization: Bearer …` and
/// verifies it against Octopilot's Firebase project. This interface provides
/// that token to the API client.
///
/// Today it's [StubAuthService] (no token → the backend uses the dev X-User-Id
/// header). To turn on real auth, add `firebase_core` + `firebase_auth`, drop in
/// a `FirebaseAuthService implements AuthService` that returns
/// `FirebaseAuth.instance.currentUser?.getIdToken()`, and point
/// `authServiceProvider` at it. No API-client or page changes needed — the
/// SseClient already sends the token when this returns non-null.
abstract interface class AuthService {
  /// Current Firebase ID token, or null when signed out / in dev mode.
  Future<String?> idToken();

  /// Whether a user is currently signed in.
  bool get isSignedIn;

  Future<void> signIn();

  Future<void> signOut();
}

/// Offline default: no token, no session. The backend falls back to X-User-Id.
class StubAuthService implements AuthService {
  const StubAuthService();

  @override
  Future<String?> idToken() async => null;

  @override
  bool get isSignedIn => false;

  @override
  Future<void> signIn() async {}

  @override
  Future<void> signOut() async {}
}
