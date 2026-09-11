import 'package:flutter/material.dart';
import 'package:staffpro/core/theme/app_colors.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 72, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _LogoPainter()),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 8),
          Text(
            'StaffPro',
            style: TextStyle(
              fontSize: size * 0.28,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Manage People. Grow Business.',
            style: TextStyle(
              fontSize: size * 0.13,
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    void person(double cx, double headR, double bodyW, double bodyH) {
      canvas.drawCircle(Offset(cx, h * 0.32), headR, paint);
      final body = Path()
        ..moveTo(cx - bodyW / 2, h * 0.44)
        ..quadraticBezierTo(cx, h * 0.40, cx + bodyW / 2, h * 0.44)
        ..lineTo(cx + bodyW / 2.4, h * 0.44 + bodyH)
        ..quadraticBezierTo(cx, h * 0.44 + bodyH + 4, cx - bodyW / 2.4, h * 0.44 + bodyH)
        ..close();
      canvas.drawPath(body, paint);
    }

    person(w * 0.28, w * 0.07, w * 0.22, h * 0.22);
    person(w * 0.50, w * 0.09, w * 0.28, h * 0.28);
    person(w * 0.72, w * 0.07, w * 0.22, h * 0.22);

    final arc = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w / 2, h * 0.92), width: w * 0.72, height: h * 0.28),
      3.5,
      2.4,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DecorativeBackground extends StatelessWidget {
  const DecorativeBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -80,
          left: -60,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.wash.withValues(alpha: 0.9),
            ),
          ),
        ),
        Positioned(
          bottom: -90,
          right: -70,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.wash.withValues(alpha: 0.8),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
