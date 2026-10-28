import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/services/alerts.dart';
import 'package:telos/services/lock_screen.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';

/// Notifications that refuse every call, as a platform might.
class _BrokenAlerts extends NoopAlerts {
  @override
  Future<void> init() async => throw StateError('init');
  @override
  Future<bool> requestPermission() async => throw StateError('permission');
  @override
  Future<void> scheduleReturn({
    required DateTime at,
    required String sector,
    required String squad,
  }) async =>
      throw StateError('schedule');
  @override
  Future<void> cancel() async => throw StateError('cancel');
}

class _BrokenLockScreen extends NoopLockScreen {
  @override
  Future<void> show({
    required DateTime startedAt,
    required DateTime endsAt,
    required String sector,
    required String designation,
    required int accent,
  }) async =>
      throw StateError('show');
  @override
  Future<void> clear() async => throw StateError('clear');
}

/// A store whose writes can be made to fail.
class _FlakyStore extends Persistence {
  bool fail = false;
  @override
  Future<void> save(GuildState state) async {
    if (fail) throw StateError('disk');
    await super.save(state);
  }
}

GuildController _broken(Persistence store) => GuildController(store,
    alerts: _BrokenAlerts(), lockScreen: _BrokenLockScreen());

Future<void> _send(GuildController c) => c.startRun(
    sectorId: 'mosswood', intent: 'Draft', squad: ['a1'], minutes: 25);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the app opens when notifications cannot start', () async {
    final c = _broken(Persistence());
    addTearDown(c.dispose);
    await c.boot();
    expect(c.ready, isTrue);
  });

  test('a squad goes out, and stays out after a relaunch, when its alert '
      'cannot be scheduled', () async {
    final c = _broken(Persistence());
    addTearDown(c.dispose);
    await c.boot();
    await _send(c);
    expect(c.hasActiveRun, isTrue);

    final next = _broken(Persistence());
    addTearDown(next.dispose);
    await next.boot();
    expect(next.g.active?.intent, 'Draft');
  });

  test('a finished run is banked when its alert cannot be cancelled',
      () async {
    final c = _broken(Persistence());
    addTearDown(c.dispose);
    await c.boot();
    c.g.active = ActiveRun(
        id: 'done',
        sectorId: 'mosswood',
        intent: '',
        squad: ['a1'],
        startedAt: DateTime.now().subtract(const Duration(minutes: 25)),
        plannedMinutes: 25);
    final record = await c.finishRun(recalled: false);
    expect(record, isNotNull);
    expect(c.g.log.single.id, 'done');
    expect(c.hasActiveRun, isFalse);
  });

  test('a run taken back is gone when its alert cannot be cancelled',
      () async {
    final c = _broken(Persistence());
    addTearDown(c.dispose);
    await c.boot();
    await _send(c);
    expect(await c.cancelRun(), isTrue);
    expect(c.hasActiveRun, isFalse);
  });

  test('a dispatch that cannot be saved leaves the squad at camp', () async {
    final store = _FlakyStore();
    final c = GuildController(store);
    addTearDown(c.dispose);
    await c.boot();
    final counter = c.g.runCounter;

    store.fail = true;
    await expectLater(_send(c), throwsStateError);
    expect(c.hasActiveRun, isFalse);
    expect(c.g.runCounter, counter);

    // And trying again once the disk is back works.
    store.fail = false;
    await _send(c);
    expect(c.hasActiveRun, isTrue);
    expect((await store.load()).active, isNotNull);
  });
}
