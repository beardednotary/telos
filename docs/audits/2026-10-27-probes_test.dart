// Audit evidence for commit 627ebc7. These assertions confirm observed defects;
// they are NOT regression expectations for a fixed app. Run explicitly with:
// flutter test --no-pub docs/audits/2026-10-27-probes_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/data/content.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/services/alerts.dart';
import 'package:telos/services/backup.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import '../../test/support/archive_fixtures.dart';

class AuditStore extends Persistence {
  GuildState saved = GuildState.fresh();
  @override
  Future<GuildState> load() async => GuildState.fromJson(saved.toJson());
  @override
  Future<void> save(GuildState state) async {
    saved = GuildState.fromJson(jsonDecode(jsonEncode(state.toJson())));
  }
}

class AuditAlerts extends NoopAlerts {
  bool failInit = false;
  bool failSchedule = false;
  bool failCancel = false;
  int schedules = 0;
  @override
  Future<void> init() async {
    if (failInit) throw StateError('Simulated platform initialization error');
  }
  @override
  Future<void> scheduleReturn({required DateTime at, required String sector,
      required String squad}) async {
    schedules++;
    if (failSchedule) throw StateError('Simulated platform scheduling error');
  }
  @override
  Future<void> cancel() async {
    if (failCancel) throw StateError('Simulated platform cancellation error');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('audit: boot overwrites the original corrupt save', () async {
    const raw = '{"guildName":"Established Guild",broken';
    SharedPreferences.setMockInitialValues({'telos.save.v1': raw});
    final c = GuildController(Persistence());
    addTearDown(c.dispose);
    await c.boot();
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('telos.save.v1'), isNot(raw));
    expect(c.g.guildName, GuildState.fresh().guildName);
  });

  test('audit: notification error leaves an unsaved active run and blocks retry', () async {
    final store = AuditStore();
    final alerts = AuditAlerts();
    final c = GuildController(store, alerts: alerts);
    addTearDown(c.dispose);
    await c.boot();
    alerts.failSchedule = true;
    await expectLater(c.startRun(sectorId: 'mosswood', intent: '', squad: ['a1'],
        minutes: 25), throwsStateError);
    expect(c.hasActiveRun, isTrue);
    expect(store.saved.active, isNull);
    await c.startRun(sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
    expect(alerts.schedules, 1);
    expect(store.saved.active, isNull);
  });

  test('audit: notification initialization error prevents app readiness', () async {
    final c = GuildController(AuditStore(), alerts: AuditAlerts()..failInit = true);
    addTearDown(c.dispose);
    await expectLater(c.boot(), throwsStateError);
    expect(c.ready, isFalse);
  });

  test('audit: notification cancellation error prevents banking a completed run', () async {
    final alerts = AuditAlerts();
    final c = GuildController(AuditStore(), alerts: alerts);
    addTearDown(c.dispose);
    await c.boot();
    c.g.active = ActiveRun(id: 'complete', sectorId: 'mosswood', intent: '',
        squad: ['a1'], startedAt: DateTime.now().subtract(const Duration(minutes: 25)),
        plannedMinutes: 25);
    alerts.failCancel = true;
    await expectLater(c.finishRun(recalled: false), throwsStateError);
    expect(c.g.log, isEmpty);
    expect(c.hasActiveRun, isTrue);
  });

  test('audit: history cap removes earned Spire progress', () async {
    final c = GuildController(AuditStore());
    addTearDown(c.dispose);
    await c.boot();
    c.g.log = List.generate(500, (i) => archiveRecord(id: 'r$i'));
    c.g.spireCompletedAt = DateTime(2026, 1, 1);
    c.g.spireCompletionMinutes = 11300;
    expect(c.g.totalFocusMinutes, 12500);
    expect(c.g.spireFloors, 1);
    c.g.active = ActiveRun(id: 'next', sectorId: 'mosswood', intent: '',
        squad: ['a1'], startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        plannedMinutes: 10);
    await c.finishRun(recalled: false);
    expect(c.g.log.length, 500);
    expect(c.g.totalFocusMinutes, 12485);
    expect(c.g.spireFloors, 0);
  });

  test('audit: backup accepts unknown gear that crashes content lookup', () {
    final g = GuildState.fresh();
    g.vault.add(Gear('bad', 'nonexistent-content'));
    g.roster.first.equipped.add('bad');
    final decoded = Backup.decode(Backup.encode(g));
    expect(decoded, isNotNull);
    expect(decoded!.vault.single.defId, 'nonexistent-content');
    expect(() => gearById(decoded.vault.single.defId), throwsA(isA<TypeError>()));
  });
}
