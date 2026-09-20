import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/models/models.dart';
import 'package:telos/services/alerts.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';

/// Records what the controller asked for, so the wiring can be asserted
/// without touching a platform channel.
class FakeAlerts implements Alerts {
  int inits = 0;
  int permissionAsks = 0;
  int cancels = 0;
  final List<DateTime> scheduledFor = [];
  String? lastSector;
  String? lastSquad;

  @override
  Future<void> init() async => inits++;

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return true;
  }

  @override
  Future<void> scheduleReturn({
    required DateTime at,
    required String sector,
    required String squad,
  }) async {
    scheduledFor.add(at);
    lastSector = sector;
    lastSquad = squad;
  }

  @override
  Future<void> cancel() async => cancels++;
}

void main() {
  late FakeAlerts alerts;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    alerts = FakeAlerts();
  });

  test('dispatching asks for permission, then schedules for the end of the run',
      () async {
    final c = GuildController(Persistence(), alerts: alerts);
    await c.boot();
    expect(alerts.inits, 1);
    expect(alerts.scheduledFor, isEmpty); // nothing live, nothing scheduled

    await c.startRun(
      sectorId: 'mosswood',
      intent: 'write the README',
      squad: ['a1'],
      minutes: 25,
    );

    expect(alerts.permissionAsks, 1);
    expect(alerts.scheduledFor.single, c.active!.endsAt);
    expect(alerts.lastSector, 'MOSSWOOD VERGE');
    expect(alerts.lastSquad, 'KAEL');
    c.dispose();
  });

  test('the alert names the whole squad', () async {
    final c = GuildController(Persistence(), alerts: alerts);
    await c.boot();
    c.g.level = 3; // two squad slots
    await c.startRun(
      sectorId: 'mosswood',
      intent: '',
      squad: ['a1', 'a2'],
      minutes: 25,
    );
    expect(alerts.lastSquad, 'KAEL and MIRA');
    c.dispose();
  });

  test('finishing a run cancels the pending alert', () async {
    final c = GuildController(Persistence(), alerts: alerts);
    await c.boot();
    await c.startRun(
      sectorId: 'mosswood',
      intent: '',
      squad: ['a1'],
      minutes: 25,
    );
    expect(alerts.cancels, 0);

    await c.finishRun(recalled: true);
    expect(alerts.cancels, 1);
    c.dispose();
  });

  test('a live run is re-armed on cold start', () async {
    final first = GuildController(Persistence(), alerts: FakeAlerts());
    await first.boot();
    await first.startRun(
      sectorId: 'mosswood',
      intent: 'still going',
      squad: ['a1'],
      minutes: 45,
    );
    final endsAt = first.active!.endsAt;
    first.dispose();

    // Relaunch against the same save: the OS may have dropped the alarm.
    final second = GuildController(Persistence(), alerts: alerts);
    await second.boot();
    expect(second.hasActiveRun, isTrue);
    expect(alerts.scheduledFor.single, endsAt);
    second.dispose();
  });

  test('a run that already ended is not re-armed on cold start', () async {
    final first = GuildController(Persistence(), alerts: FakeAlerts());
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

    final second = GuildController(Persistence(), alerts: alerts);
    await second.boot();
    expect(second.hasActiveRun, isTrue); // still waiting on its debrief
    expect(alerts.scheduledFor, isEmpty); // but no alert for a finished run
    second.dispose();
  });
}
