import 'package:flutter_test/flutter_test.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/services/backup.dart';

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
