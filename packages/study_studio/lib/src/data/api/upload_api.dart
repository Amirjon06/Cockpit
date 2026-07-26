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
}
