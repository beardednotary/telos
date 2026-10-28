import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/screens/backup_screen.dart';
import 'package:telos/screens/privacy_screen.dart';
import 'package:telos/services/feedback_mail.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/services/privacy_policy.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';

import 'support/archive_fixtures.dart';

PrivacyPolicy _policy() =>
    PrivacyPolicy.parse(File(PrivacyPolicy.asset).readAsStringSync());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the hosted page says exactly what the app says', () {
    // Re-run tool/privacy_page.py after editing the policy.
    final html = File('docs/privacy/index.html').readAsStringSync();
    final page = html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
    final policy = _policy();
    for (final line in [
      policy.title,
      policy.effective,
      for (final b in policy.blocks) ...b.lines,
    ]) {
      expect(page.contains(line), isTrue, reason: 'Not on the page: $line');
    }
    // A privacy page that loads a font or a script from elsewhere would
    // contradict itself.
    expect(html.contains(RegExp(r'''(src|href)=["']https?:''')), isFalse);
  });

  test('the policy names the address the app sends feedback to', () {
    final policy = _policy();
    expect(policy.blocks.where((b) => b.kind == PolicyBlockKind.heading),
        isNotEmpty);
    expect(policy.blocks.expand((b) => b.lines).join(' '),
        contains(FeedbackMail.address));
  });

  test('the feedback draft reads cleanly in Mail', () {
    final uri = FeedbackMail.draft(build: '0.1.0 (32)', os: 'iOS 18.1');
    expect(uri.scheme, 'mailto');
    expect(uri.path, FeedbackMail.address);
    // Spaces as %20: iOS Mail shows a "+" literally.
    expect(uri.query, isNot(contains('+')));
    final body = Uri.decodeComponent(uri.query.split('body=').last);
    for (final q in FeedbackMail.questions) {
      expect(body, contains(q));
    }
    expect(body, contains('Telos 0.1.0 (32) · iOS 18.1'));
  });

  group('settings', () {
    setUp(() => PackageInfo.setMockInitialValues(
        appName: 'Telos',
        packageName: 'com.dahvio.telos',
        version: '0.1.0',
        buildNumber: '32',
        buildSignature: ''));

    Future<GuildController> boot() async {
      final c = GuildController(Persistence());
      await c.boot();
      c.g.onboarded = true;
      addTearDown(c.dispose);
      return c;
    }

    Future<void> mount(WidgetTester t, GuildController c, Widget screen) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(theme: T.theme(), home: screen),
      ));
      await t.pumpAndSettle();
    }

    Future<void> tap(WidgetTester t, Finder finder) async {
      if (finder.evaluate().isEmpty) {
        await t.scrollUntilVisible(finder, 180,
            scrollable: find.byType(Scrollable).last);
      }
      await t.ensureVisible(finder);
      await t.pumpAndSettle();
      await t.tap(finder);
      await t.pumpAndSettle();
    }

    testWidgets('the whole policy is readable from Settings', (t) async {
      final c = await boot();
      await mount(t, c, BackupScreen(files: MemoryBackupFiles()));
      await tap(t, find.text('Help & about'));
      await tap(t, find.byKey(const Key('settings-privacy')));
      expect(find.byType(PrivacyScreen), findsOneWidget);
      expect(find.text(_policy().title), findsOneWidget);
      await tap(t, find.text('Contact'));
      expect(t.takeException(), isNull);
    });

    testWidgets('feedback opens a draft to the right address', (t) async {
      final c = await boot();
      final sent = <Uri>[];
      await mount(
          t,
          c,
          BackupScreen(
            files: MemoryBackupFiles(),
            openMail: (uri) async {
              sent.add(uri);
              return true;
            },
          ));
      await tap(t, find.text('Help & about'));
      await tap(t, find.byKey(const Key('settings-feedback')));
      expect(sent.single.path, FeedbackMail.address);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('with no mail account, the address is copied instead',
        (t) async {
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
      final c = await boot();
      await mount(
          t,
          c,
          BackupScreen(
            files: MemoryBackupFiles(),
            openMail: (_) async => false,
          ));
      await tap(t, find.text('Help & about'));
      await tap(t, find.byKey(const Key('settings-feedback')));
      expect(copied, [FeedbackMail.address]);
      expect(find.textContaining('is copied'), findsOneWidget);
    });
  });
}
