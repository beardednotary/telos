import 'dart:math';

import '../data/content.dart';
import 'caravan.dart';
import 'guild_identity.dart';
import 'models.dart';

/// The entire save file. One object, serialised to JSON.
class GuildState {
  String guildName;
  GuildSigil guildSigil;
  Facility campProject;
  int level;
  int xp;

  int credits;
  int alloy;
  int intel;

  List<Adventurer> roster;
  List<Gear> vault;
  Map<Facility, int> facilities;
  Set<String> unlockedSectors;

  /// When the last of the Spire's records was recovered, and the total
  /// protected minutes standing at that moment. Floors are counted from
  /// there, so the hours spent getting to the Spire are credited on the
  /// Charter and the hours after it become height.
  DateTime? spireCompletedAt;
  int spireCompletionMinutes;

  /// The Charter's holder line was left blank - the first company never put
  /// their name to it, because nobody had finished the work. The player's
  /// goes in on arrival.
  ///
  /// Snapshotted rather than read live from [guildName]: a charter is a
  /// document signed once, so renaming the guild afterwards does not quietly
  /// rewrite history.
  String? spireCharterName;

  /// How far into each sector's prior-survey pool the player has read.
  /// sectorId -> lines recovered. Advanced by the controller once a run is
  /// banked, so a resolve that never lands cannot burn a line.
  Map<String, int> surveyRead;

  /// The field log, newest first. Holds the latest [kLogLimit] runs in full;
  /// older ones are folded into [trimmed] as they fall off the end.
  List<RunRecord> log;
  static const int kLogLimit = 500;
  LogTally trimmed;
  ActiveRun? active;

  /// Debrief waiting to be viewed (set when a run resolves, cleared on dismiss).
  RunRecord? pendingDebrief;

  List<Contract> contracts;
  int contractCounter;

  /// The player's punch clock, or null when they have not set one. The
  /// departure last met (yyyy-mm-dd), so each is met once; and how far into
  /// the caravan's manifest they have read.
  CaravanSchedule? caravan;
  String? caravanClaimed;
  int caravanRead;

  /// Camp music, and the chime when a squad comes home. Off until the
  /// player turns it on.
  bool musicOn;

  /// Camp offers the music once, after the first expedition. Either answer
  /// settles it; Settings has the switch from then on.
  bool musicOffered;

  int gearCounter;
  int runCounter;
  bool onboarded;

  /// LOCAL TELEMETRY. Nothing here leaves the phone unless the player
  /// deliberately exports a backup and sends it to you.
  ///
  /// It exists because the field log answers "what did they do" but not
  /// "did they come back and decide not to". An opened app with no run is
  /// the single most informative event in an early test, and it is the one
  /// thing the log cannot see. An analytics SDK would answer it too, at the
  /// cost of a backend, a privacy policy, a nutrition label, and the claim
  /// that this app makes no network calls - which is worth more than the
  /// question.
  DateTime? installedAt;
  int appOpens;

  /// Distinct yyyy-mm-dd strings the app was opened on. Bounded by days, not
  /// by opens, so it stays tiny.
  List<String> openDays;

  /// When the manual was first shown, and when it was finished. A gap with
  /// no completion is someone who bounced off the first screen.
  DateTime? manualSeenAt;
  DateTime? manualDoneAt;

  GuildState({
    required this.guildName,
    this.guildSigil = GuildSigil.lantern,
    this.campProject = Facility.forge,
    required this.level,
    required this.xp,
    required this.credits,
    required this.alloy,
    required this.intel,
    required this.roster,
    required this.vault,
    required this.facilities,
    required this.unlockedSectors,
    required this.surveyRead,
    this.spireCompletedAt,
    this.spireCompletionMinutes = 0,
    this.spireCharterName,
    required this.log,
    LogTally? trimmed,
    List<Contract>? contracts,
    this.contractCounter = 0,
    this.caravan,
    this.caravanClaimed,
    this.caravanRead = 0,
    this.musicOn = false,
    this.musicOffered = false,
    this.active,
    this.pendingDebrief,
    this.gearCounter = 0,
    this.runCounter = 0,
    this.onboarded = false,
    this.installedAt,
    this.appOpens = 0,
    List<String>? openDays,
    this.manualSeenAt,
    this.manualDoneAt,
  })  : trimmed = trimmed ?? LogTally(),
        contracts = contracts ?? <Contract>[],
        openDays = openDays ?? <String>[];

