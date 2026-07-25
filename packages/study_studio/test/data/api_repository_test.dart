import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_studio/src/data/api/api_ai_service.dart';
import 'package:study_studio/src/data/api/api_studio_repository.dart';
import 'package:study_studio/src/data/api/sse_client.dart';
import 'package:study_studio/src/domain/entities/flashcard.dart';
import 'package:study_studio/src/domain/entities/topic.dart';

/// Validates the Flutter SSE client parses the backend's `text/event-stream`
/// format (event:/data: lines) and maps camelCase JSON into domain entities —
/// the wire contract with Backend/. No live server needed.

http.Response _sse(String body) => http.Response(
      body,
      200,
      headers: {'content-type': 'text/event-stream'},
    );

void main() {
  test('listStudios parses item events into Studios', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/studios');
      expect(req.headers['X-User-Id'], isNotNull);
      return _sse(
        'event: item\n'
        'data: {"id":"bio","title":"Biology Midterm Studio","subject":"Biology",'
        '"createdAt":"2026-07-20T00:00:00Z","updatedAt":"2026-07-20T00:00:00Z",'
        '"topics":[]}\n\n'
        'event: item\n'
        'data: {"id":"mbr","title":"MBR Training Studio","subject":"Baggage",'
        '"createdAt":"2026-07-20T00:00:00Z","updatedAt":"2026-07-20T00:00:00Z",'
        '"topics":[]}\n\n'
        'event: done\n'
        'data: {}\n\n',
      );
    });
    final repo = ApiStudioRepository(client: SseClient(client: mock));

    final studios = await repo.listStudios();

    expect(studios.map((s) => s.id), ['bio', 'mbr']);
    expect(studios.first.title, 'Biology Midterm Studio');
  });

  test('getStudio parses nested topics + flashcards with enum-by-name',
      () async {
    final mock = MockClient((req) async {
      return _sse(
        'event: data\n'
        'data: {"id":"bio","title":"Bio","subject":"Biology",'
        '"createdAt":"2026-07-20T00:00:00Z","updatedAt":"2026-07-20T00:00:00Z",'
        '"topics":[{"id":"bio_dna","studioId":"bio","title":"DNA Replication",'
        '"subject":"Biology","definition":"d","simpleExplanation":"s",'
        '"detailedExplanation":"x","whyItMatters":"w","mastery":0.72,'
        '"flashcards":[{"id":"fc1","topicId":"bio_dna","front":"f","back":"b",'
        '"type":"process","status":"review"}]}]}\n\n'
        'event: done\ndata: {}\n\n',
      );
    });
    final repo = ApiStudioRepository(client: SseClient(client: mock));

    final studio = await repo.getStudio('bio');

    expect(studio.topics.single.title, 'DNA Replication');
    expect(studio.topics.single.mastery, closeTo(0.72, 1e-9));
    final card = studio.topics.single.flashcards.single;
    expect(card.type, FlashcardType.process);
    expect(card.status, FlashcardStatus.review);
  });

  test('getStudio throws on an error event', () async {
    final mock = MockClient((req) async =>
        _sse('event: error\ndata: {"message":"Studio x not found"}\n\n'));
    final repo = ApiStudioRepository(client: SseClient(client: mock));

    expect(() => repo.getStudio('x'), throwsA(isA<SseException>()));
  });

  test('teach concatenates delta events into the answer', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/ask');
      expect(req.url.queryParameters['studio_id'], 'bio');
      return _sse(
        'event: delta\ndata: {"text":"Hello "}\n\n'
        'event: delta\ndata: {"text":"world"}\n\n'
        'event: meta\ndata: {"model":"test"}\n\n'
        'event: done\ndata: {}\n\n',
      );
    });
    final ai = ApiAiService(client: SseClient(client: mock));

    final answer = await ai.teach(topic: _topic(), message: 'hi');
    expect(answer, 'Hello world');
  });
}

Topic _topic() => const Topic(
      id: 'bio_dna',
      studioId: 'bio',
      title: 'DNA Replication',
      subject: 'Biology',
      definition: 'd',
      simpleExplanation: 's',
      detailedExplanation: 'x',
      whyItMatters: 'w',
    );
