import 'dart:math';

/// ---------------------------------------------------------------------------
/// RESOURCES
/// Three currencies. Everything a session produces lands in one of these.
///   credits - general spending: recruiting, facility upgrades
///   alloy   - construction material: facility upgrades
///   intel   - knowledge: unlocks new sectors (the "content gate")
/// ---------------------------------------------------------------------------
enum Res { credits, alloy, intel }

extension ResName on Res {
  String get label => switch (this) {
        Res.credits => 'CREDITS',
        Res.alloy => 'ALLOY',
        Res.intel => 'INTEL',
      };
}

/// Rarity = how good/uncommon a piece of gear is. Standard RPG ladder.
enum Rarity { common, uncommon, rare, epic }

extension RarityName on Rarity {
  String get label => name.toUpperCase();
}

/// ---------------------------------------------------------------------------
/// BONUSES
/// A flat bundle of percentage modifiers. Classes, gear and facilities all
/// produce one of these; they get summed, then applied to the raw yield.
/// 0.20 means "+20%".
/// ---------------------------------------------------------------------------
class Bonus {
  final double credits;
  final double alloy;
  final double intel;
  final double rare; // chance of finding a gear item
  final double xp;

  const Bonus({
    this.credits = 0,
    this.alloy = 0,
    this.intel = 0,
    this.rare = 0,
    this.xp = 0,
  });

  Bonus operator +(Bonus o) => Bonus(
        credits: credits + o.credits,
        alloy: alloy + o.alloy,
        intel: intel + o.intel,
        rare: rare + o.rare,
        xp: xp + o.xp,
      );

  Bonus scaled(double f) => Bonus(
        credits: credits * f,
        alloy: alloy * f,
        intel: intel * f,
        rare: rare * f,
        xp: xp * f,
      );

  static const none = Bonus();

  /// Human-readable summary, e.g. "+20% ALLOY".
  List<String> get lines {
    final out = <String>[];
    void add(String n, double v) {
      if (v.abs() > 0.0001) {
        out.add('${v > 0 ? '+' : ''}${(v * 100).round()}% $n');
      }
    }

    add('CREDITS', credits);
    add('ALLOY', alloy);
    add('INTEL', intel);
    add('RARE FIND', rare);
    add('XP', xp);
    return out;
  }
}

/// ---------------------------------------------------------------------------
/// CLASSES
/// A "class" is a role archetype. Each one is good at a different *session
/// length*, which is the whole point: your real working style picks your squad.
/// Nobody is strictly stronger - they are differently shaped.
/// ---------------------------------------------------------------------------
class ClassDef {
  final String id;
  final String name;
  final String blurb;
  final Bonus base;

  /// The session length (minutes) this class is built for. Running inside the
  /// window grants [windowBonus].
  final int windowMin;
  final int windowMax;
  final Bonus windowBonus;
  final String windowText;

  /// Credits cost to recruit, and the guild level that makes them available.
  final int recruitCost;
  final int unlockGuildLevel;

  const ClassDef({
    required this.id,
    required this.name,
    required this.blurb,
    required this.base,
    required this.windowMin,
    required this.windowMax,
    required this.windowBonus,
    required this.windowText,
    required this.recruitCost,
    this.unlockGuildLevel = 1,
  });
}

/// ---------------------------------------------------------------------------
/// GEAR
/// [GearDef] is the template ("Archivist Optic"). [Gear] is one you own.
/// ---------------------------------------------------------------------------
class GearDef {
  final String id;
  final String name;
  final Rarity rarity;
  final Bonus bonus;
  final String flavor;

  const GearDef({
    required this.id,
    required this.name,
    required this.rarity,
    required this.bonus,
    this.flavor = '',
  });
}

class Gear {
  final String uid; // unique instance id
  final String defId;
  Gear(this.uid, this.defId);

  Map<String, dynamic> toJson() => {'uid': uid, 'defId': defId};
  factory Gear.fromJson(Map<String, dynamic> j) =>
      Gear(j['uid'] as String, j['defId'] as String);
}

