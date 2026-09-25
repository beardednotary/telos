import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/models/models.dart';
import 'package:telos/services/lock_screen.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';

/// Records what the controller asked the lock screen for, so the wiring can
/// be asserted without a platform channel.
class FakeLockScreen implements LockScreen {
  final List<DateTime> shownUntil = [];
  int clears = 0;
  DateTime? lastStartedAt;
  String? lastSector;
  String? lastDesignation;
  int? lastAccent;

  @override
  Future<void> show({
    required DateTime startedAt,
    required DateTime endsAt,
    required String sector,
    required String designation,
    required int accent,
  }) async {
    shownUntil.add(endsAt);
    lastStartedAt = startedAt;
    lastSector = sector;
    lastDesignation = designation;
    lastAccent = accent;
  }

  @override
  Future<void> clear() async => clears++;
}

void main() {
  late FakeLockScreen lock;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    lock = FakeLockScreen();
  });

  test('dispatching puts the run on the lock screen', () async {
    final c = GuildController(Persistence(), lockScreen: lock);
    await c.boot();
    expect(lock.shownUntil, isEmpty);

    await c.startRun(
      sectorId: 'mosswood',
      intent: 'write the README',
      squad: ['a1'],
      minutes: 25,
    );

    expect(lock.shownUntil.single, c.active!.endsAt);
    expect(lock.lastStartedAt, c.active!.startedAt);
    expect(lock.lastSector, 'MOSSWOOD VERGE');
    expect(lock.lastDesignation, 'SECTOR 01');
    expect(lock.lastAccent, 0xFF8FD694);
    c.dispose();
  });

  test('finishing a run takes it off the lock screen', () async {
    final c = GuildController(Persistence(), lockScreen: lock);
    await c.boot();
    await c.startRun(
      sectorId: 'mosswood',
      intent: '',
      squad: ['a1'],
      minutes: 25,
    );
    final before = lock.clears;

    await c.finishRun(recalled: true);
    expect(lock.clears, before + 1);
    c.dispose();
  });

  test('a live run is put back on the lock screen on cold start', () async {
    final first = GuildController(Persistence(), lockScreen: FakeLockScreen());
    await first.boot();
    await first.startRun(
      sectorId: 'mosswood',
      intent: 'still going',
      squad: ['a1'],
      minutes: 45,
    );
    final endsAt = first.active!.endsAt;
    first.dispose();

    final second = GuildController(Persistence(), lockScreen: lock);
    await second.boot();
    expect(lock.shownUntil.single, endsAt);
    expect(lock.clears, 0);
    second.dispose();
  });

  test('a run that ended while closed is cleared, not shown, on cold start',
      () async {
    final first = GuildController(Persistence(), lockScreen: FakeLockScreen());
    await first.boot();
    await first.startRun(
      sectorId: 'mosswood',
      intent: 'finished while closed',
      squad: ['a1'],
      minutes: 30,
    );
    // Rewind the run so it is already over, and persist that.
    first.g.active = ActiveRun(
      id: 'old',
      sectorId: 'mosswood',
      intent: 'finished while closed',
      squad: ['a1'],
      startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      plannedMinutes: 30,
    );
    await first.renameGuild('THE SILVER LANTERN'); // forces a save
    first.dispose();

    final second = GuildController(Persistence(), lockScreen: lock);
    await second.boot();
    expect(second.hasActiveRun, isTrue); // still waiting on its debrief
    expect(lock.shownUntil, isEmpty);
    expect(lock.clears, 1);
    second.dispose();
  });

  test('a hard reset clears the lock screen', () async {
    final c = GuildController(Persistence(), lockScreen: lock);
    await c.boot();
    await c.startRun(
      sectorId: 'mosswood',
      intent: '',
      squad: ['a1'],
      minutes: 25,
    );
    final before = lock.clears;

    await c.hardReset();
    expect(lock.clears, before + 1);
    c.dispose();
  });
}
