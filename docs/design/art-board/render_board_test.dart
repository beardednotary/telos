// Renders the app's code-drawn art at real size for the art board.
//
//   flutter test docs/design/art-board/render_board_test.dart
//   python docs/design/art-board/build.py
//
// Lives outside test/ so the normal suite never writes these files. Output
// is PNG at 3x into docs/design/art-board/renders/; build.py shows each at
// its logical size.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telos/models/guild_identity.dart';
import 'package:telos/theme/telos_theme.dart';
import 'package:telos/widgets/guild_sigil.dart';
import 'package:telos/widgets/sector_scene.dart';
import 'package:telos/widgets/sigil.dart';
import 'package:telos/widgets/spire_drawing.dart';

const _out = 'docs/design/art-board/renders';

/// Phone content width: 390 less the screens' 16px margins.
const _w = 358.0;

const _sectors = ['mosswood', 'blackstone', 'cinder', 'riftline', 'spire'];
const _classes = ['vanguard', 'recon', 'archivist', 'artificer', 'quartermaster'];

/// A spread of earlier runs, and this one: what a few weeks in a sector
/// leaves on the ground.
const _depths = [0.28, 0.41, 0.52, 0.55, 0.63, 0.78, 0.81, 0.97, 1.12];
const _latest = 1.04;

Future<void> _shot(WidgetTester t, String name, Widget child,
    {Color bg = T.card}) async {
  final key = GlobalKey();
  await t.binding.setSurfaceSize(const Size(1200, 1600));
  await t.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: ColoredBox(color: bg, child: child),
      ),
    ),
  ));
  await t.pump();
  await t.runAsync(() async {
    final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await ro.toImage(pixelRatio: 3);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Widget _row(List<Widget> children, {double gap = 16}) => Padding(
      padding: const EdgeInsets.all(12),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final c in children) ...[c, SizedBox(width: gap)],
      ]),
    );

void main() {
  for (final id in _sectors) {
    // The outpost's sector sheet: the place alone, in amber.
    testWidgets('scene $id sheet', (t) async {
      await _shot(
          t,
          'scene-$id-sheet',
          SizedBox(
              width: _w,
              child: SectorScene(
                  sectorId: id, color: T.amber, animate: false, height: 140)));
    });
    // The debrief: dim land, earlier stakes, this run's stake.
    testWidgets('scene $id debrief', (t) async {
      await _shot(
          t,
          'scene-$id-debrief',
          SizedBox(
              width: _w,
              child: SectorScene(
                  sectorId: id,
                  color: T.dim,
                  depths: _depths,
                  latest: _latest,
                  height: 100,
                  animate: false)));
    });
  }

  testWidgets('spire drawing', (t) async {
    await _shot(
        t,
        'spire-drawing',
        const SizedBox(
            width: _w, child: SpireDrawing(historical: 60, mine: 14)));
  });

  testWidgets('sector sigils', (t) async {
    await _shot(
        t,
        'strokes-sectors',
        _row([
          for (final id in _sectors) Sigil(sectorId: id, color: T.amber, size: 24),
          const SizedBox(width: 8),
          for (final id in _sectors) Sigil(sectorId: id, color: T.amber, size: 72),
        ]));
  });

  testWidgets('class emblems', (t) async {
    await _shot(
        t,
        'strokes-classes',
        _row([
          for (final id in _classes)
            ClassEmblem(classId: id, color: T.amber, size: 24),
          const SizedBox(width: 8),
          for (final id in _classes)
            ClassEmblem(classId: id, color: T.amber, size: 72),
        ]));
  });

  testWidgets('guild emblems', (t) async {
    await _shot(
        t,
        'strokes-guild',
        _row([
          for (final s in GuildSigil.values) GuildEmblem(sigil: s, size: 32),
          const SizedBox(width: 8),
          for (final s in GuildSigil.values) GuildEmblem(sigil: s, size: 88),
        ]));
  });

  testWidgets('camp marks', (t) async {
    await _shot(
        t,
        'strokes-camp',
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 9 * 40,
            child: Wrap(spacing: 17, runSpacing: 17, children: [
              for (final m in CampMark.values) CampMarkIcon(m, color: T.text),
            ]),
          ),
        ));
  });
}
