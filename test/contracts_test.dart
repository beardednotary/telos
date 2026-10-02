import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:telos/data/content.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/services/contracts.dart';
import 'package:telos/widgets/contract_board.dart';

RunRecord rec({
  String sector = 'mosswood',
  int minutes = 30,
  double integrity = 1.0,
  bool scraps = false,
  int credits = 100,
  int alloy = 20,
  int intel = 5,
  List<String> squad = const ['a1'],
  String intent = '',
}) =>
    RunRecord(
      id: 'r',
      sectorId: sector,
      intent: intent,
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

Contract adjacent(
  GuildState g,
  ContractKind kind, {
  int target = 1,
  String? sectorId,
  String? memberId,
  String? partnerId,
  String? gearDefId,
}) {
  final c = Contract(
    id: 'x',
    kind: kind,
    sectorId: sectorId,
    memberId: memberId,
    partnerId: partnerId,
    gearDefId: gearDefId,
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

  group('adjacent contracts', () {
    List<Contract> board(GuildState g, int seeds) => [
          for (var seed = 0; seed < seeds; seed++)
            ...() {
              g.contracts.clear();
              ContractBoard.refill(g, rng: Random(seed));
              return [...g.contracts];
            }(),
        ];

    test('going back is only offered where records are left, and says so '
        'nowhere', () {
      final g = GuildState.fresh();
      g.unlockedSectors.add('blackstone');
      g.surveyRead['mosswood'] = sectorById('mosswood').priorSurvey.length;
      final returns =
          board(g, 200).where((c) => c.kind == ContractKind.sectorReturn);
      expect(returns, isNotEmpty);
      for (final c in returns) {
        expect(c.sectorId, 'blackstone');
        expect(contractTitle(c, g).toLowerCase(), isNot(contains('record')));
      }

      g.surveyRead['blackstone'] = sectorById('blackstone').priorSurvey.length;
      expect(
          board(g, 200).where((c) => c.kind == ContractKind.sectorReturn),
          isEmpty);
    });

    test('going back counts a real run in that sector', () {
      final g = GuildState.fresh();
      final c = adjacent(g, ContractKind.sectorReturn, sectorId: 'mosswood');
      ContractBoard.applyRun(g, rec(sector: 'mosswood', scraps: true));
      expect(c.progress, 0);
      ContractBoard.applyRun(g, rec(sector: 'mosswood'));
      expect(c.done, isTrue);
    });

    test('bringing someone up targets whoever is behind, and tracks level',
        () {
      final g = GuildState.fresh();
      g.memberById('a1')!.level = 4;
      final ups = board(g, 200).where((c) => c.kind == ContractKind.memberLevel);
      expect(ups, isNotEmpty);
      for (final c in ups) {
        expect(c.memberId, 'a2');
        expect(c.progress, 1);
        expect(c.target, inInclusiveRange(2, 4));
      }

      final c = adjacent(g, ContractKind.memberLevel,
          memberId: 'a2', target: 3);
      g.memberById('a2')!.level = 3;
      ContractBoard.applyRun(g, rec(squad: ['a2']));
      expect(c.done, isTrue);
    });

    test('nobody behind, no level contract', () {
      final g = GuildState.fresh(); // both level 1
      expect(board(g, 100).where((c) => c.kind == ContractKind.memberLevel),
          isEmpty);
    });

    test('carrying gear asks only for gear in the vault, in its home sector',
        () {
      final g = GuildState.fresh();
      expect(board(g, 100).where((c) => c.kind == ContractKind.carryGear),
          isEmpty);

      g.vault.add(Gear('g0', 'scav_cord'));
      final carry = board(g, 200).where((c) => c.kind == ContractKind.carryGear);
      expect(carry, isNotEmpty);
      for (final c in carry) {
        expect(c.gearDefId, 'scav_cord');
        expect(c.sectorId, 'mosswood');
      }

      final c = adjacent(g, ContractKind.carryGear,
          sectorId: 'mosswood', gearDefId: 'scav_cord');
      ContractBoard.applyRun(g, rec(sector: 'mosswood'));
      expect(c.progress, 0, reason: 'owned but not equipped');
      g.memberById('a1')!.equipped.add('g0');
      ContractBoard.applyRun(g, rec(sector: 'blackstone'));
      expect(c.progress, 0, reason: 'wrong sector');
      ContractBoard.applyRun(g, rec(sector: 'mosswood'));
      expect(c.done, isTrue);
    });

    test('a full kit means every member out has every slot filled', () {
      final g = GuildState.fresh();
      g.vault.addAll([Gear('g0', 'scav_cord'), Gear('g1', 'field_optic')]);
      final c = adjacent(g, ContractKind.fullKit);
      g.memberById('a1')!.equipped.addAll(['g0', 'g1']);
      ContractBoard.applyRun(g, rec(squad: ['a1', 'a2']));
      expect(c.progress, 0, reason: 'MIRA went out empty-handed');
      ContractBoard.applyRun(g, rec(squad: ['a1']));
      expect(c.done, isTrue);
    });

    test('a pairing pairs the newest with the most experienced', () {
      final g = GuildState.fresh();
      g.level = 3; // two squad slots
      g.memberById('a1')!.level = 5;
      final pairs = board(g, 200).where((c) => c.kind == ContractKind.pairRun);
      expect(pairs, isNotEmpty);
      for (final c in pairs) {
        expect([c.memberId, c.partnerId], ['a2', 'a1']);
      }

      final c = adjacent(g, ContractKind.pairRun,
          memberId: 'a2', partnerId: 'a1');
      ContractBoard.applyRun(g, rec(squad: ['a2']));
      expect(c.progress, 0);
      ContractBoard.applyRun(g, rec(squad: ['a1', 'a2']));
      expect(c.done, isTrue);
    });

    test('no pairing while only one can go out', () {
      final g = GuildState.fresh(); // level 1, one slot
      g.memberById('a1')!.level = 5;
      expect(board(g, 100).where((c) => c.kind == ContractKind.pairRun),
          isEmpty);
    });

    test('an intent counts when one was set, whatever the answer after', () {
      final g = GuildState.fresh();
      final c = adjacent(g, ContractKind.intentRuns, target: 2);
      ContractBoard.applyRun(g, rec());
      ContractBoard.applyRun(g, rec(intent: '   '));
      expect(c.progress, 0);
      ContractBoard.applyRun(g, rec(intent: 'Write the README', scraps: true));
      expect(c.progress, 0, reason: 'scraps do not count');
      ContractBoard.applyRun(g, rec(intent: 'Write the README'));
      ContractBoard.applyRun(g, rec(intent: 'Fix the build'));
      expect(c.done, isTrue);
    });

    test('every kind has a title', () {
      final g = GuildState.fresh();
      g.vault.add(Gear('g0', 'scav_cord'));
      for (final kind in ContractKind.values) {
        final c = Contract(
          id: 'x',
          kind: kind,
          sectorId: 'mosswood',
          classId: 'vanguard',
          res: Res.credits,
          memberId: 'a1',
          partnerId: 'a2',
          gearDefId: 'scav_cord',
          target: 2,
          tier: 1,
          rewardCredits: 1,
          rewardAlloy: 1,
          rewardIntel: 1,
          rewardXp: 1,
        );
        expect(contractTitle(c, g), isNotEmpty);
      }
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

  test('the new fields survive a save round trip', () {
    final g = GuildState.fresh();
    adjacent(g, ContractKind.pairRun, memberId: 'a2', partnerId: 'a1');
    g.contracts.add(Contract(
      id: 'y',
      kind: ContractKind.carryGear,
      sectorId: 'mosswood',
      gearDefId: 'scav_cord',
      target: 1,
      tier: 1,
      rewardCredits: 1,
      rewardAlloy: 1,
      rewardIntel: 1,
      rewardXp: 1,
    ));
    final back = GuildState.fromJson(g.toJson()).contracts;
    expect(back[0].kind, ContractKind.pairRun);
    expect([back[0].memberId, back[0].partnerId], ['a2', 'a1']);
    expect(back[1].gearDefId, 'scav_cord');
  });
}
