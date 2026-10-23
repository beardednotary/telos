import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telos/widgets/caravan_header.dart';

class _MissingCaravanBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == CaravanHeader.assetPath) {
      throw FlutterError('Missing caravan illustration for this test');
    }
    return rootBundle.load(key);
  }
}

void main() {
  testWidgets('loads the bundled scene and crops to the available card width',
      (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 345, child: CaravanHeader())),
      ),
    ));
    await t.runAsync(() => precacheImage(
          const AssetImage(CaravanHeader.assetPath),
          t.element(find.byType(CaravanHeader)),
        ));
    await t.pumpAndSettle();

    final raw = t.widget<RawImage>(find.byType(RawImage));
    expect(raw.image, isNotNull,
        reason: 'the bundled WebP must decode, not silently use the fallback');
    expect(raw.image!.width, 1290);
    expect(raw.image!.height, 726);
    expect(raw.fit, BoxFit.cover);
    expect(raw.alignment, Alignment.center);
    expect(t.getSize(find.byType(CaravanHeader)), const Size(345, 150));
    expect(t.takeException(), isNull);
  });

  testWidgets('a missing caravan illustration collapses without a gap',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DefaultAssetBundle(
          bundle: _MissingCaravanBundle(),
          child: const Column(children: [CaravanHeader()]),
        ),
      ),
    ));
    await t.pumpAndSettle();

    expect(t.getSize(find.byType(CaravanHeader)).height, 0);
    expect(t.takeException(), isNull);
  });
}
