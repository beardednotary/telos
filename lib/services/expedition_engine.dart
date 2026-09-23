import 'dart:math';

import '../data/content.dart';
import '../models/guild_state.dart';
import '../models/models.dart';

/// What a resolved run produced. The gear instances are created here so the
/// debrief can name them, and handed to the controller to bank.
class Resolution {
  final RunRecord record;
  final List<Gear> gear;
  const Resolution(this.record, this.gear);
}

/// Turns a finished focus session into loot.
///
/// The three inputs that matter:
///   TIME      - how long you actually protected. Drives raw quantity and,
///               via the sector minimum, what content you can reach at all.
///   INTEGRITY - how well you protected it. Drives quality, and rare finds
///               much more steeply than quantity.
///   SQUAD     - who you sent. Shifts *which* resources you get.
///
/// Deterministic: seeded from the run id, so a given run always resolves the
/// same way. No reroll by closing the app.
class ExpeditionEngine {
  static Resolution resolve({
    required ActiveRun run,
    required GuildState guild,
    required DateTime now,
    required bool recalled,
  }) {
    final sector = sectorById(run.sectorId);
    final rng = Random(run.id.hashCode);

    final elapsedSec = run.elapsedSeconds(now);
    final elapsedMin = elapsedSec / 60.0;
    final integrity = run.integrity(now);
    final scraps = elapsedMin < sector.minMinutes;

    // -- squad ---------------------------------------------------------------
    final members = run.squad
        .map((id) => guild.memberById(id))
        .whereType<Adventurer>()
        .toList();

    final squadBonus = squadBonusFor(
      guild: guild,
      members: members,
      minutes: elapsedMin,
    );
    final teamFactor = teamFactorFor(members.length);

    // -- yields --------------------------------------------------------------
    // Integrity scales quantity gently (a distracted run still earns) ...
    final qty = 0.55 + 0.45 * integrity;
    // ... and depth is how far into the sector they got.
    final depth = (elapsedMin / sector.nominalMinutes).clamp(0.0, 1.6);
    final scrapFactor = scraps ? 0.30 : 1.0;

    int yield_(double perMin, double bonus) => (perMin *
            elapsedMin *
            (1 + bonus) *
            qty *
            teamFactor *
            scrapFactor)
        .round()
        .clamp(0, 1 << 30);

    final credits = yield_(sector.creditsPerMin, squadBonus.credits);
    final alloy = scraps ? 0 : yield_(sector.alloyPerMin, squadBonus.alloy);
    final intel = scraps ? 0 : yield_(sector.intelPerMin, squadBonus.intel);

    // -- loot ----------------------------------------------------------------
    // Rare finds punish distraction far harder than credits do. This is where
    // a clean run actually pays.
    final loot = <Gear>[];
    if (!scraps) {
      final chance = rareChanceFor(
        sector: sector,
        minutes: elapsedMin,
        squadBonus: squadBonus,
        integrity: integrity,
      );

      var rolls = 1;
      if (depth >= 1.0) rolls++;
      if (depth >= 1.4) rolls++;

      var counter = guild.gearCounter;
      for (var i = 0; i < rolls; i++) {
        if (rng.nextDouble() < chance) {
          final defId = _pickLoot(sector, rng, depth, integrity);
          loot.add(Gear('g${counter++}', defId));
        }
      }
    }

    // -- experience ----------------------------------------------------------
    final tierFactor = 1 + kSectors.indexWhere((s) => s.id == sector.id) * 0.15;
    final xpEach = (elapsedMin *
            3.2 *
            tierFactor *
            (0.6 + 0.4 * integrity) *
            (1 + squadBonus.xp) *
            (scraps ? 0.4 : 1.0))
        .round();

    final xpGained = <String, int>{};
    final levelUps = <String>[];
    for (final m in members) {
      xpGained[m.id] = xpEach;
      // Simulate the level-up without mutating state - the controller applies.
      var lvl = m.level;
      var pool = m.xp + xpEach;
      while (pool >= Adventurer.xpForLevel(lvl)) {
        pool -= Adventurer.xpForLevel(lvl);
        lvl++;
      }
      if (lvl > m.level) levelUps.add(m.id);
    }

    final guildXp = (elapsedMin * 2.5 * (0.6 + 0.4 * integrity)).round();
    var gLvl = guild.level;
    var gPool = guild.xp + guildXp;
    while (gPool >= GuildState.xpForGuildLevel(gLvl)) {
      gPool -= GuildState.xpForGuildLevel(gLvl);
      gLvl++;
    }

    // -- field journal -------------------------------------------------------
    final journal = <String>[];
    if (sector.journal.isNotEmpty) {
      final pool = [...sector.journal]..shuffle(rng);
      final want = scraps ? 1 : (depth >= 1.0 ? 3 : 2);
      journal.addAll(pool.take(want.clamp(1, pool.length)));
    }
    journal.add(_closingLine(
      scraps: scraps,
      recalled: recalled,
      integrity: integrity,
      depth: depth,
      sector: sector,
    ));

    // -- prior survey --------------------------------------------------------
    // One trace of the first company per run in a sector, in order. Read-only
    // here: the controller advances the index after banking, so a resolve
    // that never lands cannot burn a line. Deliberately granted on scraps
    // runs too - withholding the story for a short session would be the app
    // scolding the player for a short session, which it must never do.
    final seen = guild.surveyRead[sector.id] ?? 0;
    final priorSurvey =
        seen < sector.priorSurvey.length ? sector.priorSurvey[seen] : null;

    final record = RunRecord(
      id: run.id,
      sectorId: run.sectorId,
      intent: run.intent,
      squad: run.squad,
      startedAt: run.startedAt,
      endedAt: now,
      plannedMinutes: run.plannedMinutes,
      elapsedSeconds: elapsedSec,
      integrity: integrity,
      recalled: recalled,
      scraps: scraps,
      credits: credits,
      alloy: alloy,
      intel: intel,
      loot: loot.map((g) => g.uid).toList(),
      xpGained: xpGained,
      levelUps: levelUps,
      guildXp: guildXp,
      guildLevelUps: gLvl - guild.level,
      journal: journal,
      priorSurvey: priorSurvey,
    );

    return Resolution(record, loot);
  }

