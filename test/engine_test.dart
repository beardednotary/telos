import 'package:flutter_test/flutter_test.dart';
import 'package:telos/data/content.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/services/expedition_engine.dart';

ActiveRun run({
  required String id,
  String sector = 'mosswood',
  int minutes = 45,
  List<String> squad = const ['a1'],
  int watch = 0,
  int checkIns = 0,
  DateTime? start,
}) {
  return ActiveRun(
    id: id,
    sectorId: sector,
    intent: 'test',
    squad: squad,
    startedAt: start ?? DateTime(2026, 1, 1, 9),
    plannedMinutes: minutes,
    watchSeconds: watch,
    checkIns: checkIns,
  );
}

void main() {
  group('integrity', () {
    test('an untouched run stays at 100%', () {
      final r = run(id: 'x');
      expect(r.integrity(r.endsAt), 1.0);
    });

    test('grace period covers a brief glance', () {
      final r = run(id: 'x', watch: 25);
      expect(r.integrity(r.endsAt), 1.0);
    });

    test('screen time past the grace period costs 1% per 30s', () {
      final r = run(id: 'x', watch: 30 + 300); // 5 billable minutes
      expect(r.integrity(r.endsAt), closeTo(0.90, 0.001));
    });

    test('each reopen costs a flat 4%', () {
      final r = run(id: 'x', checkIns: 3);
      expect(r.integrity(r.endsAt), closeTo(0.88, 0.001));
    });

    test('never falls below 25%', () {
      final r = run(id: 'x', watch: 99999, checkIns: 99);
      expect(r.integrity(r.endsAt), 0.25);
    });
  });

  group('resolution', () {
    test('a run under the sector minimum yields scraps and no salvage', () {
      final g = GuildState.fresh();
      final r = run(id: 's1', sector: 'mosswood', minutes: 5);
      final res = ExpeditionEngine.resolve(
        run: r,
        guild: g,
        now: r.endsAt,
        recalled: false,
      );
      expect(res.record.scraps, isTrue);
      expect(res.record.alloy, 0);
      expect(res.record.intel, 0);
      expect(res.gear, isEmpty);
      expect(res.record.credits, greaterThan(0)); // time still counts for something
    });

    test('longer protected time yields more than shorter', () {
      final g = GuildState.fresh();
      final short = ExpeditionEngine.resolve(
        run: run(id: 'a', minutes: 15),
        guild: g,
        now: DateTime(2026, 1, 1, 9, 15),
        recalled: false,
      );
      final long = ExpeditionEngine.resolve(
        run: run(id: 'a', minutes: 60),
        guild: g,
        now: DateTime(2026, 1, 1, 10),
        recalled: false,
      );
      expect(long.record.credits, greaterThan(short.record.credits));
      expect(long.record.xpGained['a1']!,
          greaterThan(short.record.xpGained['a1']!));
    });

    test('a distracted run of the same length yields less', () {
      final g = GuildState.fresh();
      final clean = ExpeditionEngine.resolve(
        run: run(id: 'same-id', minutes: 45),
        guild: g,
        now: DateTime(2026, 1, 1, 9, 45),
        recalled: false,
      );
      final messy = ExpeditionEngine.resolve(
        run: run(id: 'same-id', minutes: 45, watch: 600, checkIns: 8),
        guild: g,
        now: DateTime(2026, 1, 1, 9, 45),
        recalled: false,
      );
      expect(messy.record.integrity, lessThan(clean.record.integrity));
      expect(messy.record.credits, lessThan(clean.record.credits));
      // Salvage is punished far harder than raw currency - that is the point.
      expect(messy.gear.length, lessThanOrEqualTo(clean.gear.length));
    });

    test('resolution is deterministic for a given run id', () {
      final g = GuildState.fresh();
      final a = ExpeditionEngine.resolve(
        run: run(id: 'fixed', minutes: 45),
        guild: g,
        now: DateTime(2026, 1, 1, 9, 45),
        recalled: false,
      );
      final b = ExpeditionEngine.resolve(
        run: run(id: 'fixed', minutes: 45),
        guild: g,
        now: DateTime(2026, 1, 1, 9, 45),
        recalled: false,
      );
      expect(b.record.credits, a.record.credits);
      expect(b.gear.map((x) => x.defId), a.gear.map((x) => x.defId));
      expect(b.record.journal, a.record.journal);
    });

    test('class window matters: RECON beats VANGUARD on a short run', () {
      final g = GuildState.fresh(); // a1 = vanguard, a2 = recon
      final now = DateTime(2026, 1, 1, 9, 20);
      final vanguard = ExpeditionEngine.resolve(
        run: run(id: 'w', minutes: 20, squad: ['a1']),
        guild: g,
        now: now,
        recalled: false,
      );
      final recon = ExpeditionEngine.resolve(
        run: run(id: 'w', minutes: 20, squad: ['a2']),
        guild: g,
        now: now,
        recalled: false,
      );
      expect(recon.record.credits, greaterThan(vanguard.record.credits));
    });

    test('VANGUARD beats RECON on a long run in an alloy sector', () {
      final g = GuildState.fresh();
      g.unlockedSectors.add('blackstone');
      final now = DateTime(2026, 1, 1, 10, 30);
      final vanguard = ExpeditionEngine.resolve(
        run: run(id: 'w2', sector: 'blackstone', minutes: 90, squad: ['a1']),
        guild: g,
        now: now,
        recalled: false,
      );
      final recon = ExpeditionEngine.resolve(
        run: run(id: 'w2', sector: 'blackstone', minutes: 90, squad: ['a2']),
        guild: g,
        now: now,
        recalled: false,
      );
      expect(vanguard.record.alloy, greaterThan(recon.record.alloy));
    });

    test('gear raises yield on an otherwise identical run', () {
      final base = GuildState.fresh();
      final kitted = GuildState.fresh();
      kitted.vault.add(Gear('g0', 'ore_sense')); // +25% alloy
      kitted.roster.first.equipped.add('g0');
      kitted.unlockedSectors.add('blackstone');
      base.unlockedSectors.add('blackstone');

      final now = DateTime(2026, 1, 1, 9, 45);
      final plain = ExpeditionEngine.resolve(
        run: run(id: 'g', sector: 'blackstone', minutes: 45),
        guild: base,
        now: now,
        recalled: false,
      );
      final better = ExpeditionEngine.resolve(
        run: run(id: 'g', sector: 'blackstone', minutes: 45),
        guild: kitted,
        now: now,
        recalled: false,
      );
      expect(better.record.alloy, greaterThan(plain.record.alloy));
    });
  });

  group('save round-trip', () {
    test('a full state survives JSON', () {
      final g = GuildState.fresh();
      g.credits = 1234;
      g.vault.add(Gear('g0', 'field_optic'));
      g.roster.first.equipped.add('g0');
      g.active = run(id: 'live', checkIns: 2, watch: 90);

      final back = GuildState.fromJson(g.toJson());
      expect(back.credits, 1234);
      expect(back.roster.first.equipped, ['g0']);
      expect(back.active!.checkIns, 2);
      expect(back.active!.watchSeconds, 90);
      expect(back.active!.id, 'live');
    });

    test('a corrupt-free fresh state has exactly one open sector', () {
      expect(GuildState.fresh().unlockedSectors, {'mosswood'});
      expect(GuildState.fresh().squadSlots, 1);
    });
  });

  group('prior survey', () {
    // The story rides on the debrief and must never become a reason to open
    // the app: the rules it has to keep are mechanical, so they are tested.
    GuildState g() => GuildState.fresh();

    Resolution resolveIn(GuildState guild, String id,
        {String sector = 'mosswood', int minutes = 45}) {
      return ExpeditionEngine.resolve(
        run: run(id: id, sector: sector, minutes: minutes),
        guild: guild,
        now: DateTime(2026, 1, 1, 9, minutes),
        recalled: false,
      );
    }

    test('the first run in a sector recovers its first line', () {
      final guild = g();
      final res = resolveIn(guild, 'r1');
      expect(res.record.priorSurvey, sectorById('mosswood').priorSurvey.first);
    });

    test('resolving twice without banking does not burn a line', () {
      final guild = g();
      final a = resolveIn(guild, 'r1');
      final b = resolveIn(guild, 'r2');
      expect(b.record.priorSurvey, a.record.priorSurvey);
    });

    test('lines come back in order, once each, then stop', () {
      final guild = g();
      final pool = sectorById('mosswood').priorSurvey;
      final got = <String>[];
      for (var i = 0; i < pool.length + 2; i++) {
        final res = resolveIn(guild, 'r$i');
        final line = res.record.priorSurvey;
        if (line == null) continue;
        got.add(line);
        guild.surveyRead['mosswood'] = (guild.surveyRead['mosswood'] ?? 0) + 1;
      }
      expect(got, pool);
    });

    test('a scraps run still recovers one - the app never withholds story '
        'as a punishment for a short session', () {
      final guild = g();
      final res = resolveIn(guild, 'r1', minutes: 5);
      expect(res.record.scraps, isTrue);
      expect(res.record.priorSurvey, isNotNull);
    });

    test('each sector keeps its own place in its own pool', () {
      final guild = g();
      guild.unlockedSectors.add('blackstone');
      guild.surveyRead['mosswood'] = 2;
      final res = resolveIn(guild, 'r1', sector: 'blackstone', minutes: 60);
      expect(res.record.priorSurvey,
          sectorById('blackstone').priorSurvey.first);
    });

    test('the recovered line survives a save round-trip', () {
      final guild = g();
      final res = resolveIn(guild, 'r1');
      final back = RunRecord.fromJson(res.record.toJson());
      expect(back.priorSurvey, res.record.priorSurvey);
    });

    test('the read index survives a save round-trip', () {
      final guild = g();
      guild.surveyRead['mosswood'] = 3;
      final back = GuildState.fromJson(guild.toJson());
      expect(back.surveyRead['mosswood'], 3);
    });
  });

  group('the spire', () {
    GuildState arrived() {
      final g = GuildState.fresh();
      g.unlockedSectors.add('spire');
      g.surveyRead['spire'] = sectorById('spire').priorSurvey.length;
      g.spireCompletedAt = DateTime(2026, 6, 1);
      return g;
    }

    test('floors need the full 20 hours each', () {
      final g = arrived();
      g.spireCompletionMinutes = 0;
      for (final probe in [
        [0, 0],
        [19 * 60 + 59, 0],
        [20 * 60, 1],
        [59 * 60, 2],
        [60 * 60, 3],
      ]) {
        g.log.clear();
        g.log.add(RunRecord(
          id: 'x',
          sectorId: 'spire',
          intent: '',
          squad: const [],
          startedAt: DateTime(2026, 6, 1),
          endedAt: DateTime(2026, 6, 1),
          plannedMinutes: probe[0],
          elapsedSeconds: probe[0] * 60,
          integrity: 1,
          recalled: false,
          scraps: false,
          credits: 0,
          alloy: 0,
          intel: 0,
          loot: const [],
          xpGained: const {},
          levelUps: const [],
          guildXp: 0,
          guildLevelUps: 0,
          journal: const [],
        ));
        expect(g.spireFloors, probe[1], reason: '${probe[0]} minutes');
      }
    });

    test('hours spent getting there are not counted as floors', () {
      final g = arrived();
      g.log.add(RunRecord(
        id: 'x',
        sectorId: 'spire',
        intent: '',
        squad: const [],
        startedAt: DateTime(2026, 6, 1),
        endedAt: DateTime(2026, 6, 1),
        plannedMinutes: 100 * 60,
        elapsedSeconds: 100 * 60 * 60,
        integrity: 1,
        recalled: false,
        scraps: false,
        credits: 0,
        alloy: 0,
        intel: 0,
        loot: const [],
        xpGained: const {},
        levelUps: const [],
        guildXp: 0,
        guildLevelUps: 0,
        journal: const [],
      ));
      g.spireCompletionMinutes = g.totalFocusMinutes; // arrived on 100 hours
      expect(g.spireFloors, 0);
      expect(g.minutesSinceSpire, 0);
    });

    test('the charter total is derived from the standing structure', () {
      expect(GuildState.kCharterHours,
          GuildState.kFloorHours * GuildState.kHistoricalFloors);
    });

    test('completion survives a save round-trip', () {
      final g = arrived();
      g.spireCompletionMinutes = 4242;
      final back = GuildState.fromJson(g.toJson());
      expect(back.spireComplete, isTrue);
      expect(back.spireCompletedAt, g.spireCompletedAt);
      expect(back.spireCompletionMinutes, 4242);
    });

    test('a fresh guild has not arrived', () {
      final g = GuildState.fresh();
      expect(g.spireComplete, isFalse);
      expect(g.spireFloors, 0);
    });
  });

  group('content sanity', () {
    test('every sector loot pool references real gear', () {
      for (final s in kSectors) {
        for (final id in s.lootPool) {
          expect(kGear.containsKey(id), isTrue, reason: '${s.id} -> $id');
        }
      }
    });

    test('every sector has prior survey lines', () {
      for (final s in kSectors) {
        expect(s.priorSurvey, isNotEmpty, reason: s.id);
      }
    });

    test('no prior-survey line ends on a hook', () {
      // The tone rule that is actually checkable: a line that ends in a
      // question mark is fishing for the next session.
      for (final s in kSectors) {
        for (final line in s.priorSurvey) {
          expect(line.endsWith('?'), isFalse, reason: '${s.id}: $line');
        }
      }
    });

    test('sector minimums increase with tier', () {
      for (var i = 1; i < kSectors.length; i++) {
        expect(kSectors[i].minMinutes,
            greaterThan(kSectors[i - 1].minMinutes));
      }
    });
  });

  group('next goal', () {
    test('a fresh guild is pointed at the cheapest locked sector', () {
      final g = GuildState.fresh();
      final goal = g.nextGoal!;
      expect(goal.kind, 'SECTOR');
      expect(goal.label, 'BLACKSTONE HOLLOW');
      expect(goal.progress, 0);
      expect(goal.blocked, isNull);
    });

    test('a sector gated by guild level is flagged, not hidden', () {
      final g = GuildState.fresh();
      g.unlockedSectors.add('blackstone');
      final goal = g.nextGoal!;
      expect(goal.label, 'THE CINDER ARCHIVE');
      expect(goal.blocked, 'NEEDS GUILD LV 3');
    });

    test('progress tracks the resource actually needed', () {
      final g = GuildState.fresh();
      g.intel = 30; // half of Blackstone's 60
      expect(g.nextGoal!.progress, closeTo(0.5, 0.001));
      expect(g.nextGoal!.detail, '30 / 60 INTEL');
    });

    test('with every sector open it suggests a recruit', () {
      final g = GuildState.fresh();
      g.level = 2;
      for (final s in kSectors) {
        g.unlockedSectors.add(s.id);
      }
      final goal = g.nextGoal!;
      expect(goal.kind, 'RECRUIT');
      expect(goal.label, 'ARCHIVIST');
    });

    test('with a full roster it falls back to a facility upgrade', () {
      final g = GuildState.fresh();
      g.level = 2;
      for (final s in kSectors) {
        g.unlockedSectors.add(s.id);
      }
      while (g.roster.length < g.rosterSlots) {
        g.roster.add(Adventurer(
          id: 'x${g.roster.length}',
          name: 'EXTRA',
          classId: 'recon',
        ));
      }
      expect(g.nextGoal!.kind, 'FACILITY');
    });
  });

  group('dispatch preview', () {
    List<Adventurer> squad(GuildState g, List<String> ids) =>
        ids.map((i) => g.memberById(i)!).toList();

    test('a member inside their window projects higher than outside it', () {
      final g = GuildState.fresh(); // a2 = recon, window 10-30
      final short = ExpeditionEngine.squadBonusFor(
          guild: g, members: squad(g, ['a2']), minutes: 20);
      final long = ExpeditionEngine.squadBonusFor(
          guild: g, members: squad(g, ['a2']), minutes: 120);
      expect(short.credits, greaterThan(long.credits));
    });

    test('worn gear raises the projection', () {
      final g = GuildState.fresh();
      final before = ExpeditionEngine.squadBonusFor(
          guild: g, members: squad(g, ['a1']), minutes: 90);
      g.vault.add(Gear('g0', 'ore_sense')); // +25% alloy
      g.roster.first.equipped.add('g0');
      final after = ExpeditionEngine.squadBonusFor(
          guild: g, members: squad(g, ['a1']), minutes: 90);
      expect(after.alloy, greaterThan(before.alloy));
    });

    test('the outpost is included', () {
      final g = GuildState.fresh();
      final before = ExpeditionEngine.squadBonusFor(
          guild: g, members: squad(g, ['a1']), minutes: 90);
      g.facilities[Facility.forge] = 4;
      final after = ExpeditionEngine.squadBonusFor(
          guild: g, members: squad(g, ['a1']), minutes: 90);
      expect(after.alloy, greaterThan(before.alloy));
    });

    test('rare chance rises with length and falls with distraction', () {
      final g = GuildState.fresh();
      final b = ExpeditionEngine.squadBonusFor(
          guild: g, members: squad(g, ['a1']), minutes: 45);
      final s = sectorById('mosswood');
      final shortRun =
          ExpeditionEngine.rareChanceFor(sector: s, minutes: 12, squadBonus: b);
      final longRun =
          ExpeditionEngine.rareChanceFor(sector: s, minutes: 45, squadBonus: b);
      final messy = ExpeditionEngine.rareChanceFor(
          sector: s, minutes: 45, squadBonus: b, integrity: 0.5);
      expect(longRun, greaterThan(shortRun));
      expect(messy, lessThan(longRun));
    });
  });
}
