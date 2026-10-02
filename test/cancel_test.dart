import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';

import 'alerts_test.dart' show FakeAlerts;

void main() {
  late FakeAlerts alerts;
  late GuildController c;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    alerts = FakeAlerts();
    c = GuildController(Persistence(), alerts: alerts);
    await c.boot();
  });

  tearDown(() => c.dispose());

  Future<void> dispatch() => c.startRun(
        sectorId: 'mosswood',
        intent: 'wrong pick',
        squad: ['a1'],
        minutes: 25,
      );

  test('a run cancelled straight after dispatch leaves no trace', () async {
    final before = c.g.runCounter;
    await dispatch();
    expect(c.canCancel(DateTime.now()), isTrue);

    expect(await c.cancelRun(), isTrue);
    expect(c.hasActiveRun, isFalse);
    expect(c.pendingDebrief, isNull);
    expect(c.g.log, isEmpty);
    expect(c.g.runCounter, before);
    expect(c.g.surveyRead, isEmpty);
    expect(alerts.cancels, 1);
  });

  test('the cancel window closes, and recall is the only way out after',
      () async {
    await dispatch();
    final started = c.active!.startedAt;
    expect(c.canCancel(started.add(const Duration(seconds: 29))), isTrue);
    expect(c.canCancel(started.add(GuildController.cancelWindow)), isFalse);
  });

  test('coming back from the background on a new day counts the day',
      () async {
    c.g.openDays.clear();
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(c.g.openDays, hasLength(1));
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(c.g.openDays, hasLength(1));
  });
}
