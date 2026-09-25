import '../data/content.dart';
import '../models/guild_state.dart';
import '../models/models.dart';

/// A dispatch that can be sent again without the dispatch screen.
///
/// Most people send the same squad to the same place for the same length
/// every time, so the fastest dispatch is a repeat of an earlier one. The
/// home screen offers the last few; the widget and the Shortcuts action will
/// offer the same list, so it lives here rather than in any one screen.
class Redeploy {
  const Redeploy({
    required this.sectorId,
    required this.squad,
    required this.minutes,
    required this.intent,
  });

  final String sectorId;
  final List<String> squad;
  final int minutes;
  final String intent;

  /// Identity for de-duplicating: the same place, people and length is the
  /// same dispatch whatever it was for.
  String get key => '$sectorId|${([...squad]..sort()).join(',')}|$minutes';
}

/// Up to [limit] distinct recent dispatches, newest first, each adjusted to
/// fit the guild as it stands now. Anything that cannot be made to fit is
/// dropped rather than offered as something that would fail.
List<Redeploy> recentDispatches(GuildState g, {int limit = 3}) {
  final out = <Redeploy>[];
  final seen = <String>{};
  // The log is newest first.
  for (final r in g.log) {
    final d = _fit(g, r);
    if (d == null || !seen.add(d.key)) continue;
    out.add(d);
    if (out.length == limit) break;
  }
  return out;
}

/// The same dispatch, made to fit the guild as it is now rather than as it
/// was: members who are gone are dropped and the squad is trimmed to the
/// slots; a sector that is locked, removed or deeper than the duration falls
/// back to the deepest one that duration reaches, as dispatch itself does.
Redeploy? _fit(GuildState g, RunRecord r) {
  final minutes = r.plannedMinutes;

  final reachable = kSectors
      .where((s) => g.sectorUnlocked(s.id) && s.minMinutes <= minutes)
      .toList();
  if (reachable.isEmpty) return null;
  final sectorId =
      reachable.any((s) => s.id == r.sectorId) ? r.sectorId : reachable.last.id;

  final present = g.roster.map((a) => a.id).toSet();
  var squad = r.squad.where(present.contains).take(g.squadSlots).toList();
  if (squad.isEmpty) {
    if (g.roster.isEmpty) return null;
    squad = [g.roster.first.id];
  }

  return Redeploy(
    sectorId: sectorId,
    squad: squad,
    minutes: minutes,
    intent: r.intent,
  );
}
