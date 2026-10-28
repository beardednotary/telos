import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../data/content.dart';
import '../models/caravan.dart';
import '../models/guild_state.dart';
import '../models/models.dart';
import '../services/alerts.dart';
import '../services/contracts.dart';
import '../services/expedition_engine.dart';
import '../services/launch_actions.dart';
import '../services/lock_screen.dart';
import '../services/music.dart';
import '../services/persistence.dart';
import '../services/redeploy.dart';
import '../models/guild_identity.dart';

/// Owns the save file, the live run, and every mutation the UI can make.
class GuildController extends ChangeNotifier with WidgetsBindingObserver {
  GuildController(
    this._store, {
    Alerts? alerts,
    LockScreen? lockScreen,
    LaunchActions? launchActions,
    Music? music,
    bool launchScreen = false,
  })  : _behindLaunchScreen = launchScreen,
        _alerts = alerts ?? NoopAlerts(),
        _lockScreen = lockScreen ?? NoopLockScreen(),
        _launch = launchActions ?? NoopLaunchActions(),
        _music = music ?? NoopMusic();

  final Persistence _store;
  final Alerts _alerts;
  final LockScreen _lockScreen;
  final LaunchActions _launch;
  final Music _music;

  GuildState _g = GuildState.fresh();
  GuildState get g => _g;

  bool _ready = false;
  bool get ready => _ready;

  Timer? _ticker;

  /// Rebuilt once a second while a run is live, for the countdown.
  DateTime now = DateTime.now();

