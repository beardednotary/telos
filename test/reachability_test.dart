import 'package:flutter_test/flutter_test.dart';
import 'package:telos/data/content.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/services/expedition_engine.dart';

/// Can a real person actually reach the end of this game?
///
/// The sector gates were priced against the game's own maths, never against
/// a work pattern anybody keeps. This runs the real engine over plausible
/// days and reports where each persona tops out.
///
/// Deliberately generous: every run is 100% integrity, the whole roster goes
/// out every time, and INTEL is spent only on unlocking sectors. A real
/// player would also buy facilities and gear, so these days are an upper
/// bound - the honest version is faster, never slower.
class Sim {
  final String label;
  final int runsPerDay;
  final int minutesPerRun;
  Sim(this.label, this.runsPerDay, this.minutesPerRun);
}

void main() {
  test('how far each work pattern gets', () {
    final sims = [
      Sim('4 x 25min  pomodoro', 4, 25),
      Sim('2 x 60min  study/coding', 2, 60),
      Sim('1 x 90min  deep work', 1, 90),
      Sim('1 x 120min deep + long', 1, 120),
      Sim('2 x 90min  heavy', 2, 90),
    ];

    for (final sim in sims) {
      final g = GuildState.fresh();
      final unlocked = <String, int>{};
      var minutes = 0;
      var day = 0;
      int? day150;

      for (day = 1; day <= 730; day++) {
        for (var r = 0; r < sim.runsPerDay; r++) {
          // Deepest sector this run length can actually reach.
          final open = kSectors
              .where((s) =>
                  g.sectorUnlocked(s.id) && s.minMinutes <= sim.minutesPerRun)
              .toList();
          if (open.isEmpty) continue;
          final sector = open.last;

          final start = DateTime(2026, 1, 1).add(Duration(days: day));
          final run = ActiveRun(
            id: 'd${day}r$r',
            sectorId: sector.id,
            intent: 'sim',
            squad: g.roster.map((a) => a.id).toList(),
            startedAt: start,
            plannedMinutes: sim.minutesPerRun,
            watchSeconds: 0,
            checkIns: 0,
          );
          final res = ExpeditionEngine.resolve(
            run: run,
            guild: g,
            now: start.add(Duration(minutes: sim.minutesPerRun)),
            recalled: false,
          );

          g.credits += res.record.credits;
          g.alloy += res.record.alloy;
          g.intel += res.record.intel;
          for (final e in res.record.xpGained.entries) {
            final m = g.memberById(e.key);
            if (m == null) continue;
            m.xp += e.value;
            while (m.xp >= Adventurer.xpForLevel(m.level)) {
              m.xp -= Adventurer.xpForLevel(m.level);
              m.level++;
            }
          }
          g.xp += res.record.guildXp;
          while (g.xp >= GuildState.xpForGuildLevel(g.level)) {
            g.xp -= GuildState.xpForGuildLevel(g.level);
            g.level++;
          }
          minutes += sim.minutesPerRun;
          if (day150 == null && minutes >= 150 * 60) day150 = day;
        }

        // Unlock whatever is affordable, cheapest first.
        for (final s in kSectors) {
          if (g.sectorUnlocked(s.id)) continue;
          if (g.level >= s.guildLevelToUnlock && g.intel >= s.intelToUnlock) {
            g.intel -= s.intelToUnlock;
            g.unlockedSectors.add(s.id);
            unlocked[s.id] = day;
          }
        }
      }

      // The economy must never be the thing standing in the way: if a
      // pattern can clear a sector's minutes at all, INTEL and guild level
      // should follow inside 90 days (worst case today is 33). Session length is allowed to gate
      // content. Grinding is not.
      for (final s in kSectors) {
        if (s.id == 'mosswood') continue;
        if (s.minMinutes > sim.minutesPerRun) continue;
        expect(unlocked[s.id], isNotNull,
            reason: '${sim.label} can reach ${s.id} but never unlocked it');
        expect(unlocked[s.id]!, lessThan(90),
            reason: '${sim.label} took ${unlocked[s.id]} days to open ${s.id}');
      }

      // ignore: avoid_print
      print('\n${sim.label}   (${sim.runsPerDay * sim.minutesPerRun} min/day, '
          'lv ${g.level} after 2 years, 150h on day ${day150 ?? "never"})');
      for (final s in kSectors) {
        final when = unlocked[s.id];
        final reachable = s.minMinutes <= sim.minutesPerRun;
        final status = s.id == 'mosswood'
            ? 'open from day 1'
            : when == null
                ? 'never unlocked in 2 years'
                : reachable
                    ? 'day $when'
                    // Bought and visible, but no session is long enough to
                    // dispatch there. The player can see it and what it
                    // costs them in minutes, which is the honest nudge.
                    : 'day $when, but locked out - needs ${s.minMinutes}min';
        // ignore: avoid_print
        print('   ${s.designation}  ${s.name.padRight(20)} $status');
      }
    }
  });
}
