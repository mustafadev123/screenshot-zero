import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum IllustrationKind { orbit, plate, shoe, window, coffee, lamp }

class ScreenshotIllustration extends StatelessWidget {
  const ScreenshotIllustration({super.key, required this.kind});
  final IllustrationKind kind;

  @override
  Widget build(BuildContext context) =>
      SizedBox.expand(child: CustomPaint(painter: _IllustrationPainter(kind)));
}

class _IllustrationPainter extends CustomPainter {
  const _IllustrationPainter(this.kind);
  final IllustrationKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 260, size.height / 200);
    final ink = Paint()..color = AppColors.ink;
    final paper = Paint()..color = AppColors.paper;
    final wash = Paint()..color = AppColors.wash;
    final line = Paint()
      ..color = AppColors.graphite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    switch (kind) {
      case IllustrationKind.orbit:
        canvas.translate(130, 103);
        canvas.rotate(-.35);
        for (var i = 0; i < 13; i++) {
          final p = Paint()
            ..color = Color.lerp(AppColors.signal, AppColors.paper, i / 17)!
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: 210 - i * 10,
              height: 150,
            ),
            p,
          );
        }
        canvas.drawCircle(const Offset(91, -41), 6, paper);
        canvas.drawCircle(
          const Offset(-84, 49),
          3,
          Paint()..color = AppColors.signal,
        );
      case IllustrationKind.plate:
        canvas.drawOval(
          const Rect.fromLTWH(39, 22, 190, 166),
          Paint()..color = AppColors.border,
        );
        canvas.drawCircle(const Offset(130, 98), 77, paper);
        canvas.drawCircle(const Offset(130, 98), 59, line);
        for (var i = 0; i < 7; i++) {
          final angle = i * math.pi / 3.5;
          final point = Offset(
            130 + math.cos(angle) * 28,
            98 + math.sin(angle) * 25,
          );
          canvas.drawOval(
            Rect.fromCenter(center: point, width: 36, height: 20),
            Paint()..color = i.isEven ? AppColors.graphite : AppColors.signal,
          );
        }
        canvas.drawLine(
          const Offset(20, 38),
          const Offset(20, 163),
          line..strokeWidth = 3,
        );
        canvas.drawLine(const Offset(244, 38), const Offset(244, 163), line);
      case IllustrationKind.shoe:
        canvas.drawOval(const Rect.fromLTWH(28, 153, 209, 16), wash);
        final sole = Path()
          ..moveTo(23, 133)
          ..quadraticBezierTo(130, 153, 235, 129)
          ..lineTo(235, 147)
          ..quadraticBezierTo(128, 172, 23, 148)
          ..close();
        canvas.drawPath(sole, paper);
        canvas.drawPath(sole, line);
        final upper = Path()
          ..moveTo(24, 132)
          ..lineTo(38, 77)
          ..quadraticBezierTo(69, 103, 92, 88)
          ..lineTo(117, 55)
          ..quadraticBezierTo(145, 108, 198, 113)
          ..quadraticBezierTo(230, 111, 235, 130)
          ..quadraticBezierTo(126, 154, 24, 132)
          ..close();
        canvas.drawPath(upper, wash);
        canvas.drawPath(upper, line);
        canvas.drawPath(
          Path()
            ..moveTo(70, 117)
            ..lineTo(125, 94)
            ..lineTo(143, 105)
            ..lineTo(90, 135)
            ..close(),
          ink,
        );
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(
            Offset(111 + i * 9, 83 + i * 7),
            Offset(131 + i * 9, 76 + i * 7),
            line..strokeWidth = 2,
          );
        }
      case IllustrationKind.window:
        canvas.drawRect(const Rect.fromLTWH(0, 0, 260, 200), wash);
        canvas.drawRect(const Rect.fromLTWH(53, 14, 126, 162), ink);
        canvas.drawRect(const Rect.fromLTWH(63, 23, 106, 142), paper);
        canvas.drawPath(
          Path()
            ..moveTo(125, 23)
            ..lineTo(169, 23)
            ..lineTo(169, 165)
            ..lineTo(83, 165)
            ..close(),
          Paint()..color = AppColors.border,
        );
        canvas.drawRect(const Rect.fromLTWH(112, 20, 5, 150), ink);
        canvas.drawRect(const Rect.fromLTWH(60, 89, 112, 5), ink);
        canvas.drawPath(
          Path()
            ..moveTo(179, 176)
            ..lineTo(235, 200)
            ..lineTo(84, 200)
            ..lineTo(53, 176)
            ..close(),
          Paint()..color = AppColors.surface,
        );
      case IllustrationKind.coffee:
        canvas.drawOval(const Rect.fromLTWH(75, 155, 116, 14), wash);
        canvas.drawPath(
          Path()
            ..moveTo(73, 38)
            ..lineTo(193, 38)
            ..lineTo(151, 115)
            ..lineTo(112, 115)
            ..close(),
          paper,
        );
        canvas.drawPath(
          Path()
            ..moveTo(73, 38)
            ..lineTo(193, 38)
            ..lineTo(151, 115)
            ..lineTo(112, 115)
            ..close(),
          line,
        );
        for (var i = 0; i < 6; i++) {
          canvas.drawLine(
            Offset(84 + i * 18, 42),
            Offset(116 + i * 6, 109),
            line,
          );
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(100, 120, 66, 40),
            const Radius.circular(6),
          ),
          ink,
        );
        canvas.drawCircle(const Offset(171, 137), 12, line..strokeWidth = 3);
        canvas.drawOval(
          const Rect.fromLTWH(76, 30, 114, 16),
          Paint()..color = AppColors.graphite,
        );
      case IllustrationKind.lamp:
        canvas.drawOval(const Rect.fromLTWH(59, 176, 151, 15), wash);
        canvas.drawOval(const Rect.fromLTWH(83, 170, 99, 12), ink);
        canvas.drawLine(
          const Offset(132, 73),
          const Offset(132, 173),
          line..strokeWidth = 7,
        );
        canvas.drawPath(
          Path()
            ..moveTo(63, 82)
            ..quadraticBezierTo(130, -20, 202, 82)
            ..close(),
          Paint()..color = AppColors.border,
        );
        canvas.drawOval(const Rect.fromLTWH(63, 72, 139, 22), ink);
        canvas.drawOval(const Rect.fromLTWH(109, 77, 42, 11), paper);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IllustrationPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