  /// A fresh save: two members, one sector, nothing else.
  factory GuildState.fresh() => GuildState(
        guildName: 'The Silver Lantern',
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
        surveyRead: {},
        log: [],
        installedAt: DateTime.now(),
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

  /// Trims the field log to [kLogLimit], oldest first, folding what goes
  /// into [trimmed] so no total built from the log ever goes down.
  void trimLog() {
    while (log.length > kLogLimit) {
      trimmed.add(log.removeLast());
    }
  }

  /// Every expedition ever banked, including those trimmed from the log.
  int get expeditions => trimmed.runs + log.length;

  /// Total protected minutes across every run - the headline stat.
  int get totalFocusMinutes =>
      (trimmed.seconds + log.fold(0, (sum, r) => sum + r.elapsedSeconds)) ~/
      60;

  /// Mean Integrity across every run, 0..1. Zero before the first.
  double get averageIntegrity => expeditions == 0
      ? 0
      : (trimmed.integrity + log.fold(0.0, (sum, r) => sum + r.integrity)) /
          expeditions;

  /// When the first expedition set out. Null before there has been one.
  DateTime? get firstRunAt =>
      trimmed.since ?? (log.isEmpty ? null : log.last.startedAt);

  /// Days between install and the last day the app was opened. The blunt
  /// retention number for an early test.
  int get daysActive => openDays.length;

  int get cleanRuns =>
      trimmed.cleanRuns + log.where(LogTally.isClean).length;

  /// Departures met at the gate. A record, like [daysWorked]: it only goes
  /// up, and a missed morning takes nothing off it.
  int get caravansMet =>
      trimmed.caravansMet + log.where(LogTally.metCaravan).length;

  /// The Spire is unfinished. Everyone who worked on it stopped, which is
  /// why nobody knows what it is for. After the player arrives, their own
  /// hours start adding to it.
  ///
  /// One floor per [kFloorHours]. It never decays and there is no target -
  /// see the story bible: a record shows what someone did, a streak
  /// threatens what they will lose.
  static const int kFloorHours = 20;
  static const int kHistoricalFloors = 60;

  /// What the first company logged against this charter, in hours. Derived
  /// from the standing structure so the two numbers can never disagree.
  static const int kCharterHours = kFloorHours * kHistoricalFloors;

  bool get spireComplete => spireCompletedAt != null;

  int get minutesSinceSpire =>
      (totalFocusMinutes - spireCompletionMinutes).clamp(0, 1 << 30);

  int get spireFloors => minutesSinceSpire ~/ (kFloorHours * 60);

  /// Distinct days with at least one run. Deliberately not a streak: this
  /// only ever goes up, so a day away costs nothing. A record shows what
  /// someone did; a streak threatens what they will lose.
  int get daysWorked =>
      trimmed.daysWorked +
      log
          .map((r) => LogTally.dayOf(r.endedAt))
          // A day the trimmed runs end on may carry on into the log.
          .where((d) => d != trimmed.lastDay)
          .toSet()
          .length;

  // -- serialisation ---------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'v': 1,
        'guildName': guildName,
        'guildSigil': guildSigil.name,
        'campProject': campProject.name,
        'level': level,
        'xp': xp,
        'credits': credits,
        'alloy': alloy,
        'intel': intel,
        'roster': roster.map((a) => a.toJson()).toList(),
        'vault': vault.map((g) => g.toJson()).toList(),
        'facilities': facilities.map((k, v) => MapEntry(k.name, v)),
        'unlockedSectors': unlockedSectors.toList(),
        'surveyRead': surveyRead,
        'spireCompletedAt': spireCompletedAt?.toIso8601String(),
        'spireCompletionMinutes': spireCompletionMinutes,
        'spireCharterName': spireCharterName,
        'log': log.map((r) => r.toJson()).toList(),
        'trimmed': trimmed.toJson(),
        'contracts': contracts.map((c) => c.toJson()).toList(),
        'contractCounter': contractCounter,
        'caravan': caravan?.toJson(),
        'caravanClaimed': caravanClaimed,
        'caravanRead': caravanRead,
        'musicOn': musicOn,
        'musicOffered': musicOffered,
        'active': active?.toJson(),
        'pendingDebrief': pendingDebrief?.toJson(),
        'gearCounter': gearCounter,
        'runCounter': runCounter,
        'onboarded': onboarded,
        'installedAt': installedAt?.toIso8601String(),
        'appOpens': appOpens,
        'openDays': openDays,
        'manualSeenAt': manualSeenAt?.toIso8601String(),
        'manualDoneAt': manualDoneAt?.toIso8601String(),
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
      guildName: j['guildName'] as String? ?? 'The Silver Lantern',
      guildSigil: GuildSigil.fromId(j['guildSigil']),
      campProject: Facility.values.firstWhere(
        (f) => f.name == j['campProject'],
        orElse: () => Facility.forge,
      ),
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
      surveyRead: ((j['surveyRead'] as Map?) ?? {}).map(
        (k, v) => MapEntry(k as String, v as int),
      ),
      spireCompletedAt: j['spireCompletedAt'] == null
          ? null
          : DateTime.tryParse(j['spireCompletedAt'] as String),
      spireCompletionMinutes: j['spireCompletionMinutes'] as int? ?? 0,
      spireCharterName: j['spireCharterName'] as String?,
      log: ((j['log'] as List?) ?? [])
          .map((e) => RunRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      trimmed: LogTally.fromJson(j['trimmed']),
      contracts: ((j['contracts'] as List?) ?? [])
          .map((e) => Contract.fromJson(e as Map<String, dynamic>))
          .toList(),
      contractCounter: j['contractCounter'] as int? ?? 0,
      caravan: CaravanSchedule.fromJson(j['caravan']),
      caravanClaimed: j['caravanClaimed'] as String?,
      caravanRead: j['caravanRead'] as int? ?? 0,
      musicOn: j['musicOn'] as bool? ?? false,
      musicOffered: j['musicOffered'] as bool? ?? false,
      active: j['active'] == null
          ? null
          : ActiveRun.fromJson(j['active'] as Map<String, dynamic>),
      pendingDebrief: j['pendingDebrief'] == null
          ? null
          : RunRecord.fromJson(j['pendingDebrief'] as Map<String, dynamic>),
      gearCounter: j['gearCounter'] as int? ?? 0,
      runCounter: j['runCounter'] as int? ?? 0,
      onboarded: j['onboarded'] as bool? ?? false,
      installedAt: DateTime.tryParse(j['installedAt'] as String? ?? ''),
      appOpens: j['appOpens'] as int? ?? 0,
      openDays: (j['openDays'] as List?)?.cast<String>() ?? <String>[],
      manualSeenAt: DateTime.tryParse(j['manualSeenAt'] as String? ?? ''),
      manualDoneAt: DateTime.tryParse(j['manualDoneAt'] as String? ?? ''),
    );
  }
}

