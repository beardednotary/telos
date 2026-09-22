import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../data/content.dart';
import '../models/guild_state.dart';
import '../models/models.dart';
import '../services/alerts.dart';
import '../services/expedition_engine.dart';
import '../services/persistence.dart';

/// Owns the save file, the live run, and every mutation the UI can make.
class GuildController extends ChangeNotifier with WidgetsBindingObserver {
  GuildController(this._store, {Alerts? alerts})
      : _alerts = alerts ?? NoopAlerts();

  final Persistence _store;
  final Alerts _alerts;

  GuildState _g = GuildState.fresh();
  GuildState get g => _g;

  bool _ready = false;
  bool get ready => _ready;

  Timer? _ticker;

  /// Rebuilt once a second while a run is live, for the countdown.
  DateTime now = DateTime.now();

  Future<void> boot() async {
    _g = await _store.load();
    await _alerts.init();
    WidgetsBinding.instance.addObserver(this);
    // The app is in the foreground right now; if a run survived a cold start,
    // resume its watch clock.
    if (_g.active != null && _g.active!.watchingSince == null) {
      _g.active!.watchingSince = DateTime.now();
    }
    // A scheduled alert can be lost to a reboot or a force stop. Re-arm it for
    // any run that survived the restart.
    final restored = _g.active;
    if (restored != null && !restored.isComplete(DateTime.now())) {
      await _alerts.scheduleReturn(
        at: restored.endsAt,
        sector: sectorById(restored.sectorId).name,
        squad: _squadLabel(restored.squad),
      );
    }
    _ready = true;
    _syncTicker();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _save() => _store.save(_g);

  // -- lifecycle: the integrity signal ---------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final run = _g.active;
    if (run == null) return;
    final t = DateTime.now();

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Phone down. Bank the screen time and stop the watch clock.
        if (run.watchingSince != null) {
          final until = t.isAfter(run.endsAt) ? run.endsAt : t;
          final d = until.difference(run.watchingSince!).inSeconds;
          if (d > 0) run.watchSeconds += d;
          run.watchingSince = null;
        }
        _save();
      case AppLifecycleState.resumed:
        // Coming back before the run ends is the thing that costs you - but
        // only if we actually went away. iOS fires inactive -> resumed for
        // things the user did not do: the notification permission dialog, an
        // incoming banner, a Control Centre swipe. None of those background
        // the app, so watchingSince is still set, and charging a check-in for
        // them means a run can open below 100% before the user has touched
        // anything.
        if (!run.isComplete(t) && run.watchingSince == null) {
          run.checkIns++;
          run.watchingSince = t;
        }
        _save();
        notifyListeners();
      case AppLifecycleState.inactive:
        break; // transient (notification shade, call banner) - ignore
    }
    _syncTicker();
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (_g.active == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      now = DateTime.now();
      notifyListeners();
    });
  }

  // -- the run ---------------------------------------------------------------

  bool get hasActiveRun => _g.active != null;
  ActiveRun? get active => _g.active;
  RunRecord? get pendingDebrief => _g.pendingDebrief;

  /// "KAEL" / "KAEL and MIRA" / "The squad" - for notification copy.
  String _squadLabel(List<String> ids) {
    final names = ids
        .map((id) => _g.memberById(id))
        .whereType<Adventurer>()
        .map((m) => m.name)
        .toList();
    if (names.isEmpty) return 'The squad';
    if (names.length == 1) return names.single;
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    return '${names.first} and ${names.length - 1} others';
  }

  Future<void> startRun({
    required String sectorId,
    required String intent,
    required List<String> squad,
    required int minutes,
  }) async {
    // Ask before the clock starts, so a permission dialog never eats into the
    // session the user just committed to.
    await _alerts.requestPermission();

    final t = DateTime.now();
    _g.runCounter++;
    _g.active = ActiveRun(
      id: 'r${_g.runCounter}-${t.millisecondsSinceEpoch}',
      sectorId: sectorId,
      intent: intent.trim(),
      squad: squad,
      startedAt: t,
      plannedMinutes: minutes,
      watchingSince: t,
    );
    now = t;
    _syncTicker();
    await _alerts.scheduleReturn(
      at: _g.active!.endsAt,
      sector: sectorById(sectorId).name,
      squad: _squadLabel(squad),
    );
    await _save();
    notifyListeners();
  }

  /// Ends the run and banks everything. [recalled] = the user stopped early.
  Future<RunRecord?> finishRun({required bool recalled}) async {
    final run = _g.active;
    if (run == null) return null;
    final t = DateTime.now();

    // Close out any open watch stretch first so integrity is final.
    if (run.watchingSince != null) {
      final until = t.isAfter(run.endsAt) ? run.endsAt : t;
      final d = until.difference(run.watchingSince!).inSeconds;
      if (d > 0) run.watchSeconds += d;
      run.watchingSince = null;
    }

    await _alerts.cancel();

    final res = ExpeditionEngine.resolve(
      run: run,
      guild: _g,
      now: t,
      recalled: recalled,
    );

    // Bank it.
    _g.credits += res.record.credits;
    _g.alloy += res.record.alloy;
    _g.intel += res.record.intel;
    _g.vault.addAll(res.gear);
    _g.gearCounter += res.gear.length;

    for (final entry in res.record.xpGained.entries) {
      final m = _g.memberById(entry.key);
      if (m == null) continue;
      m.xp += entry.value;
      while (m.xp >= Adventurer.xpForLevel(m.level)) {
        m.xp -= Adventurer.xpForLevel(m.level);
        m.level++;
      }
    }

    _g.xp += res.record.guildXp;
    while (_g.xp >= GuildState.xpForGuildLevel(_g.level)) {
      _g.xp -= GuildState.xpForGuildLevel(_g.level);
      _g.level++;
    }

    _g.log.insert(0, res.record);
    if (_g.log.length > 500) _g.log.removeRange(500, _g.log.length);

    _g.active = null;
    _g.pendingDebrief = res.record;
    _ticker?.cancel();
    _ticker = null;

    await _save();
    notifyListeners();
    return res.record;
  }

  Future<void> completeOnboarding() async {
    _g.onboarded = true;
    await _save();
    notifyListeners();
  }

  Future<void> recordProgress(String answer, {String? note}) async {
    final r = _g.pendingDebrief;
    if (r == null) return;
    r.progress = answer;
    r.note = (note != null && note.trim().isNotEmpty) ? note.trim() : null;
    // The stored log entry is the same object reference; keep them in sync.
    final logged = _g.log.where((e) => e.id == r.id).toList();
    for (final e in logged) {
      e.progress = r.progress;
      e.note = r.note;
    }
    await _save();
    notifyListeners();
  }

  Future<void> dismissDebrief() async {
    _g.pendingDebrief = null;
    await _save();
    notifyListeners();
  }

  // -- roster ----------------------------------------------------------------

  Future<void> equip(String memberId, String gearUid) async {
    final m = _g.memberById(memberId);
    if (m == null) return;
    // Take it off whoever is wearing it.
    for (final other in _g.roster) {
      other.equipped.remove(gearUid);
    }
    if (m.equipped.length >= kGearSlots) {
      m.equipped.removeAt(0);
    }
    m.equipped.add(gearUid);
    await _save();
    notifyListeners();
  }

  Future<void> unequip(String memberId, String gearUid) async {
    _g.memberById(memberId)?.equipped.remove(gearUid);
    await _save();
    notifyListeners();
  }

  bool canRecruit(ClassDef c) =>
      _g.roster.length < _g.rosterSlots &&
      _g.credits >= c.recruitCost &&
      _g.level >= c.unlockGuildLevel;

  Future<Adventurer?> recruit(ClassDef c) async {
    if (!canRecruit(c)) return null;
    _g.credits -= c.recruitCost;
    final taken = _g.roster.map((a) => a.name).toSet();
    final pool = kNames.where((n) => !taken.contains(n)).toList();
    final name = pool.isEmpty
        ? 'UNIT-${_g.roster.length + 1}'
        : pool[Random().nextInt(pool.length)];
    final a = Adventurer(
      id: 'a${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      classId: c.id,
    );
    _g.roster.add(a);
    await _save();
    notifyListeners();
    return a;
  }

  // -- outpost ---------------------------------------------------------------

  bool canUpgrade(Facility f) {
    final (c, a) = f.costAt(_g.facilities[f]!);
    return _g.credits >= c && _g.alloy >= a;
  }

  Future<void> upgrade(Facility f) async {
    if (!canUpgrade(f)) return;
    final (c, a) = f.costAt(_g.facilities[f]!);
    _g.credits -= c;
    _g.alloy -= a;
    _g.facilities[f] = _g.facilities[f]! + 1;
    await _save();
    notifyListeners();
  }

  // -- forge -----------------------------------------------------------------

  int get forgeLevel => _g.facilities[Facility.forge]!;

  bool forgeCanWork(Rarity r) => forgeLevel >= kForgeLevelFor[r]!;

  bool canCraft(GearDef def) {
    if (!forgeCanWork(def.rarity)) return false;
    final c = kCraftCost[def.rarity]!;
    return _g.credits >= c.credits &&
        _g.alloy >= c.alloy &&
        _g.intel >= c.intel;
  }

  Future<Gear?> craft(GearDef def) async {
    if (!canCraft(def)) return null;
    final c = kCraftCost[def.rarity]!;
    _g.credits -= c.credits;
    _g.alloy -= c.alloy;
    _g.intel -= c.intel;
    final gear = Gear('g${_g.gearCounter++}', def.id);
    _g.vault.add(gear);
    await _save();
    notifyListeners();
    return gear;
  }

  /// Only unassigned gear can be melted - taking something off a member to
  /// destroy it should be a deliberate two-step.
  Future<int?> melt(Gear gear) async {
    if (!_g.unequippedGear.any((x) => x.uid == gear.uid)) return null;
    final value = kMeltValue[gearById(gear.defId).rarity]!;
    _g.vault.removeWhere((x) => x.uid == gear.uid);
    _g.alloy += value;
    await _save();
    notifyListeners();
    return value;
  }

  bool canUnlock(Sector s) =>
      !_g.sectorUnlocked(s.id) &&
      _g.level >= s.guildLevelToUnlock &&
      _g.intel >= s.intelToUnlock;

  Future<void> unlockSector(Sector s) async {
    if (!canUnlock(s)) return;
    _g.intel -= s.intelToUnlock;
    _g.unlockedSectors.add(s.id);
    await _save();
    notifyListeners();
  }

  /// Sectors this squad could actually reach with [minutes] on the clock.
  List<Sector> availableSectors(int minutes) => kSectors
      .where((s) => _g.sectorUnlocked(s.id) && s.minMinutes <= minutes)
      .toList();

  Future<void> renameGuild(String name) async {
    _g.guildName = name.trim().isEmpty ? _g.guildName : name.trim().toUpperCase();
    await _save();
    notifyListeners();
  }

  /// Replaces everything with a restored save. Destructive by definition -
  /// the caller confirms.
  Future<void> restore(GuildState state) async {
    _ticker?.cancel();
    _ticker = null;
    await _alerts.cancel();
    _g = state;
    // A run that was live when the backup was taken is long over; do not
    // resurrect a countdown from another phone.
    _g.active = null;
    _g.pendingDebrief = null;
    await _save();
    notifyListeners();
  }

  Future<void> hardReset() async {
    _ticker?.cancel();
    _ticker = null;
    await _alerts.cancel();
    _g = GuildState.fresh();
    await _store.wipe();
    notifyListeners();
  }
}
