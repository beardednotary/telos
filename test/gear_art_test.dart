import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telos/data/content.dart';
import 'package:telos/theme/telos_theme.dart';
import 'package:telos/widgets/gear_art.dart';
import 'package:telos/widgets/gear_mark.dart';

/// The plates land one at a time, so the thing worth testing is the
/// fallback: an item with no drawing shows its engraving rather than a gap.
void main() {
  testWidgets('an item with no plate falls back to its engraving',
      (t) async {
    await t.pumpWidget(MaterialApp(
      theme: T.theme(),
      home: const Scaffold(body: Center(child: GearArt(id: 'ore_sense'))),
    ));
    await t.pumpAndSettle();

    expect(find.byType(GearMark), findsOneWidget,
        reason: 'a missing plate must degrade to the mark, not to nothing');
    expect(t.takeException(), isNull);
  });

  test('every gear item looks for its own file, by id', () {
    for (final entry in kGear.entries) {
      expect(GearArt.assetFor(entry.key),
          'assets/art/gear/${entry.key}.webp');
      expect(entry.value.id, entry.key,
          reason: 'a key that disagrees with its id would look for the '
              'wrong plate');
    }
  });
}
