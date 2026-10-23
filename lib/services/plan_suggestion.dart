import 'dart:math';

import '../data/content.dart';
import '../models/expedition_forecast.dart';
import '../models/guild_state.dart';
import '../models/models.dart';
import 'expedition_engine.dart';

/// "I have 30 minutes. Where should I go?"
///
/// Tries every sector the player can reach in that time against every squad
/// they could send, using the same forecast the dispatch screen shows, and
/// picks the plan that moves the camp project furthest. So the suggestion
/// is never a guess and never better than what the screen then promises.
class PlanSuggestion {
  final Sector sector;
  final List<Adventurer> squad;
  final ExpeditionForecast forecast;

  /// One sentence on why, in the player's terms.
  final String reason;

  const PlanSuggestion({
    required this.sector,
    required this.squad,
    required this.forecast,
    required this.reason,
  });
}

PlanSuggestion? suggestPlan(GuildState g, int minutes) {
  final sectors = kSectors
      .where((s) => g.sectorUnlocked(s.id) && s.minMinutes <= minutes)
      .toList();
  if (sectors.isEmpty || g.roster.isEmpty) return null;

  final project = g.campProject;
  final (costC, costA) = project.costAt(g.facilities[project]!);

  // How far the project is after a run, the same measure camp shows: the
  // scarcer of the two supplies. Below 1 this is what the player is short
  // of; at 1 the project is affordable and only the overall haul matters.
  double progressAfter(ExpeditionForecast f) =>
      min((g.credits + f.credits) / costC, (g.alloy + f.alloy) / costA)
          .clamp(0.0, 1.0);

  // The haul in one number, for ties and for an affordable project. Alloy
  // and intel are scarcer than credits, and a gear attempt is worth a
  // little on top.
  double haul(ExpeditionForecast f) =>
      f.credits +
      f.alloy * 4.0 +
      f.intel * 6.0 +
      f.gearAttempts * f.gearChance * 200;

  PlanSuggestion? best;
  var bestKey = (-1.0, -1.0);
  for (final sector in sectors) {
    for (final squad in _squads(g.roster, g.squadSlots)) {
      final f = ExpeditionEngine.forecast(
        guild: g,
        sector: sector,
        members: squad,
        minutes: minutes.toDouble(),
      );
      final key = (progressAfter(f), haul(f));
      if (key.$1 > bestKey.$1 ||
          (key.$1 == bestKey.$1 && key.$2 > bestKey.$2)) {
        bestKey = key;
        best = PlanSuggestion(
            sector: sector, squad: squad, forecast: f, reason: '');
      }
    }
  }
  if (best == null) return null;

  final name = _title(project.label);
  final before = min(g.credits / costC, g.alloy / costA).clamp(0.0, 1.0);
  final reason = before >= 1
      ? 'You can already afford the $name upgrade, so this is simply the '
          'richest haul you can reach in $minutes minutes.'
      : bestKey.$1 >= 1
          ? 'This run should be enough to pay for the $name upgrade.'
          : 'This gets your $name upgrade furthest: about '
              '${(bestKey.$1 * 100).round()}% of the way after this run.';
  return PlanSuggestion(
    sector: best.sector,
    squad: best.squad,
    forecast: best.forecast,
    reason: reason,
  );
}

String _title(String label) =>
    '${label[0]}${label.substring(1).toLowerCase()}';

/// Every squad of one member up to [slots]. A roster is a handful of
/// people, so this stays small: five members and three slots is 25 squads.
Iterable<List<Adventurer>> _squads(List<Adventurer> roster, int slots) sync* {
  final size = min(slots, roster.length);
  Iterable<List<Adventurer>> pick(int from, int left) sync* {
    if (left == 0) {
      yield const [];
      return;
    }
    for (var i = from; i <= roster.length - left; i++) {
      for (final rest in pick(i + 1, left - 1)) {
        yield [roster[i], ...rest];
      }
    }
  }

  for (var k = 1; k <= size; k++) {
    yield* pick(0, k);
  }
}