/// What it costs to forge a piece of gear, and what melting one returns.
///
/// INTEL had exactly one sink - opening sectors, 5,480 of it in total - after
/// which it accumulated forever with nothing to spend it on. Worse, the
/// ARCHIVIST exists to produce intel, so investing in one eventually bought a
/// member whose whole purpose was a dead stat. The forge is that sink.
class CraftCost {
  final int credits;
  final int alloy;
  final int intel;
  const CraftCost(this.credits, this.alloy, this.intel);
}

/// Priced in hours of clean focus, measured by test/economy_test.dart against
/// the real engine rather than guessed: roughly 1h, 2h, 7h and 22h at the
/// sectors a player would actually be running when each tier matters. INTEL is
/// the binding constraint at the top, which is the point - the forge exists to
/// be somewhere for intel to go.
const Map<Rarity, CraftCost> kCraftCost = {
  Rarity.common: CraftCost(160, 60, 25),
  Rarity.uncommon: CraftCost(520, 190, 140),
  Rarity.rare: CraftCost(1600, 520, 520),
  Rarity.epic: CraftCost(5200, 1500, 1600),
};

/// Melting returns alloy only, and less than forging cost. The vault is for
/// keeping things, not for laundering them.
const Map<Rarity, int> kMeltValue = {
  Rarity.common: 24,
  Rarity.uncommon: 75,
  Rarity.rare: 200,
  Rarity.epic: 560,
};

/// The forge level needed to work at each rarity, so the deep tiers stay
/// something to build toward rather than something to buy on day one.
const Map<Rarity, int> kForgeLevelFor = {
  Rarity.common: 1,
  Rarity.uncommon: 1,
  Rarity.rare: 3,
  Rarity.epic: 5,
};

/// ---------------------------------------------------------------------------
/// ADVENTURER
/// One member of your guild. Gains XP from sessions, levels up, holds gear.
/// ---------------------------------------------------------------------------
const int kGearSlots = 2;

class Adventurer {
  final String id;
  String name;
  final String classId;
  int level;
  int xp;
  List<String> equipped; // Gear.uid, max kGearSlots

  Adventurer({
    required this.id,
    required this.name,
    required this.classId,
    this.level = 1,
    this.xp = 0,
    List<String>? equipped,
  }) : equipped = equipped ?? <String>[];

  /// XP needed to go from [level] to level+1. Grows so later levels feel earned.
  static int xpForLevel(int level) => (80 * pow(level, 1.35)).round();

  int get xpToNext => xpForLevel(level);

  /// Levels scale a member's output a little: +4% to everything per level.
  Bonus get levelBonus {
    final f = (level - 1) * 0.04;
    return Bonus(credits: f, alloy: f, intel: f, rare: f * 0.25);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'classId': classId,
        'level': level,
        'xp': xp,
        'equipped': equipped,
      };

  factory Adventurer.fromJson(Map<String, dynamic> j) => Adventurer(
        id: j['id'] as String,
        name: j['name'] as String,
        classId: j['classId'] as String,
        level: j['level'] as int? ?? 1,
        xp: j['xp'] as int? ?? 0,
        equipped: (j['equipped'] as List?)?.cast<String>() ?? <String>[],
      );
}

/// ---------------------------------------------------------------------------
/// SECTOR
/// A destination. Each has a *minimum* session length - send the squad
/// somewhere for less time than that and they come back with scraps. This is
/// what makes one 90-minute work block different from three 30-minute ones.
/// ---------------------------------------------------------------------------
class Sector {
  final String id;
  final String name;
  final String designation; // e.g. "SECTOR 01"
  final String blurb;
  final String kind; // RECON / EXTRACTION / ARCHIVE / ASSAULT

  final int minMinutes; // below this: scraps only
  final int nominalMinutes; // 100% depth reference

  final double creditsPerMin;
  final double alloyPerMin;
  final double intelPerMin;

  /// Base chance of a gear find on a full-depth, 100%-integrity run.
  final double baseRare;

  /// Gear templates this sector can drop.
  final List<String> lootPool;

  /// Unlock gate. Sector 01 is free; the rest cost INTEL.
  final int intelToUnlock;
  final int guildLevelToUnlock;

  final List<String> journal; // flavor lines shown in the debrief

  /// Traces of the company that worked this ground before, in order, one per
  /// run. Unlike [journal] these are read once each and never repeat - see
  /// the story bible for why they may never gate anything or be counted at
  /// the player.
  final List<String> priorSurvey;

