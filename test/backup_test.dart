import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/services/backup.dart';
import 'package:telos/services/contracts.dart';

void main() {
  GuildState loaded() {
    final g = GuildState.fresh();
    g.guildName = 'THE LONG WATCH';
    g.level = 9;
    g.credits = 4210;
    g.intel = 880;
    g.vault.add(Gear('g0', 'ore_sense'));
    g.roster.first.equipped.add('g0');
    g.roster.first.level = 6;
    g.unlockedSectors.addAll(['blackstone', 'cinder']);
    g.facilities[Facility.forge] = 4;
    return g;
  }

  test('a save survives the round trip intact', () {
    final before = loaded();
    final after = Backup.decode(Backup.encode(before))!;

    expect(after.guildName, before.guildName);
    expect(after.level, before.level);
    expect(after.credits, before.credits);
    expect(after.intel, before.intel);
    expect(after.unlockedSectors, before.unlockedSectors);
    expect(after.facilities[Facility.forge], 4);
    expect(after.roster.first.level, 6);
    expect(after.roster.first.equipped, ['g0']);
    expect(after.vault.single.defId, 'ore_sense');
  });

  test('the summary can be read without restoring', () {
    final g = loaded();
    final info = Backup.inspect(Backup.encode(g))!;
    expect(info.guild, 'THE LONG WATCH');
    expect(info.level, 9);
  });

  group('a bad file is a message, not a crash', () {
    test('not json', () => expect(Backup.decode('not json at all'), isNull));
    test('empty', () => expect(Backup.decode(''), isNull));
    test('json but not ours',
        () => expect(Backup.decode('{"hello":"world"}'), isNull));
    test('wrapper with no save',
        () => expect(Backup.decode('{"telos":1}'), isNull));
    test('a save with no roster', () {
      final g = GuildState.fresh();
      g.roster.clear();
      expect(Backup.decode(Backup.encode(g)), isNull,
          reason: 'never overwrite a live guild with an empty one');
    });
    test('inspect on rubbish', () => expect(Backup.inspect('{['), isNull));
  });

  group('a backup that points at things this build does not have', () {
    /// A good backup with one thing changed in its save.
    String tampered(void Function(Map<String, dynamic> save) edit) {
      final g = loaded();
      ContractBoard.refill(g, rng: Random(7));
      final j = jsonDecode(Backup.encode(g)) as Map<String, dynamic>;
      edit(j['save'] as Map<String, dynamic>);
      return jsonEncode(j);
    }

    Map<String, dynamic> record(String sectorId) => {
          'id': 'r1',
          'sectorId': sectorId,
          'squad': ['a1'],
          'startedAt': '2026-10-01T09:00:00.000',
          'endedAt': '2026-10-01T09:30:00.000',
          'plannedMinutes': 30,
          'elapsedSeconds': 1800,
          'integrity': 1.0,
        };

    List<Map<String, dynamic>> roster(Map<String, dynamic> save) =>
        (save['roster'] as List).cast<Map<String, dynamic>>();

    test('an ordinary guild with a full contract board still restores', () {
      final text = tampered((_) {});
      final g = Backup.decode(text);
      expect(g, isNotNull);
      expect(g!.contracts, hasLength(ContractBoard.slots));
      expect(Backup.inspect(text), isNotNull);
    });

    test('a log record from a known sector still restores', () {
      expect(Backup.decode(tampered((s) => s['log'] = [record('blackstone')])),
          isNotNull);
    });

    // The audit's case: this one restored, then crashed the roster screen.
    test('gear this build has never heard of', () {
      final text = tampered((s) {
        (s['vault'] as List).add({'uid': 'bad', 'defId': 'nonexistent'});
        (roster(s).first['equipped'] as List).add('bad');
      });
      expect(Backup.decode(text), isNull);
      expect(Backup.inspect(text), isNull);
    });

    test('equipped gear that is not in the vault', () {
      expect(
          Backup.decode(
              tampered((s) => roster(s).first['equipped'] = ['g0', 'missing'])),
          isNull);
    });

    test('one piece of gear on two members', () {
      expect(Backup.decode(tampered((s) {
        final second = Map<String, dynamic>.of(roster(s).first)
          ..['id'] = 'second';
        (s['roster'] as List).add(second);
      })), isNull);
    });

    test('a member of a class that does not exist', () {
      expect(
          Backup.decode(
              tampered((s) => roster(s).first['classId'] = 'necromancer')),
          isNull);
    });

    test('an unlocked sector that does not exist', () {
      expect(
          Backup.decode(
              tampered((s) => (s['unlockedSectors'] as List).add('atlantis'))),
          isNull);
    });

    test('a log record from a sector that does not exist', () {
      expect(Backup.decode(tampered((s) => s['log'] = [record('atlantis')])),
          isNull);
    });

    test('a contract naming gear that does not exist', () {
      expect(
          Backup.decode(tampered((s) => s['contracts'] = [
                {
                  'id': 'c1',
                  'kind': 'carryGear',
                  'sectorId': 'mosswood',
                  'gearDefId': 'nonexistent',
                }
              ])),
          isNull);
    });

    test('a contract missing the sector its wording needs', () {
      expect(
          Backup.decode(tampered((s) => s['contracts'] = [
                {'id': 'c1', 'kind': 'sectorRuns', 'target': 3}
              ])),
          isNull);
    });

    test('negative resources', () {
      expect(Backup.decode(tampered((s) => s['credits'] = -50)), isNull);
    });
  });

  group('the copy kept before a restore', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('telos-keep-'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('is a backup that reads back as the guild it was', () async {
      final g = loaded();
      final name = await Backup.keepBeforeRestore(g,
          when: DateTime(2026, 11, 9, 8, 5), into: dir);
      expect(name, 'telos-before-restore-2026-11-09-0805.json');
      final back = Backup.decode(File('${dir.path}/$name').readAsStringSync())!;
      expect(back.guildName, 'THE LONG WATCH');
      expect(back.credits, 4210);
    });

    test('never takes the name of an earlier copy', () async {
      final when = DateTime(2026, 11, 9, 8, 5);
      final first = loaded()..guildName = 'FIRST';
      final second = loaded()..guildName = 'SECOND';
      final a = await Backup.keepBeforeRestore(first, when: when, into: dir);
      final b = await Backup.keepBeforeRestore(second, when: when, into: dir);
      expect(b, isNot(a));
      expect(
          Backup.decode(File('${dir.path}/$a').readAsStringSync())!.guildName,
          'FIRST',
          reason: 'two restores in one minute keep both guilds');
      expect(
          Backup.decode(File('${dir.path}/$b').readAsStringSync())!.guildName,
          'SECOND');
    });
  });

  test('file names sort chronologically', () {
    final early = Backup.fileNameFor(DateTime(2026, 9, 2, 8, 5));
    final later = Backup.fileNameFor(DateTime(2026, 9, 20, 14, 30));
    expect(early.compareTo(later), lessThan(0));
    expect(later, endsWith('.json'));
  });

  group('local telemetry', () {
    test('a fresh save records when it was installed', () {
      final g = GuildState.fresh();
      expect(g.installedAt, isNotNull);
      expect(g.appOpens, 0);
      expect(g.daysActive, 0);
    });

    test('telemetry survives the round trip and reaches the summary', () {
      final g = GuildState.fresh();
      g.appOpens = 14;
      g.openDays.addAll(['2026-09-20', '2026-09-21', '2026-09-22']);
      g.manualSeenAt = DateTime(2026, 9, 20, 8);
      g.manualDoneAt = DateTime(2026, 9, 20, 8, 2);

      final after = Backup.decode(Backup.encode(g))!;
      expect(after.appOpens, 14);
      expect(after.daysActive, 3);
      expect(after.manualDoneAt, g.manualDoneAt);

      // Readable without parsing the whole save.
      expect(Backup.encode(g), contains('"appOpens": 14'));
      expect(Backup.encode(g), contains('"daysActive": 3'));
    });

    test('someone who bounced off the manual is visible', () {
      final g = GuildState.fresh();
      g.manualSeenAt = DateTime(2026, 9, 20, 8);
      // Never completed it.
      expect(g.manualDoneAt, isNull);
      expect(g.onboarded, isFalse);
    });
  });
}
