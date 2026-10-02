import 'dart:math';

import '../data/content.dart';
import '../models/guild_state.dart';
import '../models/models.dart';

/// The missing middle horizon.
///
/// A run is five minutes of decision and the guild level is a month of arc.
/// Between them there was nothing, so run thirty was identical to run five:
/// same sector, same squad, same wait. Contracts are short-term direction -
/// a reason to send someone else, somewhere else, for longer, today.
///
/// Three rules they are built to respect:
///   - Never punish. No expiry, no failure, no streak to break. A contract
///     sits there until it is done, which is the opposite of "you failed
///     today" and the whole reason this app is not a habit tracker.
///   - Never pay gear. Salvage is what expeditions are for; paying it out
///     here would cheapen the debrief reveal.
///   - Only ask for things the player can actually do right now - sectors
///     they have opened, members they actually have, gear in the vault.
///
/// The story has one more rule of its own: record lines exist only in the
/// debrief, and are never counted at the player. So [ContractKind.sectorReturn]
/// is offered only where a sector still has lines to give, and says nothing
/// about why - it reads as an ordinary order to go back.
class ContractBoard {
  static const int slots = 3;

  /// Fills any empty slot. Called on boot and after a claim, so the board is
  /// always full without needing a timer or a refresh button.
  static void refill(GuildState g, {Random? rng}) {
    final r = rng ?? Random();
    while (g.contracts.length < slots) {
      final made = _generate(g, r);
      if (made == null) break; // nothing sensible to ask for yet
      // Do not offer two of the same thing at once.
      if (g.contracts.any((c) => c.sameShapeAs(made))) continue;
      g.contracts.add(made);
    }
  }

  /// Advances every contract against a finished run. Returns nothing - the
  /// caller looks at [Contract.done] afterwards.
  static void applyRun(GuildState g, RunRecord rec) {
    final sector = sectorById(rec.sectorId);
    final classes = rec.squad
        .map((id) => g.memberById(id)?.classId)
        .whereType<String>()
        .toSet();
    final depth = rec.elapsedSeconds / 60 / sector.nominalMinutes;
    final squad =
        rec.squad.map(g.memberById).whereType<Adventurer>().toList();
    // Kit cannot change while a run is out, so what is equipped now is what
    // went into the field.
    final carried = {
      for (final m in squad)
        for (final uid in m.equipped)
          g.vault.where((v) => v.uid == uid).firstOrNull?.defId,
    };

    for (final c in g.contracts) {
      if (c.done) continue;
      switch (c.kind) {
        case ContractKind.sectorRuns:
          if (rec.sectorId == c.sectorId && !rec.scraps) c.progress += 1;
        case ContractKind.haul:
          final got = switch (c.res!) {
            Res.credits => rec.credits,
            Res.alloy => rec.alloy,
            Res.intel => rec.intel,
          };
          // A haul is a single-run target, so it records the best run rather
          // than a running total.
          if (got > c.progress) c.progress = got;
        case ContractKind.cleanRuns:
          if (rec.integrity >= 0.999 && !rec.scraps) c.progress += 1;
        case ContractKind.longRun:
          if (rec.elapsedMinutes > c.progress) c.progress = rec.elapsedMinutes;
        case ContractKind.minutes:
          c.progress += rec.elapsedMinutes;
        case ContractKind.classRuns:
          if (classes.contains(c.classId) && !rec.scraps) c.progress += 1;
        case ContractKind.fullDepth:
          if (rec.sectorId == c.sectorId && depth >= 1.0) c.progress += 1;
        case ContractKind.sectorReturn:
          if (rec.sectorId == c.sectorId && !rec.scraps) c.progress += 1;
        case ContractKind.memberLevel:
          // Runs bank XP before contracts advance, so this is the new level.
          final m = g.memberById(c.memberId!);
          if (m != null && m.level > c.progress) c.progress = m.level;
        case ContractKind.carryGear:
          if (rec.sectorId == c.sectorId &&
              carried.contains(c.gearDefId) &&
              !rec.scraps) {
            c.progress += 1;
          }
        case ContractKind.fullKit:
          if (squad.isNotEmpty &&
              squad.every((m) => m.equipped.length >= kGearSlots) &&
              !rec.scraps) {
            c.progress += 1;
          }
        case ContractKind.pairRun:
          if (rec.squad.contains(c.memberId) &&
              rec.squad.contains(c.partnerId) &&
              !rec.scraps) {
            c.progress += 1;
          }
        case ContractKind.intentRuns:
          if (rec.intent.trim().isNotEmpty && !rec.scraps) c.progress += 1;
      }
      if (c.progress > c.target) c.progress = c.target;
    }
  }

  // -- generation ------------------------------------------------------------

