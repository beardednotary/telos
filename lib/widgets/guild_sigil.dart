import 'package:flutter/material.dart';

import '../models/guild_identity.dart';
import '../theme/telos_theme.dart';

class GuildEmblem extends StatelessWidget {
  const GuildEmblem({super.key, required this.sigil, this.size = 32});
  final GuildSigil sigil;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '${sigil.label} sigil',
        image: true,
        child: CustomPaint(size: Size.square(size), painter: _Emblem(sigil)),
      );
}

class _Emblem extends CustomPainter {
  const _Emblem(this.sigil);
  final GuildSigil sigil;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final pen = Paint()
      ..color = T.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    switch (sigil) {
      case GuildSigil.lantern:
        path.moveTo(12, 10);
        path.lineTo(12, 7);
        path.cubicTo(12, 2, 20, 2, 20, 7);
        path.lineTo(20, 10);
        path.moveTo(9, 13);
        path.lineTo(12, 10);
        path.lineTo(20, 10);
        path.lineTo(23, 13);
        path.lineTo(21, 16);
        path.lineTo(11, 16);
        path.close();
        path.moveTo(11, 16);
        path.lineTo(9, 27);
        path.lineTo(23, 27);
        path.lineTo(21, 16);
        path.moveTo(9, 27);
        path.lineTo(7, 30);
        path.lineTo(25, 30);
        path.lineTo(23, 27);
        path.moveTo(16, 18);
        path.lineTo(16, 24);
        path.moveTo(13, 22);
        path.lineTo(19, 22);
      case GuildSigil.compass:
        path.moveTo(16, 3);
        path.lineTo(21, 16);
        path.lineTo(16, 29);
        path.lineTo(11, 16);
        path.close();
        path.moveTo(3, 16);
        path.lineTo(11, 16);
        path.moveTo(21, 16);
        path.lineTo(29, 16);
        path.moveTo(7, 7);
        path.lineTo(10, 10);
        path.moveTo(22, 22);
        path.lineTo(25, 25);
        path.moveTo(25, 7);
        path.lineTo(22, 10);
        path.moveTo(10, 22);
        path.lineTo(7, 25);
      case GuildSigil.branch:
        path.moveTo(10, 29);
        path.quadraticBezierTo(16, 17, 20, 3);
        path.moveTo(13, 23);
        path.cubicTo(4, 21, 5, 13, 13, 17);
        path.moveTo(16, 17);
        path.cubicTo(27, 18, 29, 10, 19, 12);
        path.moveTo(18, 10);
        path.cubicTo(9, 10, 10, 3, 19, 5);
      case GuildSigil.anvil:
        path.moveTo(3, 9);
        path.lineTo(29, 9);
        path.lineTo(25, 15);
        path.lineTo(20, 17);
        path.lineTo(20, 24);
        path.lineTo(24, 28);
        path.lineTo(8, 28);
        path.lineTo(12, 24);
        path.lineTo(12, 18);
        path.lineTo(6, 15);
        path.close();
        path.moveTo(11, 5);
        path.lineTo(23, 5);
        path.lineTo(23, 9);
    }
    canvas.drawPath(path, pen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Emblem oldDelegate) => oldDelegate.sigil != sigil;
}