  /// Every sector owns a colour. The app takes it on wherever that sector is
  /// the subject - dispatch, the live run, the debrief, the log - so the
  /// screens stop being five views of the same amber.
  final int accent;

  const Sector({
    required this.id,
    required this.name,
    required this.designation,
    required this.blurb,
    required this.kind,
    required this.minMinutes,
    required this.nominalMinutes,
    required this.creditsPerMin,
    required this.alloyPerMin,
    required this.intelPerMin,
    required this.baseRare,
    required this.lootPool,
    this.intelToUnlock = 0,
    this.guildLevelToUnlock = 1,
    this.journal = const [],
    this.priorSurvey = const [],
    required this.accent,
  });
}

/// ---------------------------------------------------------------------------
/// ACTIVE RUN
/// The live focus session. Stored by *wall-clock end time*, not by ticking a
/// counter, so it keeps running correctly with the app closed or the phone off.
/// ---------------------------------------------------------------------------
class ActiveRun {
  final String id;
  final String sectorId;
  final String intent; // what the user said they would work on
  final List<String> squad; // Adventurer ids
  final DateTime startedAt;
  final int plannedMinutes;

  /// INTEGRITY TRACKING.
  ///
  /// A deliberate inversion: this does NOT measure time away from the app.
  /// Being away is the point - the phone is face down and the squad is out.
  /// What it measures is *screen time on Telos while the run is live*: seconds
  /// spent staring at the timer, and how many times the phone got picked up
  /// again before the run ended.
  ///
  /// This is also the only thing Flutter can honestly observe. Detecting a
  /// switch to Instagram needs Android UsageStats or iOS Screen Time, which is
  /// the V2 path (see README). Until then the app measures its own screen time
  /// rather than pretending to watch the rest of the phone.
  int watchSeconds; // foreground seconds during the run
  int checkIns; // times the app was reopened mid-run
  DateTime? watchingSince; // non-null while Telos is in the foreground

  ActiveRun({
    required this.id,
    required this.sectorId,
    required this.intent,
    required this.squad,
    required this.startedAt,
    required this.plannedMinutes,
    this.watchSeconds = 0,
    this.checkIns = 0,
    this.watchingSince,
  });

  DateTime get endsAt => startedAt.add(Duration(minutes: plannedMinutes));

  int elapsedSeconds(DateTime now) {
    final e = now.difference(startedAt).inSeconds;
    return e.clamp(0, plannedMinutes * 60);
  }

  Duration remaining(DateTime now) {
    final r = endsAt.difference(now);
    return r.isNegative ? Duration.zero : r;
  }

  bool isComplete(DateTime now) => !now.isBefore(endsAt);

  /// Seconds of screen time on Telos during the run, including an in-progress
  /// stretch. Never counts past the scheduled end.
  int effectiveWatch(DateTime now) {
    var w = watchSeconds;
    if (watchingSince != null) {
      final until = now.isAfter(endsAt) ? endsAt : now;
      final extra = until.difference(watchingSince!).inSeconds;
      if (extra > 0) w += extra;
    }
    return w;
  }

  /// Grace period: enough to read the dispatch screen and put the phone down.
  static const int graceSeconds = 30;

