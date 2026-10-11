import 'models.dart';

/// Deterministic quantities and gear opportunities, never the rolled loot.
class ExpeditionForecast {
  const ExpeditionForecast({
    required this.credits,
    required this.alloy,
    required this.intel,
    required this.bonus,
    required this.depth,
    required this.scraps,
    required this.gearAttempts,
    required this.gearChance,
  });
  final int credits;
  final int alloy;
  final int intel;
  final Bonus bonus;
  final double depth;
  final bool scraps;
  final int gearAttempts;
  final double gearChance;
}
