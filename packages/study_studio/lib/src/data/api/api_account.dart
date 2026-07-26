import '../../domain/entities/me.dart';
import 'dto_mappers.dart';
import 'sse_client.dart';

/// Reads the signed-in user (identity + Octocredits) from the backend `/me`
/// SSE endpoint. The start of auth — identity/credits come from Octopilot.
class ApiAccount {
  ApiAccount({SseClient? client}) : _sse = client ?? SseClient();

  final SseClient _sse;

  Future<Me> me() async {
    final events = await _sse.get('/me');
    final data = events.firstWhere(
      (e) => e.event == 'data',
      orElse: () => throw SseException('No /me payload'),
    );
    return meFromJson(data.data);
  }
}