  /// INTEGRITY - the core mechanic, 0.25 .. 1.0.
  ///
  /// After the grace period, every 30 seconds of watching the timer costs 1%,
  /// and every reopen costs a flat 4%. It degrades; it never fails you
  /// outright, and a distracted run still earns something.
  double integrity(DateTime now) {
    final watched = effectiveWatch(now);
    final billable = watched - graceSeconds < 0 ? 0 : watched - graceSeconds;
    final timePenalty = billable / 30.0 * 0.01;
    final checkPenalty = checkIns * 0.04;
    return (1.0 - timePenalty - checkPenalty).clamp(0.25, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sectorId': sectorId,
        'intent': intent,
        'squad': squad,
        'startedAt': startedAt.toIso8601String(),
        'plannedMinutes': plannedMinutes,
        'watchSeconds': watchSeconds,
        'checkIns': checkIns,
        'watchingSince': watchingSince?.toIso8601String(),
      };

  factory ActiveRun.fromJson(Map<String, dynamic> j) => ActiveRun(
        id: j['id'] as String,
        sectorId: j['sectorId'] as String,
        intent: j['intent'] as String? ?? '',
        squad: (j['squad'] as List).cast<String>(),
        startedAt: DateTime.parse(j['startedAt'] as String),
        plannedMinutes: j['plannedMinutes'] as int,
        watchSeconds: j['watchSeconds'] as int? ?? 0,
        checkIns: j['checkIns'] as int? ?? 0,
        watchingSince: j['watchingSince'] == null
            ? null
            : DateTime.parse(j['watchingSince'] as String),
      );
}

/// ---------------------------------------------------------------------------
/// RUN RECORD
/// The finished expedition: the debrief screen *and* the permanent work log.
/// Resolved once, then stored - reopening it never rerolls the loot.
/// ---------------------------------------------------------------------------
class RunRecord {
  final String id;
  final String sectorId;
  final String intent;
  final List<String> squad;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedMinutes;
  final int elapsedSeconds;
  final double integrity;
  final bool recalled; // ended early
  final bool scraps; // under the sector minimum

  final int credits;
  final int alloy;
  final int intel;
  final List<String> loot; // Gear.uid granted
  final Map<String, int> xpGained; // adventurerId -> xp
  final List<String> levelUps; // adventurerId
  final int guildXp;
  final int guildLevelUps;
  final List<String> journal;

  /// The prior-survey line this run turned up, if it was owed one. Stored on
  /// the record so the log reads back the same way months later.
  final String? priorSurvey;

  /// True on the one run that recovered the last of the Spire's records.
  /// Mutable and set by the controller rather than the engine, which stays a
  /// pure resolver and knows nothing about the guild's long arc.
  bool completedSpire;

  String? progress; // 'YES' | 'SOME' | 'NO' - honour-system self report
  String? note;

  RunRecord({
    required this.id,
    required this.sectorId,
    required this.intent,
    required this.squad,
    required this.startedAt,
    required this.endedAt,
    required this.plannedMinutes,
    required this.elapsedSeconds,
    required this.integrity,
    required this.recalled,
    required this.scraps,
    required this.credits,
    required this.alloy,
    required this.intel,
    required this.loot,
    required this.xpGained,
    required this.levelUps,
    required this.guildXp,
    required this.guildLevelUps,
    required this.journal,
    this.priorSurvey,
    this.completedSpire = false,
    this.progress,
    this.note,
  });

  int get elapsedMinutes => elapsedSeconds ~/ 60;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sectorId': sectorId,
        'intent': intent,
        'squad': squad,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'plannedMinutes': plannedMinutes,
        'elapsedSeconds': elapsedSeconds,
        'integrity': integrity,
        'recalled': recalled,
        'scraps': scraps,
        'credits': credits,
        'alloy': alloy,
        'intel': intel,
        'loot': loot,
        'xpGained': xpGained,
        'levelUps': levelUps,
        'guildXp': guildXp,
        'guildLevelUps': guildLevelUps,
        'journal': journal,
        'priorSurvey': priorSurvey,
        'completedSpire': completedSpire,
        'progress': progress,
        'note': note,
      };

  factory RunRecord.fromJson(Map<String, dynamic> j) => RunRecord(
        id: j['id'] as String,
        sectorId: j['sectorId'] as String,
        intent: j['intent'] as String? ?? '',
        squad: (j['squad'] as List).cast<String>(),
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: DateTime.parse(j['endedAt'] as String),
        plannedMinutes: j['plannedMinutes'] as int,
        elapsedSeconds: j['elapsedSeconds'] as int,
        integrity: (j['integrity'] as num).toDouble(),
        recalled: j['recalled'] as bool? ?? false,
        scraps: j['scraps'] as bool? ?? false,
        credits: j['credits'] as int? ?? 0,
        alloy: j['alloy'] as int? ?? 0,
        intel: j['intel'] as int? ?? 0,
        loot: (j['loot'] as List?)?.cast<String>() ?? <String>[],
        xpGained: (j['xpGained'] as Map?)?.map(
              (k, v) => MapEntry(k as String, v as int),
            ) ??
            <String, int>{},
        levelUps: (j['levelUps'] as List?)?.cast<String>() ?? <String>[],
        guildXp: j['guildXp'] as int? ?? 0,
        guildLevelUps: j['guildLevelUps'] as int? ?? 0,
        journal: (j['journal'] as List?)?.cast<String>() ?? <String>[],
        priorSurvey: j['priorSurvey'] as String?,
        completedSpire: j['completedSpire'] as bool? ?? false,
        progress: j['progress'] as String?,
        note: j['note'] as String?,
      );
}

