import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'sse_client.dart';

/// Uploads study materials and waits for RAG ingestion.
///
/// Upload is a multipart POST (the documents endpoint returns a JSON job);
/// [watchBuild] then reads the build SSE stream, which stays open until the job
/// finishes — so the returned Future completes on `done` and throws on failure.
/// Everything binds to the authenticated user server-side.
class UploadApi {
  // ignore: prefer_initializing_formals — public name differs from field
  UploadApi({required SseClient sse}) : _sse = sse;

  final SseClient _sse;

  /// Uploads [bytes] as a document under [studioId]; returns the ingest job id.
  Future<String> uploadDocument({
    required String studioId,
    required String filename,
    required Uint8List bytes,
  }) async {
    final headers = await _sse.authHeaders()
      ..remove('Accept'); // the upload response is JSON, not an event stream
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${_sse.baseUrl}/studios/$studioId/documents'),
    )
      ..headers.addAll(headers)
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

    final resp = await http.Response.fromStream(await req.send());
    if (resp.statusCode >= 400) {
      throw SseException('Upload failed: HTTP ${resp.statusCode}');
    }
    final job = jsonDecode(resp.body) as Map<String, dynamic>;
    return job['id'] as String;
  }

  /// Completes when ingestion finishes; throws [SseException] if it fails.
  Future<void> watchBuild({
    required String studioId,
    required String jobId,
  }) async {
    await _sse.get('/studios/$studioId/build/$jobId');
  }

  /// Kick off the studio-level generation pass over ALL uploaded files; returns
  /// the build id. Runs in the background — poll [buildSnapshot] for progress.
  Future<String> startBuild({required String studioId}) async {
    final events = await _sse.post('/studios/$studioId/build');
    final data = events.firstWhere(
      (e) => e.event == 'data',
      orElse: () => throw SseException('Build did not start'),
    );
    return data.data['buildId'] as String;
  }

  /// One-shot current build state — the dashboard polls this for a live banner.
  Future<BuildSnapshot> buildSnapshot({
    required String studioId,
    required String buildId,
  }) async {
    final events = await _sse.get(
      '/studios/$studioId/build-status/$buildId',
      query: {'snapshot': '1'},
    );
    final p = events.firstWhere(
      (e) => e.event == 'progress',
      orElse: () => throw SseException('No build status'),
    );
    final d = p.data;
    return BuildSnapshot(
      status: d['status'] as String? ?? 'queued',
      stage: d['stage'] as String? ?? '',
      lessonsDone: (d['lessonsDone'] as num?)?.toInt() ?? 0,
      lessonsTotal: (d['lessonsTotal'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A snapshot of a studio build's progress.
class BuildSnapshot {
  const BuildSnapshot({
    required this.status,
    required this.stage,
    required this.lessonsDone,
    required this.lessonsTotal,
  });

  final String status; // queued|extracting|generating|scenarios|done|failed
  final String stage;
  final int lessonsDone;
  final int lessonsTotal;

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get inProgress => !isDone && !isFailed;
}
