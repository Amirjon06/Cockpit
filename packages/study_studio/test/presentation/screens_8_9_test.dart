import 'package:cockpit_ui/cockpit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_studio/src/application/providers.dart';
import 'package:study_studio/src/data/mock/mock_data.dart';
import 'package:study_studio/src/domain/entities/studio.dart';
import 'package:study_studio/src/presentation/lightning_recall/lightning_recall_page.dart';
import 'package:study_studio/src/presentation/mastery_report/mastery_report_page.dart';

void main() {
  // A rich studio (topics with varied mastery + a quiz bank) to drive the two
  // screens. Taken from the stashed mock so the test stays independent of the
  // offline repository, which dev empties for backend testing.
  final Studio bio = buildMockStudiosStashed().firstWhere((s) => s.id == 'bio');

  Future<void> setPhoneViewport(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> setDesktopViewport(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1281, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  // Override studioProvider('bio') so both screens receive [bio] directly,
  // regardless of whether the offline repo or the API backend is configured.
  Widget app(Widget home) {
    return ProviderScope(
      overrides: [studioProvider('bio').overrideWith((ref) => bio)],
      child: MaterialApp(
        theme: CockpitTheme.build(
          colors: CockpitColors.brand,
          fonts: CockpitFonts.brand,
          brightness: Brightness.light,
        ),
        home: home,
      ),
    );
  }

  group('Screen 8 — AI Mastery Report', () {
    testWidgets('renders live studio data at a phone viewport', (tester) async {
      await setPhoneViewport(tester);
      await tester.pumpWidget(app(const MasteryReportPage(studioId: 'bio')));
      await tester.pumpAndSettle();

      expect(find.text('AI Mastery Report'), findsOneWidget);
      expect(find.text('Biology Midterm Studio'), findsOneWidget);
      expect(find.text('Exam Readiness'), findsOneWidget);
      // The weak-topic focus chip is a real topic (DNA Replication, mastery
      // 0.35) from the studio, proving the report reads live data, not a mock.
      expect(find.text('DNA Replication'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out without overflow at a desktop viewport', (
      tester,
    ) async {
      await setDesktopViewport(tester);
      await tester.pumpWidget(app(const MasteryReportPage(studioId: 'bio')));
      await tester.pumpAndSettle();

      expect(find.text('AI Mastery Report'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Screen 9 — Lightning Recall', () {
    // The countdown uses a periodic Timer, so avoid pumpAndSettle and dispose
    // the tree at the end to cancel it (otherwise the test fails on a pending
    // timer).
    Future<void> pumpRecall(WidgetTester tester) async {
      await tester.pumpWidget(app(const LightningRecallPage(studioId: 'bio')));
      await tester.pump(); // resolve the overridden studioProvider
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('renders the recall session at a phone viewport', (
      tester,
    ) async {
      await setPhoneViewport(tester);
      await pumpRecall(tester);

      expect(find.text('Lightning Recall'), findsWidgets);
      expect(find.text('Biology Midterm Studio'), findsOneWidget);
      expect(find.text('QUESTION'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox()); // dispose → cancel timer
    });

    testWidgets('lays out without overflow at a desktop viewport', (
      tester,
    ) async {
      await setDesktopViewport(tester);
      await pumpRecall(tester);

      expect(find.text('QUESTION'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox()); // dispose → cancel timer
    });
  });
}
