import 'package:flutter/material.dart';

import '../theme/telos_theme.dart';

/// Small equipment engravings; no raster asset or portrait for each item.
class GearMark extends StatelessWidget {
  const GearMark({super.key, required this.id, this.size = 80});
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(size: Size.square(size), painter: _GearPainter(id)),
      );
}

class _GearPainter extends CustomPainter {
  const _GearPainter(this.id);
  final String id;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 80, size.height / 80);
    final pen = Paint()
      ..color = T.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path();
    if (id == 'deep_lamp' || id == 'first_light') {
      path.moveTo(30, 21);
      path.lineTo(30, 12);
      path.cubicTo(30, 0, 50, 0, 50, 12);
      path.lineTo(50, 21);
      path.moveTo(22, 27);
      path.lineTo(30, 21);
      path.lineTo(50, 21);
      path.lineTo(58, 27);
      path.lineTo(53, 34);
      path.lineTo(27, 34);
      path.close();
      path.moveTo(27, 34);
      path.lineTo(22, 67);
      path.lineTo(58, 67);
      path.lineTo(53, 34);
      path.moveTo(22, 67);
      path.lineTo(18, 74);
      path.lineTo(62, 74);
      path.lineTo(58, 67);
      path.moveTo(41, 39);
      path.cubicTo(20, 58, 57, 65, 44, 47);
      path.cubicTo(41, 50, 38, 49, 41, 39);
    } else if (id.contains('optic') ||
        id.contains('lens') ||
        id == 'ore_sense') {
      canvas.drawCircle(const Offset(35, 31), 21, pen);
      canvas.drawCircle(const Offset(35, 31), 15, pen);
      path.moveTo(47, 49);
      path.lineTo(62, 72);
      path.lineTo(69, 67);
      path.lineTo(54, 44);
      path.moveTo(21, 31);
      path.lineTo(49, 31);
      path.moveTo(35, 17);
      path.lineTo(35, 45);
    } else if (id.contains('ledger') || id.contains('charter')) {
      path.addRect(const Rect.fromLTWH(19, 10, 42, 60));
      path.moveTo(25, 10);
      path.lineTo(25, 70);
      for (var y = 24.0; y < 58; y += 9) {
        path.moveTo(33, y);
        path.lineTo(52, y);
      }
    } else if (id.contains('key')) {
      canvas.drawCircle(const Offset(40, 21), 14, pen);
      canvas.drawCircle(const Offset(40, 21), 7, pen);
      path.moveTo(36, 35);
      path.lineTo(36, 71);
      path.lineTo(54, 71);
      path.lineTo(54, 64);
      path.lineTo(45, 64);
      path.lineTo(45, 56);
      path.lineTo(55, 56);
      path.lineTo(55, 49);
      path.lineTo(44, 49);
      path.lineTo(44, 35);
    } else if (id.contains('pick') || id.contains('anchor')) {
      path.moveTo(35, 21);
      path.lineTo(29, 70);
      path.lineTo(38, 72);
      path.lineTo(44, 23);
      path.moveTo(10, 29);
      path.quadraticBezierTo(40, -1, 70, 29);
      path.quadraticBezierTo(42, 15, 10, 29);
    } else if (id == 'scav_cord') {
      for (var i = 0; i < 3; i++) {
        canvas.drawOval(Rect.fromLTWH(22 + i * 5, 12, 22, 49), pen);
      }
      path.moveTo(23, 43);
      path.cubicTo(7, 65, 21, 73, 32, 68);
      path.moveTo(54, 32);
      path.cubicTo(70, 45, 57, 59, 63, 69);
      path.moveTo(28, 65);
      path.lineTo(32, 71);
      path.moveTo(59, 66);
      path.lineTo(66, 65);
    } else if (id == 'slag_brace') {
      path.moveTo(22, 13);
      path.lineTo(58, 13);
      path.lineTo(53, 69);
      path.lineTo(27, 69);
      path.close();
      path.addRect(const Rect.fromLTWH(19, 23, 42, 9));
      path.addRect(const Rect.fromLTWH(22, 48, 36, 9));
      path.addRect(const Rect.fromLTWH(35, 21, 10, 13));
      path.addRect(const Rect.fromLTWH(35, 46, 10, 13));
      path.moveTo(30, 13);
      path.lineTo(32, 69);
    } else if (id.contains('rig')) {
      path.addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(18, 22, 44, 48), const Radius.circular(5)));
      path.moveTo(29, 22);
      path.lineTo(29, 13);
      path.lineTo(51, 13);
      path.lineTo(51, 22);
      path.moveTo(18, 35);
      path.lineTo(62, 35);
      path.moveTo(28, 22);
      path.lineTo(28, 70);
      path.moveTo(52, 22);
      path.lineTo(52, 70);
      path.addRect(const Rect.fromLTWH(34, 43, 12, 10));
    } else {
      path.moveTo(40, 7);
      path.lineTo(61, 28);
      path.lineTo(52, 64);
      path.lineTo(40, 74);
      path.lineTo(23, 55);
      path.lineTo(19, 28);
      path.close();
      path.moveTo(40, 7);
      path.lineTo(31, 35);
      path.lineTo(52, 64);
      path.moveTo(31, 35);
      path.lineTo(61, 28);
    }
    canvas.drawPath(path, pen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GearPainter oldDelegate) => oldDelegate.id != id;
}
