import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/main.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/services/backup.dart';
import 'package:telos/services/feedback_mail.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';
import 'package:telos/widgets/feedback_action.dart';

import 'support/archive_fixtures.dart' show archiveRecord;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'Telos',
        packageName: 'com.dahvio.telos',
        version: '0.1.0',
        buildNumber: '34',
        buildSignature: '');
  });

  Future<GuildController> boot() async {
    final c = GuildController(Persistence());
    await c.boot();
    c.g.onboarded = true;
    addTearDown(c.dispose);
    return c;
  }

  Future<void> run(GuildController c, {bool recalled = false}) async {
    await c.startRun(
        sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
    await c.finishRun(recalled: recalled);
    await c.dismissDebrief();
  }

  group('cancels and recalls are counted', () {
    test('a cancel leaves no log entry, but is counted', () async {
      final c = await boot();
      await c.startRun(
          sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
      expect(await c.cancelRun(), isTrue);
      expect(c.g.log, isEmpty);
      expect(c.g.cancelledRuns, 1);
    });

    test('a recall is counted, and a full run is not', () async {
      final c = await boot();
      await run(c, recalled: true);
      await run(c);
      expect(c.g.recalledRuns, 1);
      expect(c.g.expeditions, 2);
      expect(c.g.completedRuns, 1);
    });

    test('the counts survive a restart and a backup', () async {
      final c = await boot();
      await c.startRun(
          sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
      await c.cancelRun();
      await run(c, recalled: true);

      final again = GuildController(Persistence());
      await again.boot();
      addTearDown(again.dispose);
      expect(again.g.cancelledRuns, 1);
      expect(again.g.recalledRuns, 1);

      final restored = Backup.decode(Backup.encode(c.g))!;
      expect(restored.cancelledRuns, 1);
      expect(restored.recalledRuns, 1);
    });

    test('a save from before the count finds its recalls in the log', () {
      final g = GuildState.fresh()
        ..log.addAll([
          archiveRecord(id: 'r1', recalled: true),
          archiveRecord(id: 'r2'),
          archiveRecord(id: 'r3', recalled: true),
        ]);
      final json = g.toJson()
        ..remove('recalledRuns')
        ..remove('cancelledRuns')
        ..remove('feedbackAsked');
      final old = GuildState.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(old.recalledRuns, 2);
      expect(old.cancelledRuns, 0,
          reason: 'cancels were never recorded, so none can be found');
      expect(old.feedbackAsked, isFalse);
    });
  });

  group('camp asks for feedback once', () {
    test('after the third full expedition, not before', () async {
      final c = await boot();
      await c.declineMusic();
      await run(c);
      await run(c);
      await run(c, recalled: true);
      expect(c.offerFeedback, isFalse,
          reason: 'a recalled run is not a full expedition');
      await run(c);
      expect(c.offerFeedback, isTrue);
    });

    test('never alongside the music offer, or during a run', () async {
      final c = await boot();
      for (var i = 0; i < 3; i++) {
        await run(c);
      }
      expect(c.offerMusic, isTrue);
      expect(c.offerFeedback, isFalse, reason: 'one question at a time');
      await c.declineMusic();
      expect(c.offerFeedback, isTrue);
      await c.startRun(
          sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
      expect(c.offerFeedback, isFalse);
    });

    testWidgets('"No thanks" settles it, across a restart', (t) async {
      final c = await boot();
      await c.declineMusic();
      for (var i = 0; i < 3; i++) {
        await run(c);
      }
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(theme: T.theme(), home: const Root()),
      ));
      await t.pumpAndSettle();
      expect(find.text('Three expeditions in. How is it going?'),
          findsOneWidget);
      await t.tap(find.byKey(const Key('feedback-offer-no')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('feedback-offer')), findsNothing);

      final again = GuildController(Persistence());
      await again.boot();
      addTearDown(again.dispose);
      expect(again.offerFeedback, isFalse);
    });

    testWidgets('"Write an email" starts the draft and settles it too',
        (t) async {
      final c = await boot();
      await c.declineMusic();
      for (var i = 0; i < 3; i++) {
        await run(c);
      }
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(theme: T.theme(), home: const Root()),
      ));
      await t.pumpAndSettle();
      // A phone with no mail account: nothing can open the draft, so this
      // takes the copied-address path.
      const launcher = MethodChannel('plugins.flutter.io/url_launcher');
      t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(launcher, (_) async => false);
      addTearDown(() => t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(launcher, null));
      final copied = <String>[];
      t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await t.tap(find.byKey(const Key('feedback-offer-yes')));
      await t.pumpAndSettle();
      expect(copied, [FeedbackMail.address]);
      expect(find.textContaining('is copied'), findsOneWidget);
      expect(find.byKey(const Key('feedback-offer')), findsNothing);
      expect(c.g.feedbackAsked, isTrue);
    });
  });

  group('the email', () {
    test('ends with counts only, and says they can be deleted', () {
      final g = GuildState.fresh()
        ..guildName = 'The Long Watch'
        ..log.add(archiveRecord(intent: 'Write the grant report'))
        ..recalledRuns = 0
        ..cancelledRuns = 2
        ..openDays.addAll(['2026-11-01', '2026-11-02']);
      final usage = FeedbackMail.usageLine(g);
      expect(usage, '1 expedition · 0 recalled · 2 cancelled · opened on 2 days');
      final body = Uri.decodeComponent(FeedbackMail.draft(
              build: '0.1.0 (34)', os: 'iOS 26.1', usage: usage)
          .query);
      expect(body, contains(usage));
      expect(body, contains('Delete them if you would rather not'));
      expect(body, isNot(contains('The Long Watch')));
      expect(body, isNot(contains('grant report')));
    });

    testWidgets('carries the usage line when sent', (t) async {
      final c = await boot();
      await run(c);
      Uri? sent;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => sendFeedback(context, c.g, openMail: (uri) async {
                sent = uri;
                return true;
              }),
              child: const Text('send'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('send'));
      await t.pumpAndSettle();
      expect(Uri.decodeComponent(sent!.query),
          contains('1 expedition · 0 recalled · 0 cancelled'));
    });
  });
}
