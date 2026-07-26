import 'package:cockpit_ui/cockpit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_studio/src/presentation/lightning_recall/lightning_recall_page.dart';
import 'package:study_studio/src/presentation/mastery_report/mastery_report_page.dart';

void main() {
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

  Widget app(Widget home) {
    return ProviderScope(
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

  // Both screens read the seeded 'bio' studio (Biology Midterm Studio) through
  // studioProvider, so the assertions below exercise real repository data.

  group('Screen 8 — AI Mastery Report', () {
    testWidgets('renders live studio data at a phone viewport', (tester) async {
      await setPhoneViewport(tester);
      await tester.pumpWidget(app(const MasteryReportPage(studioId: 'bio')));
      await tester.pumpAndSettle();

      expect(find.text('AI Mastery Report'), findsOneWidget);
      expect(find.text('Biology Midterm Studio'), findsOneWidget);
      expect(find.text('Exam Readiness'), findsOneWidget);
      // The weak-topic focus chip is a real seeded topic (DNA Replication,
      // mastery 0.35), proving the report reads live studio data, not a mock.
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
      await tester.pump(); // resolve the studioProvider future
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
