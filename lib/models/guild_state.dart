import 'dart:math';

import '../data/content.dart';
import 'models.dart';

/// The entire save file. One object, serialised to JSON.
class GuildState {
  String guildName;
  int level;
  int xp;

  int credits;
  int alloy;
  int intel;

  List<Adventurer> roster;
  List<Gear> vault;
  Map<Facility, int> facilities;
  Set<String> unlockedSectors;
  List<RunRecord> log;
  ActiveRun? active;

  /// Debrief waiting to be viewed (set when a run resolves, cleared on dismiss).
  RunRecord? pendingDebrief;

  int gearCounter;
  int runCounter;
  bool onboarded;

  GuildState({
    required this.guildName,
    required this.level,
    required this.xp,
    required this.credits,
    required this.alloy,
    required this.intel,
    required this.roster,
    required this.vault,
    required this.facilities,
    required this.unlockedSectors,
    required this.log,
    this.active,
    this.pendingDebrief,
    this.gearCounter = 0,
    this.runCounter = 0,
    this.onboarded = false,
  });

  /// A fresh save: two members, one sector, nothing else.
  factory GuildState.fresh() => GuildState(
        guildName: 'THE SILVER LANTERN',
        level: 1,
        xp: 0,
        credits: 0,
        alloy: 0,
        intel: 0,
        roster: [
          Adventurer(id: 'a1', name: 'KAEL', classId: 'vanguard'),
          Adventurer(id: 'a2', name: 'MIRA', classId: 'recon'),
        ],
        vault: [],
        facilities: {
          Facility.barracks: 1,
          Facility.forge: 1,
          Facility.archive: 1,
        },
        unlockedSectors: {'mosswood'},
        log: [],
      );

  // -- progression curves ----------------------------------------------------

  /// XP required to move from [level] to level+1.
  static int xpForGuildLevel(int level) => (160 * pow(level, 1.45)).round();

  int get xpToNext => xpForGuildLevel(level);

  /// How many members you can keep. Barracks raises the ceiling.
  int get rosterSlots => 2 + facilities[Facility.barracks]!;

  /// How many members can go out on a single run. This is the core tactical
  /// choice early on: two members, one slot - who fits this block of work?
  int get squadSlots {
    var slots = 1;
    for (final l in kSquadSlotLevels) {
      if (level >= l) slots++;
    }
    return slots;
  }

  /// Facility bonuses, summed. Applied to every run.
  Bonus get facilityBonus => facilities.entries
      .map((e) => e.key.bonusAt(e.value))
      .fold(Bonus.none, (a, b) => a + b);

  Adventurer? memberById(String id) {
    for (final a in roster) {
      if (a.id == id) return a;
    }
    return null;
  }

  Gear? gearByUid(String uid) {
    for (final g in vault) {
      if (g.uid == uid) return g;
    }
    return null;
  }

  /// Gear not currently equipped by anyone.
  List<Gear> get unequippedGear {
    final worn = <String>{for (final a in roster) ...a.equipped};
    return vault.where((g) => !worn.contains(g.uid)).toList();
  }

  bool sectorUnlocked(String id) => unlockedSectors.contains(id);

  /// Total protected minutes across every logged run - the headline stat.
  int get totalFocusMinutes =>
      log.fold(0, (sum, r) => sum + r.elapsedSeconds) ~/ 60;

  int get cleanRuns => log.where((r) => r.integrity >= 0.999).length;