  static Contract? _generate(GuildState g, Random r) {
    final open = kSectors.where((s) => g.sectorUnlocked(s.id)).toList();
    if (open.isEmpty) return null;

    // Sectors with record lines still unread. Never named as such.
    final untold = open
        .where((s) => (g.surveyRead[s.id] ?? 0) < s.priorSurvey.length)
        .toList();
    // Gear the guild owns that came from a sector it can still reach.
    final carriable = {
      for (final v in g.vault)
        if (open.any((s) => s.lootPool.contains(v.defId))) v.defId,
    }.toList();
    final byLevel = [...g.roster]..sort((a, b) => a.level.compareTo(b.level));

    final kinds = <ContractKind>[
      ContractKind.sectorRuns,
      ContractKind.haul,
      ContractKind.cleanRuns,
      ContractKind.longRun,
      ContractKind.minutes,
      if (g.roster.isNotEmpty) ContractKind.classRuns,
      ContractKind.fullDepth,
      if (untold.isNotEmpty) ContractKind.sectorReturn,
      // Only when someone has fallen behind - otherwise it is just "level up".
      if (byLevel.length >= 2 && byLevel.last.level > byLevel.first.level)
        ContractKind.memberLevel,
      if (carriable.isNotEmpty) ContractKind.carryGear,
      if (g.vault.length >= kGearSlots) ContractKind.fullKit,
      if (g.squadSlots >= 2 &&
          byLevel.length >= 2 &&
          byLevel.last.level > byLevel.first.level)
        ContractKind.pairRun,
      // Kept rare: it sits closest to a habit tracker of anything here.
      if (r.nextInt(3) == 0) ContractKind.intentRuns,
    ];
    final kind = kinds[r.nextInt(kinds.length)];
    final sector = open[r.nextInt(open.length)];
    final id = 'c${g.contractCounter++}';

    // Difficulty 1..3, biased by how far along the guild is.
    final tier = 1 + r.nextInt(g.level >= 6 ? 3 : (g.level >= 3 ? 2 : 1));

    switch (kind) {
      case ContractKind.sectorRuns:
        return _make(g, id, kind, tier,
            sectorId: sector.id, target: 1 + tier);

      case ContractKind.haul:
        final res = [Res.credits, Res.alloy, Res.intel][r.nextInt(3)];
        // Ask for roughly what a nominal run there already yields, times the
        // tier, so it nudges toward a longer run or a better squad.
        final perRun = switch (res) {
          Res.credits => sector.creditsPerMin,
          Res.alloy => sector.alloyPerMin,
          Res.intel => sector.intelPerMin,
        } *
            sector.nominalMinutes;
        if (perRun < 8) return null; // not worth asking for here
        final target = (perRun * (0.8 + 0.35 * tier)).round();
        return _make(g, id, kind, tier,
            sectorId: sector.id, res: res, target: target);

      case ContractKind.cleanRuns:
        return _make(g, id, kind, tier, target: 1 + tier);

      case ContractKind.longRun:
        final target = [45, 60, 90][tier - 1];
        return _make(g, id, kind, tier, target: target);

      case ContractKind.minutes:
        final target = [90, 180, 300][tier - 1];
        return _make(g, id, kind, tier, target: target);

      case ContractKind.classRuns:
        final cls = g.roster[r.nextInt(g.roster.length)].classId;
        return _make(g, id, kind, tier, classId: cls, target: 1 + tier);

      case ContractKind.fullDepth:
        return _make(g, id, kind, tier, sectorId: sector.id, target: tier);

      case ContractKind.sectorReturn:
        final s = untold[r.nextInt(untold.length)];
        return _make(g, id, kind, 1, sectorId: s.id, target: 1);

      case ContractKind.memberLevel:
        // Whoever is furthest behind, a level or two - never past the lead.
        final m = byLevel.first;
        final t = min(1 + (tier > 1 ? 1 : 0), byLevel.last.level - m.level);
        final c = _make(g, id, kind, t,
            memberId: m.id, target: m.level + t);
        c.progress = m.level;
        return c;

      case ContractKind.carryGear:
        final def = carriable[r.nextInt(carriable.length)];
        final home = open.firstWhere((s) => s.lootPool.contains(def));
        return _make(g, id, kind, tier,
            sectorId: home.id, gearDefId: def, target: tier);

      case ContractKind.fullKit:
        return _make(g, id, kind, tier, target: tier);

      case ContractKind.pairRun:
        // The newest hand goes out with the most experienced one.
        return _make(g, id, kind, tier,
            memberId: byLevel.first.id,
            partnerId: byLevel.last.id,
            target: tier);

      case ContractKind.intentRuns:
        return _make(g, id, kind, tier, target: 1 + tier);
    }
  }

  static Contract _make(
    GuildState g,
    String id,
    ContractKind kind,
    int tier, {
    String? sectorId,
    String? classId,
    Res? res,
    String? memberId,
    String? partnerId,
    String? gearDefId,
    required int target,
  }) {
    // Rewards scale with the guild so a contract stays worth doing, but stay
    // modest against expedition income - this is direction, not a second job.
    final base = 45 + g.level * 22;
    return Contract(
      id: id,
      kind: kind,
      sectorId: sectorId,
      classId: classId,
      res: res,
      memberId: memberId,
      partnerId: partnerId,
      gearDefId: gearDefId,
      target: target,
      tier: tier,
      rewardCredits: base * tier,
      rewardAlloy: (base * tier * 0.28).round(),
      rewardIntel: (base * tier * 0.22).round(),
      rewardXp: 30 * tier + g.level * 6,
    );
  }
}
