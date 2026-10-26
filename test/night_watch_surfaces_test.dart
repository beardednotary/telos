import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/data/content.dart';
import 'package:telos/models/models.dart';
import 'package:telos/screens/spire_screen.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';
import 'package:telos/widgets/camp_controls.dart';
import 'package:telos/widgets/contract_board.dart';
import 'package:telos/widgets/run_card.dart';

import 'support/archive_fixtures.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GuildController> boot() async {
    final c = GuildController(Persistence());
    await c.boot();
    c.g.onboarded = true;
    addTearDown(c.dispose);
    return c;
  }

  Future<void> mount(WidgetTester t, GuildController c, Widget screen) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(
        theme: T.theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: screen,
      ),
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

  testWidgets('orders reveal one reward at a time and pay a claim exactly once',
      (t) async {
    final c = await boot();
    c.g.contracts
      ..clear()
      ..addAll(standingOrders());
    final before = (c.g.credits, c.g.alloy, c.g.intel, c.g.xp);
    await mount(
        t,
        c,
        Scaffold(
            body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [ContractBoardPanel()],
        )));
    await tap(t, find.text('Run Blackstone Hollow 3 times'));
    expect(find.text('Claim rewards'), findsNothing);
    expect(find.text('Progress is recorded when an expedition returns.'),
        findsOneWidget);
    await tap(t, find.text('Finish 3 runs at full Integrity'));
    expect(
        t
            .widgetList<CampDisclosure>(find.byType(CampDisclosure))
            .where((w) => w.expanded)
            .length,
        1);
    final claim = find.byKey(const Key('claim-order-ready'));
    await t.ensureVisible(claim);
    await t.pumpAndSettle();
    final button = t.widget<TextButton>(
        find.descendant(of: claim, matching: find.byType(TextButton)));
    button.onPressed!();
    button.onPressed!();
    await t.pumpAndSettle();
    expect((c.g.credits, c.g.alloy, c.g.intel, c.g.xp),
        (before.$1 + 120, before.$2 + 25, before.$3 + 8, before.$4 + 35));
    expect(c.g.contracts.any((order) => order.id == 'order-ready'), isFalse);
    expect(c.g.contracts.length, 3);
    final restored = await boot();
    expect(restored.g.credits, c.g.credits);
    expect(restored.g.contracts.any((order) => order.id == 'order-ready'),
        isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Spire keeps the signed charter and recorded contribution read-only',
      (t) async {
    final c = await boot();
    c.g.guildName = 'The Renamed Company';
    c.g.spireCharterName = 'The Original Lantern';
    c.g.spireCompletedAt = DateTime(2026, 3, 1);
    c.g.spireCompletionMinutes = 0;
    c.g.log.add(RunRecord.fromJson(
        archiveRecord().toJson()..['elapsedSeconds'] = 1000 * 60 * 60));
    final before = jsonEncode(c.g.toJson());
    expect(c.g.spireFloors, 50);
    await mount(t, c, const SpireScreen());
    await t.scrollUntilVisible(find.text('50 floors'), 180);
    await t.pumpAndSettle();
    expect(find.text('50 floors'), findsOneWidget);
    await tap(t, find.text('The Last Charter'));
    expect(find.text('The Original Lantern'), findsOneWidget);
    expect(find.text('The Renamed Company'), findsNothing);
    await t.ensureVisible(find.textContaining('One floor for every'));
    await t.pumpAndSettle();
    expect(find.textContaining('It does not decay'), findsOneWidget);
    expect(jsonEncode(c.g.toJson()), before);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'sharing previews a fixed card without private task or reflection text',
      (t) async {
    final c = await boot();
    final rec = archiveRecord(recalled: true);
    final card = RunCard(
        record: rec,
        sector: sectorById(rec.sectorId),
        guildName: 'The Company of the Very Long Guild Name',
        depths: const [.5, .8, 1],
        floors: 0,
        status: 'RECALLED');
    await mount(
        t,
        c,
        Scaffold(
            body: Builder(
                builder: (context) => Center(
                    child: CampButton(
                        label: 'Preview',
                        onPressed: () => showRunCard(context, card))))));
    await tap(t, find.text('Preview'));
    expect(t.getSize(find.byType(RunCard)), RunCard.size);
    expect(find.text('45s'), findsOneWidget);
    expect(find.text('Recalled'), findsOneWidget);
    expect(find.text(rec.intent), findsNothing);
    expect(find.text(rec.note!), findsNothing);
    expect(
        find.text(
            'Shares your guild and expedition stats. Task notes stay private.'),
        findsOneWidget);
    expect(t.takeException(), isNull);
    await tap(t, find.text('Close preview'));
    expect(find.byType(RunCard), findsNothing);
    expect(t.takeException(), isNull);
  });
}
