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
2. **Session** — a quiet countdown, your intention, and a small Integrity
   readout. No live rewards, animated scenery, or guild management.
3. **Debrief** — earnings are banked once when the run resolves. A find, story
   discovery, or ordinary haul leads; the full report expands on tap. One
   notification fires when the run ends; that is the only thing the app will
   ever interrupt you for.
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
| The Cinder Archive | 40m | Intel |
| Riftline Descent | 60m | Everything, richly |
| The Spire of Telos | 90m | Endgame |

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
changes, no additional art. Sector geometry and equipment marks remain coded;
the single camp illustration establishes a mood without adding an artwork
requirement to every content entry.

---

## Visual language

Night Watch is the launch design: charcoal, brass, practical field equipment,
and clear boundaries around optional detail.

- Ground `#1E252B`, panel `#272F35`, boundary `#677A83`, text `#E6EAEB`.
- Brass `#D3B779` identifies the main action. Secondary controls use neutral
  outlines; color is not the only way to read a state.
- **IBM Plex Sans Condensed SemiBold** for names and headings, **IBM Plex Sans**
  for prose and controls, and **JetBrains Mono** for quantities and time.
  All fonts and their SIL Open Font Licenses ship in the bundle and appear in
  Flutter's in-app license registry.
- Camp shows guild identity, the approved ink illustration, one selected
  facility project, and two bounded disclosures: squad/equipment and
  stores/facilities. Only one disclosure opens at a time. Dispatch and the
  most recent repeat remain in a footer while the content scrolls.
- The illustration establishes the guild's world; it is not a portrait of
  the selected squad. Roster counts and summaries come from the save.
- Guild names retain the player's casing. A name and one of four cosmetic
  sigils can be changed at camp, saved locally, and carried through backups.
  Existing names are preserved; old saves receive the lantern sigil.
  Renaming does not rewrite a previously signed Spire Charter.

Camp, dispatch, focus, and return now use the native Night Watch flow.
Preparation has three mutually exclusive disclosures: your focus, their
destination, and the squad. A fresh plan starts at 25 minutes; later plans
reuse the most recent duration, destination, and squad, with a fresh optional
intention. Presets and custom 5–180-minute durations remain available.

The forecast shares resource formulas with the resolver. It shows the expected
full-session haul at 100% Integrity, with gear attempts and per-attempt odds
available as planning information. Those odds are for any gear; rarity is
rolled separately, and actual loot is never revealed during preparation.
Shorter durations keep the selected destination when reachable, or explicitly
name the replacement when it is not. Locked and duration-gated sectors explain
their requirements inside the destination step without a longer-session nudge.

Roster, equipment, forge, and facilities now use bounded Night Watch sections.
Only one member, recipe tier, or management section opens at a time. Equipment
reviews compare the selected slot's bonuses before committing a swap; the
replaced piece returns to the vault. Crafting, melting, upgrades, recruiting,
and sector access have separate reviews showing the actual costs and gates.
Resource purchases show what remains afterward, and assigned gear cannot be
melted. Camp-project selection still spends nothing.

The field log opens read-only expedition records with saved reflections, journal,
haul, and squad XP. Opening a record never banks it again. Historical levels are
not inferred from the current roster; equipment removed from the vault is shown
as a count because older records retain only its ID. Log totals describe the
retained history, up to 500 expeditions.

The first-run field manual has four short pages with optional rule explanations.
Reviewing it from settings adds repeat-dispatch help. Settings groups guild
identity, save/restore, and help. Backup review compares the current guild with
the actual decoded save before replacement; unreadable or unsupported files
cannot be restored. Exported copies in the app's folder still need to be kept
outside Telos to survive deleting the app.

Contracts show one order's rewards at a time and guard repeated claim taps.
The Spire gives the recorded contribution first, with the original charter behind
a disclosure. Share cards use Night Watch type and coded sector art, preview
before opening the native share sheet, and exclude task and reflection text.
The complete Flutter screen migration is implemented; physical iPhone lifecycle,
notification, backup, and sharing checks remain in the
[device validation pass](docs/design/device-validation.md).
The native widget and Live Activity now share the Night Watch palette and Plex
fonts, and iOS starts on a charcoal background. Source wiring is checked locally;
the signed iOS build and device appearance still need Codemagic/iPhone validation.

Expedition balance and Integrity formulas are unchanged. Simultaneous start/finish
requests share one operation, and a new focus session or debrief closes
management routes left open above camp, including when started by a Shortcut.

### Pacing

Three deliberate bits of feel, all of them load-bearing rather than decorative:

- **The debrief has three finite beats**: the return, the focal result, and
  the next project/report. The reveal lasts 900ms, skips on touch, and respects
  reduced motion. The highest-rarity recovered item leads when there is gear;
  otherwise a prior record or the actual haul does. The Spire Charter takes
  precedence on arrival. All journal entries, salvage, XP and unlocks remain
  in the expandable report. Reflection and sharing are optional.
- **Camp shows one chosen facility project** with its actual costs and
  resource progress. The player can choose Forge, Archive, or Barracks without
  spending anything. These projects can be funded by repeated short sessions;
  the camp does not make a duration-gated sector the compulsory next target.
  Upgrades still use the existing costs and facility rules.
- **Dispatch makes the current plan legible**: the chosen duration,
  destination, and squad stay visible when their details are closed. The
  resource forecast changes with the plan; focus duration remains the
  player's constraint.

The session screen has no motion at all, on purpose.

---

## Running it

```bash
flutter run
```

```bash
flutter test
```

The existing Codemagic workflow builds iOS and auto-increments the TestFlight
build number. Keep its current numbering and signing setup. The optional
pre-build gate is `python3 tool/preflight.py`; it runs source checks, analysis,
and behavior/economy tests without uploading anything. See the
[Codemagic handoff](docs/design/codemagic-handoff.md) for the candidate contents,
build settings, and [tester notes](docs/design/testflight-notes.txt).

---

## Not in V1 (deliberately)

- App blocking / distraction detection (see V2 path above)
- IAP: sector packs and cosmetic terminal themes, after retention is proven.
  The one rule from the design notes stands: money expands and customises the
  game; focus is the only thing that generates progression. No XP boosts, no
  session skips, no purchased currency. No pack sector goes deeper than the
  Spire's 90 minutes.
- Companions and guild-hall cosmetics
