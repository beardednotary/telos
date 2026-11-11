import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telos/theme/telos_theme.dart';
import 'package:telos/widgets/wide_layout.dart';

/// What the app's content sees of the screen, from inside the builder.
class _Probe extends StatelessWidget {
  const _Probe(this.onBuild);
  final void Function(MediaQueryData) onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(MediaQuery.of(context));
    return const Scaffold(body: SizedBox.expand());
  }
}

void main() {
  Future<MediaQueryData> seen(WidgetTester t, Size size,
      {EdgeInsets padding = EdgeInsets.zero}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    t.view.padding = FakeViewPadding(
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom);
    addTearDown(t.view.reset);
    late MediaQueryData data;
    await t.pumpWidget(MaterialApp(
      theme: T.theme(),
      builder: WideLayout.builder,
      home: _Probe((d) => data = d),
    ));
    return data;
  }

  testWidgets('a phone keeps the whole width', (t) async {
    final d = await seen(t, const Size(390, 844));
    expect(d.size, const Size(390, 844));
    expect(t.getSize(find.byType(Scaffold)), const Size(390, 844));
  });

  testWidgets('an iPad centres a column and reports it as the screen',
      (t) async {
    final d = await seen(t, const Size(1032, 1376));
    expect(d.size, const Size(WideLayout.maxWidth, 1376));
    final box = t.getRect(find.byType(Scaffold));
    expect(box.width, WideLayout.maxWidth);
    expect(box.height, 1376);
    expect(box.center.dx, 1032 / 2);
  });

  testWidgets('a landscape iPad does the same', (t) async {
    final d = await seen(t, const Size(1376, 1032));
    expect(d.size.width, WideLayout.maxWidth);
    expect(t.getRect(find.byType(Scaffold)).center.dx, 1376 / 2);
  });

  testWidgets('side insets the margins already cover are dropped', (t) async {
    // A phone on its side: the notch inset sits inside the margin.
    final d = await seen(t, const Size(932, 430),
        padding: const EdgeInsets.fromLTRB(59, 0, 59, 21));
    expect(d.padding.left, 0);
    expect(d.padding.right, 0);
    expect(d.padding.bottom, 21);
  });

  testWidgets('a narrow Split View pane is left alone', (t) async {
    final d = await seen(t, const Size(507, 1376));
    expect(d.size.width, 507);
  });
}