/// ---------------------------------------------------------------------------
/// CONTRACTS
/// Short-term direction. See services/contracts.dart for why they exist and
/// the rules they are built to respect.
/// ---------------------------------------------------------------------------
enum ContractKind {
  sectorRuns,
  haul,
  cleanRuns,
  longRun,
  minutes,
  classRuns,
  fullDepth,
}

class Contract {
  final String id;
  final ContractKind kind;
  final String? sectorId;
  final String? classId;
  final Res? res;
  final int target;
  final int tier;
  final int rewardCredits;
  final int rewardAlloy;
  final int rewardIntel;
  final int rewardXp;
  int progress;

  Contract({
    required this.id,
    required this.kind,
    required this.target,
    required this.tier,
    required this.rewardCredits,
    required this.rewardAlloy,
    required this.rewardIntel,
    required this.rewardXp,
    this.sectorId,
    this.classId,
    this.res,
    this.progress = 0,
  });

  bool get done => progress >= target;

  /// Two contracts asking the same thing of the same place, regardless of
  /// how much - the board should never offer near-duplicates.
  bool sameShapeAs(Contract o) =>
      kind == o.kind &&
      sectorId == o.sectorId &&
      classId == o.classId &&
      res == o.res;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'sectorId': sectorId,
        'classId': classId,
        'res': res?.name,
        'target': target,
        'tier': tier,
        'rewardCredits': rewardCredits,
        'rewardAlloy': rewardAlloy,
        'rewardIntel': rewardIntel,
        'rewardXp': rewardXp,
        'progress': progress,
      };

  factory Contract.fromJson(Map<String, dynamic> j) => Contract(
        id: j['id'] as String,
        kind: ContractKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => ContractKind.cleanRuns,
        ),
        sectorId: j['sectorId'] as String?,
        classId: j['classId'] as String?,
        res: j['res'] == null
            ? null
            : Res.values.firstWhere((r) => r.name == j['res'],
                orElse: () => Res.credits),
        target: j['target'] as int? ?? 1,
        tier: j['tier'] as int? ?? 1,
        rewardCredits: j['rewardCredits'] as int? ?? 0,
        rewardAlloy: j['rewardAlloy'] as int? ?? 0,
        rewardIntel: j['rewardIntel'] as int? ?? 0,
        rewardXp: j['rewardXp'] as int? ?? 0,
        progress: j['progress'] as int? ?? 0,
      );
}

/// ---------------------------------------------------------------------------
/// FACILITIES - the guild outpost. Permanent upgrades bought with resources.
/// This is the "between sessions" layer that gives you a reason to come back.
/// ---------------------------------------------------------------------------
enum Facility { barracks, forge, archive }

extension FacilityInfo on Facility {
  String get label => switch (this) {
        Facility.barracks => 'BARRACKS',
        Facility.forge => 'FORGE',
        Facility.archive => 'ARCHIVE',
      };

  String get effect => switch (this) {
        Facility.barracks => 'Roster capacity, and +5% squad XP per level',
        Facility.forge => '+6% alloy and +2% rare find per level',
        Facility.archive => '+8% intel per level',
      };

  Bonus bonusAt(int level) {
    final n = level - 1;
    return switch (this) {
      Facility.barracks => Bonus(xp: n * 0.05),
      Facility.forge => Bonus(alloy: n * 0.06, rare: n * 0.02),
      Facility.archive => Bonus(intel: n * 0.08),
    };
  }

  /// Cost to go from [level] to level+1.
  (int, int) costAt(int level) {
    final c = (120 * pow(1.55, level - 1)).round();
    final a = (25 * pow(1.6, level - 1)).round();
    return (c, a);
  }
}