  /// Everything a squad contributes to a run of [minutes]: class shape, the
  /// window bonus when the length suits them, levels, worn gear, and the
  /// outpost on top. Shared with the dispatch preview so the number shown
  /// before a run is the number used to resolve it.
  static Bonus squadBonusFor({
    required GuildState guild,
    required List<Adventurer> members,
    required double minutes,
  }) {
    var total = Bonus.none;
    for (final m in members) {
      final cls = kClasses[m.classId]!;
      var b = cls.base + m.levelBonus;
      // Inside their window, a class does what it is built for.
      if (minutes >= cls.windowMin && minutes <= cls.windowMax) {
        b = b + cls.windowBonus;
      }
      for (final uid in m.equipped) {
        final g = guild.gearByUid(uid);
        if (g != null) b = b + gearById(g.defId).bonus;
      }
      total = total + b;
    }
    // Average, so adding members shifts the mix rather than multiplying it.
    if (members.isNotEmpty) total = total.scaled(1 / members.length);
    return total + guild.facilityBonus;
  }

  /// A bigger squad carries more out, just not explosively.
  static double teamFactorFor(int size) => 1 + 0.15 * (size - 1).clamp(0, 5);

  /// The chance of a gear find on a clean run of this length, for the
  /// dispatch preview. Deliberately the only number shown before a run - the
  /// loot itself stays hidden until the debrief, which is the whole point.
  static double rareChanceFor({
    required Sector sector,
    required double minutes,
    required Bonus squadBonus,
    double integrity = 1.0,
  }) {
    final depth = (minutes / sector.nominalMinutes).clamp(0.0, 1.6);
    return (sector.baseRare *
            (0.55 + 0.75 * depth) *
            pow(integrity, 1.6) *
            (1 + squadBonus.rare))
        .clamp(0.02, 0.90)
        .toDouble();
  }

  /// Weighted pick from the sector's pool. Depth and integrity both push the
  /// weighting up the rarity ladder.
  static String _pickLoot(
    Sector sector,
    Random rng,
    double depth,
    double integrity,
  ) {
    final push = 1 + depth * 0.9 + integrity * 0.6;
    final weights = <String, double>{};
    for (final id in sector.lootPool) {
      final def = kGear[id];
      if (def == null) continue;
      final base = switch (def.rarity) {
        Rarity.common => 100.0,
        Rarity.uncommon => 45.0,
        Rarity.rare => 14.0,
        Rarity.epic => 3.5,
      };
      final lift = switch (def.rarity) {
        Rarity.common => 1.0,
        Rarity.uncommon => push * 0.8,
        Rarity.rare => push,
        Rarity.epic => push * 1.2,
      };
      weights[id] = base * lift;
    }
    final total = weights.values.fold(0.0, (a, b) => a + b);
    var roll = rng.nextDouble() * total;
    for (final e in weights.entries) {
      roll -= e.value;
      if (roll <= 0) return e.key;
    }
    return sector.lootPool.first;
  }

  static String _closingLine({
    required bool scraps,
    required bool recalled,
    required double integrity,
    required double depth,
    required Sector sector,
  }) {
    if (scraps) {
      return 'Squad turned back short of ${sector.name}. Scraps only.';
    }
    if (recalled) {
      return 'Recalled early. They came back with what they had.';
    }
    if (integrity >= 0.999) {
      return depth >= 1.0
          ? 'Clean run. They went further than the brief allowed.'
          : 'Clean run. No interruptions, no losses.';
    }
    if (integrity >= 0.85) {
      return 'Minor signal loss. Squad held the route.';
    }
    if (integrity >= 0.6) {
      return 'Contact broken repeatedly. The squad lost time on the trail.';
    }
    return 'Signal unstable throughout. Most of the run was spent regrouping.';
  }
}
