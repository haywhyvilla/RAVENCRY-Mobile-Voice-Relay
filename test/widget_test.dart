import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_relay/main.dart';

void main() {
  testWidgets('requires language and consent before voice capture', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const VoiceRelayApp());

    expect(find.text('RAVENCRY'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(
      find.text('If you are in immediate danger, call 112.'),
      findsOneWidget,
    );

    final continueLabel = find.text('Continue to voice capture');
    await tester.scrollUntilVisible(continueLabel, 200);
    await tester.tap(continueLabel);
    await tester.pumpAndSettle();
    expect(find.text('Voice capture'), findsNothing);

    final hausaLabel = find.text('Hausa');
    await tester.scrollUntilVisible(hausaLabel, -200);
    await tester.tap(hausaLabel);
    await tester.pump();

    final consentLabel = find.text(
      'I understand that a human reviews reports before any action is taken.',
    );
    await tester.scrollUntilVisible(consentLabel, 200);
    await tester.tap(consentLabel);
    await tester.pump();

    expect(find.text('Hausa'), findsOneWidget);
    await tester.scrollUntilVisible(continueLabel, 200);
    await tester.tap(continueLabel);
    await tester.pumpAndSettle();

    expect(find.text('Voice capture'), findsOneWidget);
    expect(find.textContaining('Record locally in Hausa'), findsOneWidget);

    await tester.tap(find.text('Use text instead'));
    await tester.pumpAndSettle();
    expect(find.text('Text-only report'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('text-fallback-field')),
      'I saw someone near the market.',
    );
    final prepareButton = find.byKey(const Key('prepare-text-response'));
    await tester.ensureVisible(prepareButton);
    await tester.pumpAndSettle();
    await tester.tap(prepareButton);
    await tester.pump();

    expect(find.text('Text response ready'), findsOneWidget);

    final reviewButton = find.byKey(const Key('review-fixture'));
    await tester.scrollUntilVisible(
      reviewButton,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();

    expect(find.text('Not sent yet'), findsOneWidget);
    expect(
      find.text(
        'Na ga Fatima Bello, yarinya mai shekara bakwai, kusa da Kasuwar Sabon Gari a Kano da misalin karfe tara na safe.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'I saw Fatima Bello, a seven-year-old girl, near Sabon Gari Market in Kano at about nine in the morning.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sabon Gari Market, Kano'), findsOneWidget);
    expect(find.text('20 July 2026, 08:15 WAT'), findsOneWidget);
    expect(find.text('Hausa (ha)'), findsNWidgets(2));

    final queueButton = find.byKey(const Key('queue-report'));
    await tester.scrollUntilVisible(
      queueButton,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(queueButton);
    await tester.pumpAndSettle();

    expect(find.text('Outbox'), findsOneWidget);
    expect(find.text('Queued for human review'), findsOneWidget);
    expect(await LocalOutboxStore().loadReports(), hasLength(1));

    final trySendingButton = find.byKey(
      const Key('try-sending-demo-voice-001'),
    );
    await tester.scrollUntilVisible(
      trySendingButton,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(trySendingButton);
    await tester.pumpAndSettle();

    expect(find.text('DEMO-VOICE-001'), findsOneWidget);
    expect(find.text('Status: queued_for_human_review'), findsOneWidget);
    expect(
      find.text(
        'Saved for human review. This demo has not contacted emergency services.',
      ),
      findsOneWidget,
    );
    expect((await LocalOutboxStore().loadReports()).single.status, 'queued');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(const VoiceRelayApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-outbox')));
    await tester.pumpAndSettle();

    expect(find.text('Queued for human review'), findsOneWidget);
    expect(find.text('Sabon Gari Market, Kano'), findsOneWidget);
  });
}