  /// Consecutive days, ending today or yesterday, with at least one run.
  int get streak {
    if (log.isEmpty) return 0;
    final days = log
        .map((r) => DateTime(r.endedAt.year, r.endedAt.month, r.endedAt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    if (days.first != t0 && days.first != t0.subtract(const Duration(days: 1))) {
      return 0;
    }
    var count = 1;
    for (var i = 1; i < days.length; i++) {
      if (days[i - 1].difference(days[i]).inDays == 1) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  // -- serialisation ---------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'v': 1,
        'guildName': guildName,
        'level': level,
        'xp': xp,
        'credits': credits,
        'alloy': alloy,
        'intel': intel,
        'roster': roster.map((a) => a.toJson()).toList(),
        'vault': vault.map((g) => g.toJson()).toList(),
        'facilities': facilities.map((k, v) => MapEntry(k.name, v)),
        'unlockedSectors': unlockedSectors.toList(),
        'log': log.map((r) => r.toJson()).toList(),
        'active': active?.toJson(),
        'pendingDebrief': pendingDebrief?.toJson(),
        'gearCounter': gearCounter,
        'runCounter': runCounter,
        'onboarded': onboarded,
      };

  factory GuildState.fromJson(Map<String, dynamic> j) {
    final facs = <Facility, int>{
      Facility.barracks: 1,
      Facility.forge: 1,
      Facility.archive: 1,
    };
    final raw = (j['facilities'] as Map?) ?? {};
    for (final f in Facility.values) {
      final v = raw[f.name];
      if (v is int) facs[f] = v;
    }

    return GuildState(
      guildName: j['guildName'] as String? ?? 'THE SILVER LANTERN',
      level: j['level'] as int? ?? 1,
      xp: j['xp'] as int? ?? 0,
      credits: j['credits'] as int? ?? 0,
      alloy: j['alloy'] as int? ?? 0,
      intel: j['intel'] as int? ?? 0,
      roster: ((j['roster'] as List?) ?? [])
          .map((e) => Adventurer.fromJson(e as Map<String, dynamic>))
          .toList(),
      vault: ((j['vault'] as List?) ?? [])
          .map((e) => Gear.fromJson(e as Map<String, dynamic>))
          .toList(),
      facilities: facs,
      unlockedSectors:
          ((j['unlockedSectors'] as List?)?.cast<String>() ?? ['mosswood'])
              .toSet(),
      log: ((j['log'] as List?) ?? [])
          .map((e) => RunRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      active: j['active'] == null
          ? null
          : ActiveRun.fromJson(j['active'] as Map<String, dynamic>),
      pendingDebrief: j['pendingDebrief'] == null
          ? null
          : RunRecord.fromJson(j['pendingDebrief'] as Map<String, dynamic>),
      gearCounter: j['gearCounter'] as int? ?? 0,
      runCounter: j['runCounter'] as int? ?? 0,
      onboarded: j['onboarded'] as bool? ?? false,
    );
  }
}

/// Guild levels that grant another squad slot. Named so the level-up
/// acknowledgement and the slot calculation cannot drift apart.
const List<int> kSquadSlotLevels = [3, 6, 10];

/// What reaching [level] actually opened up.
///
/// Derived from the content rather than written out, so adding a class or a
/// sector keeps this honest by itself. The number going up is not the reward;
/// knowing what it bought you is.
List<String> guildLevelUnlocks(int level) {
  final out = <String>[];
  if (kSquadSlotLevels.contains(level)) {
    out.add('SQUAD SLOT +1  -  send another member on every run');
  }
  for (final c in kClasses.values) {
    if (c.recruitCost > 0 && c.unlockGuildLevel == level) {
      out.add('${c.name} available to recruit');
    }
  }
  for (final s in kSectors) {
    if (s.guildLevelToUnlock == level) {
      out.add('${s.name} eligible  -  ${s.intelToUnlock} INTEL to open');
    }
  }
  return out;
}

/// Classes available to recruit at the current guild level.
List<ClassDef> recruitableClasses(GuildState g) => kClasses.values
    .where((c) => c.recruitCost > 0 && c.unlockGuildLevel <= g.level)
    .toList();

/// The middle horizon: the nearest thing worth working towards.
///
/// Incremental games live on "I'll just get to the next unlock". The home
/// screen has the immediate action (dispatch) and the long arc (guild level),
/// but nothing in between - this fills that gap with one concrete target.
class NextGoal {
  final String kind; // SECTOR / RECRUIT / FACILITY
  final String label;
  final String detail; // '184 / 320 INTEL'
  final double progress; // 0..1
  final String? blocked; // e.g. 'NEEDS GUILD LV 3'

  const NextGoal({
    required this.kind,
    required this.label,
    required this.detail,
    required this.progress,
    this.blocked,
  });
}

extension NextGoalFor on GuildState {
  NextGoal? get nextGoal {
    // 1. A new sector is the most interesting unlock, so it wins when one is
    //    in sight.
    final locked = kSectors.where((s) => !sectorUnlocked(s.id)).toList()
      ..sort((a, b) => a.intelToUnlock.compareTo(b.intelToUnlock));
    if (locked.isNotEmpty) {
      final s = locked.first;
      final short = level < s.guildLevelToUnlock;
      return NextGoal(
        kind: 'SECTOR',
        label: s.name,
        detail: '$intel / ${s.intelToUnlock} INTEL',
        progress: s.intelToUnlock == 0 ? 1 : intel / s.intelToUnlock,
        blocked: short ? 'NEEDS GUILD LV ${s.guildLevelToUnlock}' : null,
      );
    }

    // 2. Otherwise a new archetype, if there is room for one.
    if (roster.length < rosterSlots) {
      final options = recruitableClasses(this)
        ..sort((a, b) => a.recruitCost.compareTo(b.recruitCost));
      if (options.isNotEmpty) {
        final c = options.first;
        return NextGoal(
          kind: 'RECRUIT',
          label: c.name,
          detail: '$credits / ${c.recruitCost} CREDITS',
          progress: credits / c.recruitCost,
        );
      }
    }

    // 3. Failing that, the cheapest facility upgrade.
    Facility? best;
    var bestCost = 1 << 30;
    for (final f in Facility.values) {
      final (c, _) = f.costAt(facilities[f]!);
      if (c < bestCost) {
        bestCost = c;
        best = f;
      }
    }
    if (best == null) return null;
    final (costC, costA) = best.costAt(facilities[best]!);
    return NextGoal(
      kind: 'FACILITY',
      label: '${best.label} LV ${facilities[best]! + 1}',
      detail: '$credits / $costC CR  -  $alloy / $costA AL',
      progress: ((credits / costC) + (alloy / costA)) / 2,
    );
  }
}
