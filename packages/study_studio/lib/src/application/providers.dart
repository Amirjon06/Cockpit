import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai/ai_service.dart';
import '../data/ai/stub_ai_service.dart';
import '../data/api/api_account.dart';
import '../data/api/api_ai_service.dart';
import '../data/api/api_studio_repository.dart';
import '../data/api/sse_client.dart';
import '../data/auth/auth_service.dart';
import '../data/repositories/in_memory_studio_repository.dart';
import '../domain/entities/me.dart';
import '../domain/entities/studio.dart';
import '../domain/entities/topic.dart';
import '../domain/repositories/studio_repository.dart';
import 'config.dart';

/// Auth boundary. Stub (dev, X-User-Id) until Firebase is wired — see
/// [AuthService]. Swap to a FirebaseAuthService here to turn on real auth.
final authServiceProvider = Provider<AuthService>((ref) => const StubAuthService());

/// Shared SSE client (one HTTP client) when the API backend is configured.
/// Sends the Firebase ID token (when signed in) as `Authorization: Bearer`.
final _sseClientProvider = Provider<SseClient>((ref) {
  final auth = ref.watch(authServiceProvider);
  final client = SseClient(tokenProvider: auth.idToken);
  ref.onDispose(client.close);
  return client;
});

/// AI boundary. Uses the backend `/ask` stream when `STUDY_API_BASE_URL` is set,
/// otherwise the offline stub.
final aiServiceProvider = Provider<AiService>((ref) {
  if (StudioConfig.hasApiBackend) {
    return ApiAiService(client: ref.watch(_sseClientProvider));
  }
  return const StubAiService();
});

/// Data access. Uses the server API over SSE when `STUDY_API_BASE_URL` is set,
/// otherwise the in-memory mock (offline dev + tests). Pages are unchanged.
final studioRepositoryProvider = Provider<StudioRepository>((ref) {
  if (StudioConfig.hasApiBackend) {
    return ApiStudioRepository(client: ref.watch(_sseClientProvider));
  }
  return InMemoryStudioRepository();
});

/// All studios (Study Studio Home).
final studioListProvider = FutureProvider<List<Studio>>((ref) {
  return ref.watch(studioRepositoryProvider).listStudios();
});

/// One studio by id (Dashboard, Topic Library, Progress).
final studioProvider = FutureProvider.family<Studio, String>((ref, studioId) {
  return ref.watch(studioRepositoryProvider).getStudio(studioId);
});

/// The signed-in user for the app chrome (profile + Octocredits). Reads `/me`
/// from the backend when configured; otherwise a local placeholder so the header
/// still renders in offline/mock mode. This is the auth starting point — swap
/// the placeholder for the real Octopilot/Firebase session.
final meProvider = FutureProvider<Me>((ref) async {
  if (StudioConfig.hasApiBackend) {
    return ApiAccount(client: ref.watch(_sseClientProvider)).me();
  }
  return const Me(
    id: StudioConfig.devUserId,
    displayName: 'Guest',
    credits: null,
  );
});

typedef TopicKey = ({String studioId, String topicId});

/// One Study Object by id (Topic Detail, Teach Me, etc.).
final topicProvider = FutureProvider.family<Topic, TopicKey>((ref, key) {
  return ref.watch(studioRepositoryProvider).getTopic(key.studioId, key.topicId);
});
