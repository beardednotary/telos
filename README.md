# Telos

**Telos — Focus Timer RPG.** A distraction-free focus timer wrapped in an
incremental guild RPG: protected work time dispatches an adventuring squad on
expeditions, and the loot is revealed only when you stop working.

Flutter, offline-first, no accounts, no network calls.

---

## The one rule

> **Opening the app does not advance the game. Not opening it does.**

Everything below exists to serve that inversion.

---

## Core loop

```
INTENT -> DURATION -> SECTOR -> SQUAD -> [put the phone down] -> DEBRIEF -> SPEND
   ^                                                                          |
   +--------------------------------------------------------------------------+
```

1. **Dispatch** — say what you're working on, how long you have, where the
   squad goes and who goes.
2. **Session** — a countdown and nothing else. No taps, no collectibles, no
   progress ticking up on screen.
3. **Debrief** — everything the run produced, delivered at once when you come
   back. One notification fires when the run ends; that is the only thing the
   app will ever interrupt you for.
4. **Outpost** — spend what you earned: gear, recruits, facilities, new sectors.
   This is what makes you want to start the next session.

---

## The three inputs that decide a run

| Input | What it drives |
|---|---|
| **Time** | Raw quantity, and — via sector minimums — what content you can reach at all |
| **Integrity** | Quality. Scales loot quantity gently and *rare finds* steeply |
| **Squad** | Which resources you get. Each class is built for a different session length |

### Sector minimums

Each sector has a `minMinutes`. Come back under it and the squad returns with
scraps: credits only, no alloy, no intel, no salvage. This is what makes one
90-minute block mechanically different from three 30-minute ones, without ever
telling the user how long they should focus.

| Sector | Minimum | Bias |
|---|---:|---|
| Mosswood Verge | 10m | Credits |
| Blackstone Hollow | 25m | Alloy |
| The Cinder Archive | 45m | Intel |
| Riftline Descent | 75m | Everything, richly |
| The Spire of Telos | 100m | Endgame |

### Class windows

Nobody is strictly stronger — they're differently shaped, so your real working
style picks your squad.

| Class | Window | Bias |
|---|---|---|
| RECON | 10–30m | Credits, finds things |
| VANGUARD | 60m+ | Alloy |
| ARCHIVIST | 45m+ | Intel |
| ARTIFICER | 25–75m | Alloy + salvage rate |
| QUARTERMASTER | any | Steady, no sweet spot |

---

## Integrity — and an honest note about what it can measure

`ActiveRun.integrity()` is the honesty mechanic. It starts at 100% and degrades:

- **30-second grace** at dispatch (long enough to read the screen and put the
  phone down)
- **−1% per 30s** of screen time on Telos while a run is live
- **−4% per reopen** before the run ends
- **Floor of 25%** — it degrades, it never fails you

Note what this measures: **screen time on Telos**, not time away from the app.
Being away is the point.

That inversion isn't just thematic — it's the only thing Flutter can honestly
observe. `AppLifecycleState` cannot distinguish "locked the phone" from
"switched to Instagram"; both are `paused`. Rather than pretend to watch the
rest of the device, V1 measures its own screen time and treats the work report
as an honour system. Per the design notes: no leaderboards, no trading, no
real-money prizes — so there's nobody to cheat but yourself.

**V2 path** (real distraction detection, both platform-specific):

- **Android** — `UsageStatsManager` with usage-access permission gives
  foreground package events, so the app can see the switch to another app.
- **iOS** — `FamilyControls` / `ManagedSettings` can *block* a chosen set of
  apps for the duration of a session ("Protected Expedition"), which is a
  better product than detection anyway. `DeviceActivity` fires on schedule
  boundaries and usage thresholds, not a live app-switch stream.

Both need a platform channel and entitlements; neither belongs in V1.

---

## The one notification

`lib/services/alerts.dart`. Exactly one alert exists: *"KAEL returned from
Mosswood Verge."* No streak nagging, no daily reminders, nothing the user did
not personally start.

- Scheduled at dispatch, cancelled the moment a run is recalled or received
- Permission is requested **at the first dispatch**, not at launch, so the
  prompt arrives with an obvious reason attached
- Re-armed on cold start for any run still in progress, in case the OS dropped
  the alarm
- Android uses `exactAllowWhileIdle` with `USE_EXACT_ALARM`. Telos is a timer,
  so the alert has to land on the second the run ends — an inexact alarm can
  drift by minutes. Boot receivers are declared so a run survives a reboot.
- iOS uses `timeSensitive` interruption level, so it can break through Focus
  modes — which the user is plausibly in, given what this app is for
- Scheduling uses `TZDateTime.from(at, tz.UTC)`. For a one-shot timer only the
  absolute instant matters, and that conversion is exact, which avoids a
  device-timezone plugin

The `Alerts` interface has a `NoopAlerts` implementation, so tests and the
desktop/web preview targets never touch a platform channel.

---

## Timing correctness

The session is stored as `startedAt + plannedMinutes` and every read derives
from wall clock. Killing the app, locking the phone, or rebooting mid-session
does not affect the result — which matters a great deal for an app whose entire
premise is that you put the phone down.

Loot is resolved **once**, seeded from the run id, so it's deterministic. You
cannot reroll a debrief by force-quitting.

---

## Project layout

```
lib/
  main.dart                      app entry + root router (debrief > session > home)
  theme/telos_theme.dart         palette, type scale, ThemeData
  models/
    models.dart                  Bonus, ClassDef, Gear, Adventurer, Sector,
                                 ActiveRun (integrity), RunRecord, Facility
    guild_state.dart             the entire save file + progression curves
  data/content.dart              ALL game content as plain data
  services/
    expedition_engine.dart       resolves a finished run into loot
    persistence.dart             JSON blob in SharedPreferences
    alerts.dart                  the one local notification (+ a no-op impl)
  state/guild_controller.dart    ChangeNotifier; owns save, run, lifecycle hooks
  screens/                       home, dispatch, session, debrief, roster,
                                 outpost, log
  widgets/terminal.dart          Panel, Meter, TButton, TChip, KV, scaffold
test/
  engine_test.dart               integrity math, yields, determinism, save
  flow_test.dart                 home -> dispatch -> session -> debrief
  alerts_test.dart               scheduling, cancelling and re-arming
```

Adding a sector, class or item is an edit to `data/content.dart` — no code
changes, no art. That's deliberate: the terminal aesthetic means content scales
without an artist.

---

## Visual language

Tactical terminal / OLED command console.

- True black `#0B0C0E`, card `#16181D`, hairline `#2A2E36`
- Amber `#F5A623` primary accent, cyan `#00E5FF` for intel, green/red for status
- Monospace throughout, bracketed actions (`[ DISPATCH SQUAD ]`), 1px borders,
  discrete block meters
- **No bundled font yet** — it falls through a platform monospace stack
  (JetBrains Mono → SF Mono → Menlo → Consolas → monospace). Bundling
  JetBrains Mono is a one-line pubspec change and makes it consistent.

---

## Running it

```bash
flutter run
```

```bash
flutter test
```

---

## Not in V1 (deliberately)

- App blocking / distraction detection (see V2 path above)
- IAP: Guildmaster one-time unlock, sector packs, cosmetic terminal themes.
  The one rule from the design notes stands: money expands and customises the
  game; focus is the only thing that generates progression. No XP boosts, no
  session skips, no purchased currency.
- Crafting, companions, guild-hall cosmetics
- Onboarding / first-run tutorial
