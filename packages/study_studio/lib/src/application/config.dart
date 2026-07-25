/// Runtime configuration for the Study Studio module.
///
/// The backend base URL is injected at build/run time:
///
/// ```bash
/// flutter run -d chrome --dart-define=STUDY_API_BASE_URL=http://localhost:8100
/// # production:      --dart-define=STUDY_API_BASE_URL=https://api.octopilot.ai
/// ```
///
/// When it is empty (the default), the app runs fully offline against the
/// in-memory mock repository — so tests and design work need no server. When it
/// is set, the app pulls everything from the server backend over SSE.
class StudioConfig {
  const StudioConfig._();

  static const String apiBaseUrl =
      String.fromEnvironment('STUDY_API_BASE_URL', defaultValue: '');

  /// Dev/user identity header until real auth (octopilot session/JWT) lands.
  static const String devUserId = String.fromEnvironment(
    'STUDY_USER_ID',
    defaultValue: '11111111-1111-1111-1111-111111111111',
  );

  static bool get hasApiBackend => apiBaseUrl.isNotEmpty;
}
