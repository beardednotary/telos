import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telos/data/content.dart';
import 'package:telos/theme/telos_theme.dart';
import 'package:telos/widgets/sector_header.dart';

/// Missing art must still collapse, even now that every current sector ships
/// with a header. Simulate the missing asset rather than relying on Mosswood
/// being absent from the bundle.
class _MissingHeaderBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == SectorHeader.assetFor('mosswood')) {
      throw FlutterError('Missing header for this test');
    }
    return rootBundle.load(key);
  }
}

void main() {
  testWidgets('a sector with no illustration yet takes up no room',
      (t) async {
    final sector = sectorById('mosswood');

    await t.pumpWidget(MaterialApp(
      theme: T.theme(),
      home: Scaffold(
        body: DefaultAssetBundle(
          bundle: _MissingHeaderBundle(),
          child: Column(children: [SectorHeader(sector: sector)]),
        ),
      ),
    ));
    await t.pumpAndSettle();

    expect(t.getSize(find.byType(SectorHeader)), Size.zero,
        reason: 'a missing header must collapse, not reserve its height');
    expect(t.takeException(), isNull);
  });

  test('every sector looks for its own file, by id', () {
    for (final s in kSectors) {
      expect(SectorHeader.assetFor(s.id), 'assets/art/sectors/${s.id}.webp');
    }
    // Ids are unique, so no two sectors can collide on one illustration.
    expect(kSectors.map((s) => s.id).toSet().length, kSectors.length);
  });
}
