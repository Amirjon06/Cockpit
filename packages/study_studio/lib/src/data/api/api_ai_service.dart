import '../../domain/entities/topic.dart';
import '../ai/ai_service.dart';
import 'sse_client.dart';

/// [AiService] backed by the backend `/ask` SSE stream. Concatenates the streamed
/// `delta` events into the final grounded answer (the interface is Future-based;
/// swap to a Stream when the UI wants token-by-token rendering).
class ApiAiService implements AiService {
  ApiAiService({SseClient? client}) : _sse = client ?? SseClient();

  final SseClient _sse;

  @override
  Future<String> teach({required Topic topic, required String message}) async {
    final events = await _sse.get(
      '/ask',
      query: {'studio_id': topic.studioId, 'q': message},
    );
    final buffer = StringBuffer();
    for (final e in events.where((e) => e.event == 'delta')) {
      buffer.write(e.data['text'] ?? '');
    }
    return buffer.toString().trim();
  }
}