/// What the runs trimmed off the end of the field log added up to.
///
/// The log keeps the latest [GuildState.kLogLimit] runs in full. Older ones
/// are folded in here as they go, so the totals built from the log - focus
/// time, days worked, the Spire's floors - stay records that only go up,
/// rather than a window that slides.
class LogTally {
  int runs;
  int seconds;

  /// Summed, for the average.
  double integrity;
  int cleanRuns;
  int caravansMet;
  int daysWorked;

  /// The day of the newest run folded in, so a day that carries on into the
  /// log is not counted twice.
  String? lastDay;

  /// When the very first run set out.
  DateTime? since;

  LogTally({
    this.runs = 0,
    this.seconds = 0,
    this.integrity = 0,
    this.cleanRuns = 0,
    this.caravansMet = 0,
    this.daysWorked = 0,
    this.lastDay,
    this.since,
  });

  static bool isClean(RunRecord r) => r.integrity >= 0.999;
  static bool metCaravan(RunRecord r) => (r.caravan ?? 0) >= 1 && !r.recalled;
  static String dayOf(DateTime t) => '${t.year}-${t.month}-${t.day}';

  /// Folds in [r]. Called oldest first.
  void add(RunRecord r) {
    runs++;
    seconds += r.elapsedSeconds;
    integrity += r.integrity;
    if (isClean(r)) cleanRuns++;
    if (metCaravan(r)) caravansMet++;
    final day = dayOf(r.endedAt);
    if (day != lastDay) {
      daysWorked++;
      lastDay = day;
    }
    since ??= r.startedAt;
  }

  Map<String, dynamic> toJson() => {
        'runs': runs,
        'seconds': seconds,
        'integrity': integrity,
        'cleanRuns': cleanRuns,
        'caravansMet': caravansMet,
        'daysWorked': daysWorked,
        'lastDay': lastDay,
        'since': since?.toIso8601String(),
      };

  /// Saves from before the log was ever trimmed have none: a zero tally,
  /// which is exactly right for them.
  factory LogTally.fromJson(Object? raw) {
    if (raw is! Map) return LogTally();
    return LogTally(
      runs: raw['runs'] as int? ?? 0,
      seconds: raw['seconds'] as int? ?? 0,
      integrity: (raw['integrity'] as num?)?.toDouble() ?? 0,
      cleanRuns: raw['cleanRuns'] as int? ?? 0,
      caravansMet: raw['caravansMet'] as int? ?? 0,
      daysWorked: raw['daysWorked'] as int? ?? 0,
      lastDay: raw['lastDay'] as String?,
      since: DateTime.tryParse(raw['since'] as String? ?? ''),
    );
  }
}

/// Everything the forge can make: the loot pools of every sector you have
/// opened. Charting a place is what teaches you to build its equipment.
List<GearDef> craftableGear(GuildState g) {
  final ids = <String>{};
  for (final s in kSectors) {
    if (g.sectorUnlocked(s.id)) ids.addAll(s.lootPool);
  }
  final out = ids.map((i) => kGear[i]!).toList();
  out.sort((a, b) {
    final r = a.rarity.index.compareTo(b.rarity.index);
    return r != 0 ? r : a.name.compareTo(b.name);
  });
  return out;
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
    out.add('Another squad slot: send one more member on every run');
  }
  for (final c in kClasses.values) {
    if (c.recruitCost > 0 && c.unlockGuildLevel == level) {
      out.add('${fieldName(c.name)} available to recruit');
    }
  }
  for (final s in kSectors) {
    if (s.guildLevelToUnlock == level) {
      out.add('${fieldName(s.name)} can be opened for ${s.intelToUnlock} intel');
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
