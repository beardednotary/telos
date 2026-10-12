import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telos/data/content.dart';
import 'package:telos/theme/telos_theme.dart';
import 'package:telos/models/models.dart';
import 'package:telos/widgets/gear_art.dart';
import 'package:telos/widgets/gear_mark.dart';
import 'package:telos/widgets/management_widgets.dart';

/// Missing art still falls back even after the current epics have plates.
class _MissingPlateBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == GearArt.assetFor('ore_sense')) {
      throw FlutterError('Missing plate for this test');
    }
    return rootBundle.load(key);
  }
}

void main() {
  testWidgets('an item with no plate falls back to its engraving',
      (t) async {
    await t.pumpWidget(MaterialApp(
      theme: T.theme(),
      home: Scaffold(
        body: DefaultAssetBundle(
          bundle: _MissingPlateBundle(),
          child: const Center(child: GearArt(id: 'ore_sense')),
        ),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.byType(GearMark), findsOneWidget,
        reason: 'a missing plate must degrade to the mark, not to nothing');
    expect(t.takeException(), isNull);
  });

  testWidgets('epic lists and comparisons keep their engravings', (t) async {
    for (final def in kGear.values.where((def) => def.rarity == Rarity.epic)) {
      await t.pumpWidget(MaterialApp(
        theme: T.theme(),
        home: Scaffold(
          body: Column(children: [
            GearEntry(def: def, onTap: () {}),
            GearDetail(def: def),
          ]),
        ),
      ));
      await t.pumpAndSettle();
      expect(find.byType(GearArt), findsNothing,
          reason: '${def.id} belongs only in the salvage reveal');
      expect(find.byType(GearMark), findsNWidgets(2));
      expect(t.takeException(), isNull);
    }
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
