import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/services/contracts.dart';

RunRecord rec({
  String sector = 'mosswood',
  int minutes = 30,
  double integrity = 1.0,
  bool scraps = false,
  int credits = 100,
  int alloy = 20,
  int intel = 5,
  List<String> squad = const ['a1'],
}) =>
    RunRecord(
      id: 'r',
      sectorId: sector,
      intent: '',
      squad: squad,
      startedAt: DateTime(2026, 1, 1, 9),
      endedAt: DateTime(2026, 1, 1, 9).add(Duration(minutes: minutes)),
      plannedMinutes: minutes,
      elapsedSeconds: minutes * 60,
      integrity: integrity,
      recalled: false,
      scraps: scraps,
      credits: credits,
      alloy: alloy,
      intel: intel,
      loot: const [],
      xpGained: const {},
      levelUps: const [],
      guildXp: 50,
      guildLevelUps: 0,
      journal: const [],
    );

Contract only(GuildState g, ContractKind kind, {int target = 2, Res? res}) {
  final c = Contract(
    id: 'x',
    kind: kind,
    sectorId: kind == ContractKind.sectorRuns || kind == ContractKind.fullDepth
        ? 'mosswood'
        : null,
    classId: kind == ContractKind.classRuns ? 'vanguard' : null,
    res: res,
    target: target,
    tier: 1,
    rewardCredits: 100,
    rewardAlloy: 20,
    rewardIntel: 10,
    rewardXp: 40,
  );
  g.contracts
    ..clear()
    ..add(c);
  return c;
}

void main() {
  group('the board', () {
    test('fills every slot and never offers two of a shape', () {
      final g = GuildState.fresh();
      ContractBoard.refill(g, rng: Random(7));
      expect(g.contracts.length, ContractBoard.slots);
      for (var i = 0; i < g.contracts.length; i++) {
        for (var j = i + 1; j < g.contracts.length; j++) {
          expect(g.contracts[i].sameShapeAs(g.contracts[j]), isFalse);
        }
      }
    });

    test('only asks for sectors that are open', () {
      final g = GuildState.fresh(); // mosswood only
      for (var seed = 0; seed < 40; seed++) {
        g.contracts.clear();
        ContractBoard.refill(g, rng: Random(seed));
        for (final c in g.contracts) {
          if (c.sectorId != null) expect(c.sectorId, 'mosswood');
        }
      }
    });

    test('only asks for classes on the roster', () {
      final g = GuildState.fresh(); // vanguard + recon
      final have = g.roster.map((m) => m.classId).toSet();
      for (var seed = 0; seed < 40; seed++) {
        g.contracts.clear();
        ContractBoard.refill(g, rng: Random(seed));
        for (final c in g.contracts) {
          if (c.classId != null) expect(have, contains(c.classId));
        }
      }
    });

    test('never pays gear', () {
      final g = GuildState.fresh();
      ContractBoard.refill(g, rng: Random(3));
      // Rewards are resources and guild XP only - salvage stays the reason to
      // run an expedition.
      for (final c in g.contracts) {
        expect(c.rewardCredits + c.rewardAlloy + c.rewardIntel,
            greaterThan(0));
      }
    });
  });

  group('progress', () {
    test('sector runs count only that sector, and not scraps', () {
      final g = GuildState.fresh();
      final c = only(g, ContractKind.sectorRuns, target: 2);
      ContractBoard.applyRun(g, rec(sector: 'mosswood'));
      expect(c.progress, 1);
      ContractBoard.applyRun(g, rec(sector: 'blackstone'));
      expect(c.progress, 1, reason: 'wrong sector');
      ContractBoard.applyRun(g, rec(sector: 'mosswood', scraps: true));
      expect(c.progress, 1, reason: 'scraps should not count');
      ContractBoard.applyRun(g, rec(sector: 'mosswood'));
      expect(c.done, isTrue);
    });

    test('a haul records the best single run, not a total', () {
      final g = GuildState.fresh();
      final c = only(g, ContractKind.haul, target: 200, res: Res.credits);
      ContractBoard.applyRun(g, rec(credits: 120));
      ContractBoard.applyRun(g, rec(credits: 90));
      expect(c.progress, 120, reason: 'two runs must not add up');
      ContractBoard.applyRun(g, rec(credits: 260));
      expect(c.done, isTrue);
    });

    test('clean runs need full integrity', () {
      final g = GuildState.fresh();
      final c = only(g, ContractKind.cleanRuns, target: 1);
      ContractBoard.applyRun(g, rec(integrity: 0.96));
      expect(c.progress, 0);
      ContractBoard.applyRun(g, rec(integrity: 1.0));
      expect(c.done, isTrue);
    });

    test('a long run takes the best block, minutes accumulate', () {
      final g = GuildState.fresh();
      final long = only(g, ContractKind.longRun, target: 60);
      ContractBoard.applyRun(g, rec(minutes: 45));
      ContractBoard.applyRun(g, rec(minutes: 30));
      expect(long.progress, 45);

      final mins = only(g, ContractKind.minutes, target: 60);
      ContractBoard.applyRun(g, rec(minutes: 45));
      ContractBoard.applyRun(g, rec(minutes: 30));
      expect(mins.done, isTrue, reason: 'totals should add up');
    });

    test('progress never exceeds the target', () {
      final g = GuildState.fresh();
      final c = only(g, ContractKind.minutes, target: 50);
      ContractBoard.applyRun(g, rec(minutes: 200));
      expect(c.progress, 50);
    });

    test('a finished contract stops advancing', () {
      final g = GuildState.fresh();
      final c = only(g, ContractKind.cleanRuns, target: 1);
      ContractBoard.applyRun(g, rec());
      ContractBoard.applyRun(g, rec());
      expect(c.progress, 1);
    });
  });

  test('contracts survive a save round trip', () {
    final g = GuildState.fresh();
    ContractBoard.refill(g, rng: Random(11));
    g.contracts.first.progress = 2;

    final back = GuildState.fromJson(g.toJson());
    expect(back.contracts.length, g.contracts.length);
    expect(back.contracts.first.progress, 2);
    expect(back.contracts.first.kind, g.contracts.first.kind);
    expect(back.contracts.first.target, g.contracts.first.target);
  });
}
