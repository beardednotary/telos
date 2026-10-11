import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../theme/telos_theme.dart';
import 'camp_controls.dart';
import 'expedition_widgets.dart';
import 'management_widgets.dart';
import 'sector_scene.dart';

/// A 360×450 composition exported at 3×. Task and reflection text never enter
/// this widget. The fixed image typography is independent of UI text scaling.
class RunCard extends StatelessWidget {
  const RunCard({
    super.key,
    required this.record,
    required this.sector,
    required this.guildName,
    required this.depths,
    required this.floors,
    required this.status,
  });

  final RunRecord record;
  final Sector sector;
  final String guildName;
  final List<double> depths;
  final int floors;
  final String status;

  static const size = Size(360, 450);

  @override
  Widget build(BuildContext context) {
    final depth =
        (record.elapsedSeconds / 60 / sector.nominalMinutes).clamp(0.0, 1.6);
    final date = record.endedAt.toLocal();
    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: size,
        child: Material(
          color: T.black,
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: T.boundary)),
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('TELOS',
                    style: T.label.copyWith(color: T.amber, letterSpacing: 3)),
                const Spacer(),
                Text(sector.designation, style: T.micro),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                height: 34,
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(fieldName(sector.name), style: T.display),
                ),
              ),
              SizedBox(
                height: 22,
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(guildName, style: T.body),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: const BoxDecoration(
                    border: Border.symmetric(
                        horizontal: BorderSide(color: T.line))),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SectorScene(
                  sectorId: sector.id,
                  color: T.amber,
                  depths: depths,
                  latest: depth,
                  floors: floors,
                  height: 160,
                  animate: false,
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                _Figure(
                    'Time',
                    record.elapsedSeconds < 60
                        ? '${record.elapsedSeconds}s'
                        : '${record.elapsedMinutes}m'),
                _Figure('Depth', '${(depth * 100).round()}%'),
                _Figure('Integrity', '${(record.integrity * 100).round()}%'),
              ]),
              const Spacer(),
              Row(children: [
                Expanded(child: Text(fieldName(status), style: T.micro)),
                const SizedBox(width: 8),
                Text(
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
                    '${date.day.toString().padLeft(2, '0')}',
                    style: T.micro),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: T.secondary),
          const SizedBox(height: 4),
          Text(value, style: T.mono.copyWith(fontSize: 24)),
        ],
      ));
}

/// Preview first; native sharing happens only after an explicit Share tap.
Future<void> showRunCard(BuildContext context, RunCard card) =>
    showDialog<void>(
      context: context,
      builder: (_) => _SharePreview(card: card),
    );

class _SharePreview extends StatefulWidget {
  const _SharePreview({required this.card});
  final RunCard card;

  @override
  State<_SharePreview> createState() => _SharePreviewState();
}

class _SharePreviewState extends State<_SharePreview> {
  final _capture = GlobalKey();
  String? _error;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: T.black,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: T.boundary),
          borderRadius: BorderRadius.circular(4),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
                child: FittedBox(
              child: RepaintBoundary(key: _capture, child: widget.card),
            )),
            const SizedBox(height: 16),
            Text(
                'Shares your guild and expedition stats. Task notes stay private.',
                style: T.secondary),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: T.secondary),
            ],
            const SizedBox(height: 16),
            Builder(
                builder: (buttonContext) => CampAction(
                      key: const Key('share-expedition'),
                      label: 'Share expedition',
                      onPressed: () async {
                        setState(() => _error = null);
                        final box =
                            buttonContext.findRenderObject() as RenderBox?;
                        try {
                          await _share(
                              _capture,
                              widget.card,
                              box == null
                                  ? null
                                  : box.localToGlobal(Offset.zero) & box.size);
                        } catch (_) {
                          if (mounted) {
                            setState(() => _error =
                                'Could not share the image. Please try again.');
                          }
                        }
                      },
                    )),
            const SizedBox(height: 8),
            CampButton(
                label: 'Close preview',
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
      );
}

Future<void> _share(GlobalKey key, RunCard card, Rect? origin) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) return;
  final dir = await getTemporaryDirectory();
  final file =
      File('${dir.path}/telos-${card.sector.id}-${card.record.id}.png');
  await file.writeAsBytes(bytes.buffer.asUint8List());
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'image/png')],
    sharePositionOrigin: origin,
  ));
}