  Future<void> boot() async {
    _g = await _store.load();
    _unreadableSave = await _store.unreadableSave();
    await _courtesy(_alerts.init);
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
      await _scheduleReturn(restored);
      // Same for the lock screen countdown, which a force stop can take
      // with it.
      await _showLockScreen(restored);
    } else {
      // Nothing live: sweep up any countdown left over from a run that ended
      // while the app was dead.
      await _courtesy(_lockScreen.clear);
    }
    _noteOpen();
    // The board is always full, so there is never a refresh to remember.
    ContractBoard.refill(_g);
    await _armCaravan();
    _ready = true;
    _syncTicker();
    notifyListeners();
    await _courtesy(() => _launch.listen(launchPick));
  }

  /// Notifications, the lock screen countdown and the widget are courtesies
  /// around a run, not the run. A platform that refuses one must not stop a
  /// squad going out, coming home, or being banked, so failures are logged
  /// and the caller carries on. Returns whether the call went through.
  Future<bool> _courtesy(Future<void> Function() call) async {
    try {
      await call();
      return true;
    } catch (e) {
      debugPrint('Telos: platform call failed: $e');
      return false;
    }
  }

  Future<void> _scheduleReturn(ActiveRun run) => _courtesy(() =>
      _alerts.scheduleReturn(
        at: run.endsAt,
        sector: sectorById(run.sectorId).name,
        squad: _squadLabel(run.squad),
      ));

  /// Clears the return notice and the countdown for a run that is over.
  Future<void> _clearRunAlerts() async {
    await _courtesy(_alerts.cancel);
    await _courtesy(_lockScreen.clear);
  }

  /// One line of local bookkeeping per launch: how many times, and on which
  /// distinct days. Never sent anywhere.
  void _noteOpen() {
    _g.installedAt ??= DateTime.now();
    _g.appOpens++;
    _noteDay();
    unawaited(_save());
  }

  /// Stamps today as a day the app was used. Called on launch and on every
  /// return from the background: iOS keeps the app suspended for days, so a
  /// launch-only stamp misses most of the days a player actually came back.
  /// Returns whether today was new.
  bool _noteDay() {
    final now = DateTime.now();
    final day = '${now.year}-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
    if (_g.openDays.contains(day)) return false;
    _g.openDays.add(day);
    if (_g.openDays.length > 400) _g.openDays.removeAt(0);
    return true;
  }

  /// A save that could not be read, set aside by [Persistence] before the
  /// fresh guild replaced it. Shown before anything else, so a guild that
  /// vanished is explained rather than greeted with the briefing as if
  /// nothing had been there.
  String? _unreadableSave;
  String? get unreadableSave => _unreadableSave;

  Future<void> dismissUnreadableSave() async {
    _unreadableSave = null;
    await _store.dismissUnreadableSave();
    notifyListeners();
  }

  /// Called when the manual is first shown, so bouncing off it is visible.
  Future<void> noteManualSeen() async {
    if (_g.manualSeenAt != null) return;
    _g.manualSeenAt = DateTime.now();
    await _save();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    unawaited(_music.pause(fade: false));
    super.dispose();
  }

  Future<void> _save() async {
    await _store.save(_g);
    // Forgotten on failure, so the next save offers it again.
    if (!await _courtesy(_publishLaunchItems)) _publishedLaunch = null;
  }

  // -- launch actions: redeploy from outside the app --------------------------

  String? _publishedLaunch;

  /// Keeps the icon menu, the Shortcuts action and the widget offering what
  /// SEND AGAIN offers, and the widget showing a squad that is out. Runs on
  /// every save, and only reaches the platform on a change.
  Future<void> _publishLaunchItems() async {
    final items = [
      for (final d in recentDispatches(_g))
        LaunchItem(
          key: d.key,
          title: sectorById(d.sectorId).name,
          subtitle: '${d.minutes} MIN · ${[
            for (final id in d.squad) _g.memberById(id)?.name
          ].whereType<String>().join(', ')}',
          accent: sectorById(d.sectorId).accent,
        ),
    ];
    final live = _g.active;
    final run = live == null
        ? null
        : LaunchRun(
            sectorName: sectorById(live.sectorId).name,
            accent: sectorById(live.sectorId).accent,
            endsAt: live.endsAt,
          );
    final signature = jsonEncode({
      'items': [for (final i in items) i.toJson()],
      'run': run?.toJson(),
    });
    if (signature == _publishedLaunch) return;
    _publishedLaunch = signature;
    await _launch.publish(items, run: run);
  }

  /// A dispatch picked from the icon menu or the Shortcuts action.
  ///
  /// It must start a run whenever one can start, because the player may have
  /// set this off from a Focus automation and already put the phone down: a
  /// debrief left open with no squad out would be a silent failure. So a run
  /// that came back while the app was closed is received first, and a debrief
  /// still waiting is skipped - its loot is already banked and it stays in
  /// the field log. A run still out is simply shown.
  Future<void> launchPick(String key) async {
    if (!_ready || !_g.onboarded) return;
    final live = _g.active;
    if (live != null) {
      if (!live.isComplete(DateTime.now())) return;
      // Its debrief is skipped for the next run, so no chime for it either.
      await finishRun(recalled: false, chime: false);
    }

    final options = recentDispatches(_g);
    final pick = key == LaunchActions.latest
        ? options.firstOrNull
        : options.where((d) => d.key == key).firstOrNull;
    if (pick == null) {
      notifyListeners();
      return;
    }
    _g.pendingDebrief = null;
    await redeploy(pick);
  }

  // -- lifecycle: the integrity signal ---------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _foreground = false;
      case AppLifecycleState.inactive:
        break;
    }
    _syncMusic();
    if (state == AppLifecycleState.resumed && _ready) {
      if (_noteDay()) unawaited(_save());
      // Notices are armed a week ahead from the last open; coming back
      // extends them, and a clock or timezone change gets picked up.
      unawaited(_armCaravan());
      // The caravan card on camp reads the time; let it catch up.
      if (_g.caravan != null && _g.active == null) notifyListeners();
    }
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

  Future<void> _showLockScreen(ActiveRun run) {
    final sector = sectorById(run.sectorId);
    return _courtesy(() => _lockScreen.show(
          startedAt: run.startedAt,
          endsAt: run.endsAt,
          sector: sector.name,
          designation: sector.designation,
          accent: sector.accent,
        ));
  }

  Future<void>? _dispatching;

  Future<void> startRun({
    required String sectorId,
    required String intent,
    required List<String> squad,
    required int minutes,
  }) {
    if (hasActiveRun) return Future.value();
    if (_dispatching != null) return _dispatching!;
    final pending = _startRun(
      sectorId: sectorId,
      intent: intent,
      squad: squad,
      minutes: minutes,
    );
    _dispatching = pending;
    return pending.whenComplete(() => _dispatching = null);
  }

  Future<void> _startRun({
    required String sectorId,
    required String intent,
    required List<String> squad,
    required int minutes,
  }) async {
    // Ask before the clock starts, so a permission dialog never eats into the
    // session the user just committed to.
    await _courtesy(_alerts.requestPermission);

    final t = DateTime.now();
    final caravan = caravanAt(t);
    _g.runCounter++;
    final run = _g.active = ActiveRun(
      id: 'r${_g.runCounter}-${t.millisecondsSinceEpoch}',
      sectorId: sectorId,
      intent: intent.trim(),
      squad: squad,
      startedAt: t,
      plannedMinutes: minutes,
      watchingSince: t,
      caravan: caravan?.strength,
      caravanDay: caravan?.day,
    );
    // The run exists once it is saved, and not before: a run only in memory
    // would vanish with the app. If the save fails, the squad is still at
    // camp, which is what the dispatch screen tells the player.
    try {
      await _save();
    } catch (_) {
      _g.active = null;
      _g.runCounter--;
      rethrow;
    }
    now = t;
    _syncTicker();
    await _scheduleReturn(run);
    await _showLockScreen(run);
    await _armCaravan();
    notifyListeners();
  }

  /// Sends an earlier dispatch again. Every way into this - the home screen
  /// today, the widget and Shortcuts later - may fire while a run is live,
  /// and none of them may start a second one.
  Future<void> redeploy(Redeploy d) async {
    if (hasActiveRun) return;
    await startRun(
      sectorId: d.sectorId,
      intent: d.intent,
      squad: List.of(d.squad),
      minutes: d.minutes,
    );
  }

  /// How long after BEGIN EXPEDITION the run can still be taken back as if it
  /// was never sent: long enough to notice the wrong sector, length or squad.
  static const cancelWindow = Duration(seconds: 30);

  bool canCancel(DateTime t) {
    final run = _g.active;
    return run != null && t.difference(run.startedAt) < cancelWindow;
  }

  /// Takes back a dispatch made by mistake. Unlike a recall it leaves no
  /// trace: no log entry, no expedition counted, no survey line spent.
  Future<bool> cancelRun() async {
    if (_resolution != null) return false;
    if (!canCancel(DateTime.now())) return false;
    _g.active = null;
    _g.runCounter--;
    await _clearRunAlerts();
    // Taken back, so the departure is still there to be met.
    await _armCaravan();
    _syncTicker();
    await _save();
    notifyListeners();
    return true;
  }

  /// Ends the run and banks everything. [recalled] = the user stopped early.
  Future<RunRecord?>? _resolution;

  /// Resume, the timer, and an explicit recall can all arrive together.
  /// Share the in-flight resolution so a run can only be banked once.
  Future<RunRecord?> finishRun({required bool recalled, bool chime = true}) {
    if (_resolution != null) return _resolution!;
    final pending = _finishRun(recalled: recalled, chime: chime);
    _resolution = pending;
    return pending.whenComplete(() => _resolution = null);
  }

  Future<RunRecord?> _finishRun(
      {required bool recalled, required bool chime}) async {
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

    await _clearRunAlerts();

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

    if (res.record.priorSurvey != null) {
      final id = res.record.sectorId;
      _g.surveyRead[id] = (_g.surveyRead[id] ?? 0) + 1;
    }

    // Arriving is recovering the last of the Spire's records - the Charter
    // under a stone on the top course. It takes a campaign of long runs in
    // Sector 05, not one lucky session.
    if (!_g.spireComplete && res.record.sectorId == 'spire') {
      final spire = sectorById('spire');
      if ((_g.surveyRead['spire'] ?? 0) >= spire.priorSurvey.length) {
        res.record.completedSpire = true;
        _g.spireCompletedAt = t;
        _g.spireCharterName = _g.guildName;
      }
    }

    ContractBoard.applyRun(_g, res.record);

    // After contracts are scored, which read the kit as it went into the
    // field: new finds must not count as carried on the run that found them.
    _wearNewFinds(run.squad, res.gear);

    // Met or followed, the departure is spent: one run per caravan.
    if (run.caravanDay != null) _g.caravanClaimed = run.caravanDay;
    if (res.record.caravanLine != null) _g.caravanRead++;

    _g.log.insert(0, res.record);
    // After the insert, so the run that arrived is counted on the Charter
    // rather than becoming the first of the floors.
    if (res.record.completedSpire) {
      _g.spireCompletionMinutes = _g.totalFocusMinutes;
    }
    if (_g.log.length > 500) _g.log.removeRange(500, _g.log.length);

    _g.active = null;
    _g.pendingDebrief = res.record;
    _ticker?.cancel();
    _ticker = null;
    if (chime && _soundWanted) unawaited(_music.chime());

    await _armCaravan();
    await _save();
    notifyListeners();
    return res.record;
  }

  // -- music -----------------------------------------------------------------

  bool _foreground = true;

  /// Every state change passes through here, so music follows the screen
  /// without any screen having to ask for it.
  @override
  void notifyListeners() {
    _syncMusic();
    super.notifyListeners();
  }

  /// At camp or on a debrief, with the app open and the player's say-so.
  /// Never during a run, and never over the first-launch briefing.
  bool get _musicWanted => _soundWanted && _g.active == null;

  /// The player's say-so, with the app open and camp on screen.
  bool get _soundWanted =>
      _ready &&
      _foreground &&
      !_behindLaunchScreen &&
      _g.onboarded &&
      _g.musicOn;

  /// Eased out when the player starts a run or turns it off; cut when they
  /// leave the app, which is already silence.
  void _syncMusic() => unawaited(
      _musicWanted ? _music.play() : _music.pause(fade: _foreground));

  bool _behindLaunchScreen;

  /// The launch screen calls this as it lifts, so the track fades in over
  /// camp instead of starting cold under the lantern.
  void launchScreenLifted() {
    if (!_behindLaunchScreen) return;
    _behindLaunchScreen = false;
    _syncMusic();
  }

  Future<void> setMusic(bool on) async {
    _g.musicOn = on;
    _g.musicOffered = true;
    await _save();
    notifyListeners();
  }

  /// Camp asks once, on the first visit after an expedition. Not before the
  /// first one: that visit is for getting a squad out.
  bool get offerMusic =>
      _g.log.isNotEmpty && !_g.musicOn && !_g.musicOffered;

  Future<void> declineMusic() async {
    _g.musicOffered = true;
    await _save();
    notifyListeners();
  }

  // -- caravan ---------------------------------------------------------------

  /// The departure a run started at [t] would go out with. Null when none is
  /// in reach, it has already been met, or its tracks have gone cold.
  CaravanStatus? caravanAt(DateTime t) {
    final status = caravanStatus(_g.caravan, t, claimedDay: _g.caravanClaimed);
    if (status == null || status.strength <= 0) return null;
    // A squad already out with it cannot be sent again.
    if (_g.active?.caravanDay == status.day) return null;
    return status;
  }

  /// Sets or clears the punch clock. Asks for notification permission, since
  /// the gate notice is most of the point.
  Future<void> setCaravan(CaravanSchedule? schedule) async {
    _g.caravan = schedule;
    if (schedule != null) await _courtesy(_alerts.requestPermission);
    await _armCaravan();
    await _save();
    notifyListeners();
  }

  String? _armedCaravan;

  /// Rebuilds the week of caravan notices from the current schedule, run and
  /// claim. Cheap to call often: it only reaches the platform on a change.
  Future<void> _armCaravan() async {
    final run = _g.active;
    final notices = caravanNotices(
      schedule: _g.caravan,
      now: DateTime.now(),
      claimedDay: _g.caravanClaimed,
      runStart: run?.startedAt,
      runEnd: run?.endsAt,
      runDay: run?.caravanDay,
    );
    final signature = [
      for (final n in notices) '${n.at.toIso8601String()} ${n.title}',
    ].join('|');
    if (signature == _armedCaravan) return;
    _armedCaravan = signature;
    // Forgotten on failure, so the next call tries again.
    if (!await _courtesy(() => _alerts.scheduleCaravan(notices))) {
      _armedCaravan = null;
    }
  }

  /// Puts each new find straight on whoever brought it home, if they have
  /// an empty slot. Never replaces anything: a player who arranges kit by
  /// hand keeps their arrangement, and a player who never opens the roster
  /// still gets the benefit of what they found.
  void _wearNewFinds(List<String> squad, List<Gear> finds) {
    final pending = [...finds]..sort((a, b) => gearById(b.defId)
        .rarity
        .index
        .compareTo(gearById(a.defId).rarity.index));
    for (final gear in pending) {
      for (final id in squad) {
        final m = _g.memberById(id);
        if (m != null && m.equipped.length < kGearSlots) {
          m.equipped.add(gear.uid);
          break;
        }
      }
    }
  }

  /// Who is wearing [gearUid], if anyone. For the debrief's "KAEL is
  /// wearing it" line.
  Adventurer? wearerOf(String gearUid) {
    for (final m in _g.roster) {
      if (m.equipped.contains(gearUid)) return m;
    }
    return null;
  }

  Future<void> completeOnboarding() async {
    _g.onboarded = true;
    _g.manualDoneAt = DateTime.now();
    await _save();
    notifyListeners();
  }

  // -- contracts ---------------------------------------------------------

  List<Contract> get contracts => _g.contracts;
  int get claimableContracts => _g.contracts.where((c) => c.done).length;

  /// Takes an unfinished contract off the board for nothing and posts a
  /// different one. Nothing expires, so without this an order that does not
  /// suit the player would sit in its slot for good.
  Future<bool> setAsideContract(String id) async {
    final i = _g.contracts.indexWhere((c) => c.id == id && !c.done);
    if (i < 0) return false;
    final c = _g.contracts.removeAt(i);
    ContractBoard.refill(_g, setAside: c);
    await _save();
    notifyListeners();
    return true;
  }

  /// Pays out and replaces the slot.
  Future<Contract?> claimContract(String id) async {
    final i = _g.contracts.indexWhere((c) => c.id == id && c.done);
    if (i < 0) return null;
    final c = _g.contracts.removeAt(i);

    _g.credits += c.rewardCredits;
    _g.alloy += c.rewardAlloy;
    _g.intel += c.rewardIntel;
    _g.xp += c.rewardXp;
    while (_g.xp >= GuildState.xpForGuildLevel(_g.level)) {
      _g.xp -= GuildState.xpForGuildLevel(_g.level);
      _g.level++;
    }

    ContractBoard.refill(_g);
    await _save();
    notifyListeners();
    return c;
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

  Future<void> equip(String memberId, String gearUid,
      {String? replacingUid}) async {
    final m = _g.memberById(memberId);
    if (m == null || _g.gearByUid(gearUid) == null) return;
    if (m.equipped.contains(gearUid)) return;
    // A slot review names the piece it replaces. Reject stale reviews rather
    // than silently removing a different piece of equipment.
    if (replacingUid != null && !m.equipped.contains(replacingUid)) return;
    final slot = replacingUid == null ? -1 : m.equipped.indexOf(replacingUid);
    // Take it off whoever is wearing it.
    for (final other in _g.roster) {
      other.equipped.remove(gearUid);
    }
    if (slot >= 0) {
      m.equipped[slot] = gearUid;
    } else {
      if (m.equipped.length >= kGearSlots) {
        m.equipped.removeAt(0);
      }
      m.equipped.add(gearUid);
    }
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
    if (name.trim().isEmpty) return;
    await updateGuildIdentity(name, _g.guildSigil);
  }

  Future<void> updateGuildIdentity(String name, GuildSigil sigil) async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty || clean.characters.length > guildNameLimit) {
      throw ArgumentError('Use a guild name of 1–$guildNameLimit characters.');
    }
    _g.guildName = clean;
    _g.guildSigil = sigil;
    await _save();
    notifyListeners();
  }

  Future<void> selectCampProject(Facility facility) async {
    _g.campProject = facility;
    await _save();
    notifyListeners();
  }

  /// Replaces everything with a restored save. Destructive by definition -
  /// the caller confirms.
  Future<void> restore(GuildState state) async {
    _ticker?.cancel();
    _ticker = null;
    await _clearRunAlerts();
    _g = state;
    // A run that was live when the backup was taken is long over; do not
    // resurrect a countdown from another phone.
    _g.active = null;
    _g.pendingDebrief = null;
    await _armCaravan();
    await _save();
    notifyListeners();
  }

  Future<void> hardReset() async {
    _ticker?.cancel();
    _ticker = null;
    await _clearRunAlerts();
    _g = GuildState.fresh();
    await _armCaravan();
    await _store.wipe();
    notifyListeners();
  }
}
