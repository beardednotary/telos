@Tags(['economy'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telos/data/content.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/services/expedition_engine.dart';

/// What an hour of protected focus is actually worth.
///
/// The forge costs were set blind. This runs the real engine over
/// representative runs and prints the yield rates, so the prices can be
/// expressed in the only unit that matters here - hours of focus - rather
/// than guessed.
///
///   flutter test --run-skipped test/economy_test.dart
///
/// Skipped by default: it is an instrument, and it prints.

/// One clean run at a sector's nominal length, resolved by the real engine.
({int credits, int alloy, int intel, double hours}) runOnce(
  GuildState g,
  Sector s,
  List<String> squad,
) {
  final minutes = s.nominalMinutes;
  final start = DateTime(2026, 1, 1, 9);
  final run = ActiveRun(
    id: 'sim-${s.id}-${squad.join()}',
    sectorId: s.id,
    intent: '',
    squad: squad,
    startedAt: start,
    plannedMinutes: minutes,
  );
  final res = ExpeditionEngine.resolve(
    run: run,
    guild: g,
    now: start.add(Duration(minutes: minutes)),
    recalled: false,
  );
  return (
    credits: res.record.credits,
    alloy: res.record.alloy,
    intel: res.record.intel,
    hours: minutes / 60.0,
  );
}

void main() {
  test('yield rates per hour of clean focus', () {
    // A player at the point each sector opens, roughly: one member out, no
    // gear, outpost untouched. The floor, not the ceiling.
    final g = GuildState.fresh();

    // ignore: avoid_print
    print('\nPER HOUR OF CLEAN FOCUS, baseline squad of one');
    // ignore: avoid_print
    print('SECTOR              MIN      CR/h     AL/h     IN/h');

    final rates = <String, ({double cr, double al, double intel})>{};
    for (final s in kSectors) {
      final r = runOnce(g, s, ['a1']);
      final rate = (
        cr: r.credits / r.hours,
        al: r.alloy / r.hours,
        intel: r.intel / r.hours,
      );
      rates[s.id] = rate;
      // ignore: avoid_print
      print('${s.name.padRight(20)}${s.nominalMinutes.toString().padLeft(3)}'
          '${rate.cr.round().toString().padLeft(10)}'
          '${rate.al.round().toString().padLeft(9)}'
          '${rate.intel.round().toString().padLeft(9)}');
    }

    // The two sectors a player forging seriously would actually be running.
    final cinder = rates['cinder']!;
    final rift = rates['riftline']!;

    // ignore: avoid_print
    print('\nFORGE COST IN HOURS OF FOCUS');
    // ignore: avoid_print
    print('RARITY        CR        AL        IN    -> hours at CINDER / RIFT');
    for (final r in Rarity.values) {
      final c = kCraftCost[r]!;
      double hours(({double cr, double al, double intel}) rate) {
        // The binding constraint is whichever resource takes longest.
        final h = [
          c.credits / rate.cr,
          c.alloy / rate.al,
          c.intel / rate.intel,
        ];
        return h.reduce((a, b) => a > b ? a : b);
      }

      // ignore: avoid_print
      print('${r.label.padRight(12)}${c.credits.toString().padLeft(6)}'
          '${c.alloy.toString().padLeft(10)}${c.intel.toString().padLeft(10)}'
          '    -> ${hours(cinder).toStringAsFixed(1)}h / '
          '${hours(rift).toStringAsFixed(1)}h');
    }

    // ignore: avoid_print
    print('\nSECTOR UNLOCKS IN HOURS (intel only)');
    for (final s in kSectors.where((s) => s.intelToUnlock > 0)) {
      // You farm intel wherever you can reach, so use the best open to you.
      final best = s.id == 'blackstone'
          ? rates['mosswood']!.intel
          : s.id == 'cinder'
              ? rates['blackstone']!.intel
              : rates['cinder']!.intel;
      // ignore: avoid_print
      print('${s.name.padRight(20)}${s.intelToUnlock.toString().padLeft(6)} IN'
          '  -> ${(s.intelToUnlock / best).toStringAsFixed(1)}h');
    }

    // Guard rails rather than exact values: deeper sectors should pay better
    // per hour, or there is no reason to go.
    expect(rates['riftline']!.cr, greaterThan(rates['mosswood']!.cr));
    expect(rates['cinder']!.intel, greaterThan(rates['blackstone']!.intel));

    // The curve must not run backwards. Riftline once cost fewer hours than
    // Cinder, because Cinder produces intel six times faster than Blackstone
    // does, so the fourth sector was cheaper than the third.
    double unlockHours(Sector s, double intelRate) =>
        s.intelToUnlock / intelRate;
    final gates = [
      unlockHours(sectorById('blackstone'), rates['mosswood']!.intel),
      unlockHours(sectorById('cinder'), rates['blackstone']!.intel),
      unlockHours(sectorById('riftline'), rates['cinder']!.intel),
      unlockHours(sectorById('spire'), rates['cinder']!.intel),
    ];
    for (var i = 1; i < gates.length; i++) {
      expect(gates[i], greaterThan(gates[i - 1]),
          reason: 'sector gate ${i + 2} must cost more focus than the one '
              'before it');
    }

    // Each forge tier should be a real step, not a rounding difference.
    var previous = 0.0;
    for (final r in Rarity.values) {
      final c = kCraftCost[r]!;
      final h = c.intel / rates['cinder']!.intel;
      expect(h, greaterThan(previous * 1.5),
          reason: '${r.label} should cost meaningfully more than the tier '
              'below it');
      previous = h;
    }

    // Melting must never be a way to print alloy.
    for (final r in Rarity.values) {
      expect(kMeltValue[r]!, lessThan(kCraftCost[r]!.alloy),
          reason: '${r.label} melt value must be below its forge cost');
    }
  });
}
