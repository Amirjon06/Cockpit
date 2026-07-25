import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/config.dart';

/// One parsed Server-Sent Event.
class SseEvent {
  const SseEvent(this.event, this.data);

  final String event;
  final Map<String, dynamic> data;
}

/// Minimal SSE client for the Study Studio backend.
///
/// The backend speaks `text/event-stream` for everything. Since the module's
/// repository/AI interfaces are `Future`-based (not streams), we read the whole
/// response body and parse the events — simple and cross-platform (web + io)
/// with just `package:http`. Switch to an incremental reader if the UI later
/// wants token-by-token rendering.
class SseClient {
  SseClient({
    http.Client? client,
    String? baseUrl,
    String? userId,
    Future<String?> Function()? tokenProvider,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? StudioConfig.apiBaseUrl,
        _userId = userId ?? StudioConfig.devUserId,
        // ignore: prefer_initializing_formals — public name differs from field
        _tokenProvider = tokenProvider;

  final http.Client _client;
  final String _baseUrl;
  final String _userId;

  /// Supplies the Firebase ID token when signed in; null falls back to the dev
  /// X-User-Id header.
  final Future<String?> Function()? _tokenProvider;

  Future<Map<String, String>> _headers() async {
    final token = await _tokenProvider?.call();
    return {
      'Accept': 'text/event-stream',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token'
      else
        'X-User-Id': _userId,
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        for (final e in query.entries) e.key: '${e.value}',
      },
    );
  }

  Future<List<SseEvent>> get(String path, {Map<String, dynamic>? query}) async {
    final resp = await _client.get(_uri(path, query), headers: await _headers());
    return _parse(resp);
  }

  Future<List<SseEvent>> post(String path, {Map<String, dynamic>? query}) async {
    final resp =
        await _client.post(_uri(path, query), headers: await _headers());
    return _parse(resp);
  }

  List<SseEvent> _parse(http.Response resp) {
    if (resp.statusCode >= 400) {
      throw SseException('HTTP ${resp.statusCode} for ${resp.request?.url}');
    }
    final events = <SseEvent>[];
    String? name;
    final dataLines = <String>[];

    void flush() {
      if (dataLines.isEmpty) return;
      final raw = dataLines.join('\n');
      dataLines.clear();
      final ev = name ?? 'message';
      name = null;
      Map<String, dynamic> parsed;
      try {
        final decoded = jsonDecode(raw);
        parsed = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{'value': decoded};
      } catch (_) {
        parsed = <String, dynamic>{'raw': raw};
      }
      events.add(SseEvent(ev, parsed));
    }

    for (final line in const LineSplitter().convert(resp.body)) {
      if (line.isEmpty) {
        flush();
      } else if (line.startsWith('event:')) {
        name = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
      // ':' comment / keep-alive lines are ignored.
    }
    flush();

    final err = events.where((e) => e.event == 'error');
    if (err.isNotEmpty) {
      throw SseException('${err.first.data['message'] ?? 'stream error'}');
    }
    return events;
  }

  void close() => _client.close();
}

class SseException implements Exception {
  SseException(this.message);
  final String message;
  @override
  String toString() => 'SseException: $message';
}
