import 'package:flutter/material.dart';

class GoogleIcon extends StatelessWidget {
  final double size;

  const GoogleIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Google Brand Colors
    final Paint blue = Paint()..color = const Color(0xFF4285F4);
    final Paint green = Paint()..color = const Color(0xFF34A853);
    final Paint yellow = Paint()..color = const Color(0xFFFBBC05);
    final Paint red = Paint()..color = const Color(0xFFEA4335);

    final Path bluePath = Path()
      ..moveTo(w * 0.96, h * 0.51)
      ..cubicTo(w * 0.96, h * 0.47, w * 0.95, h * 0.44, w * 0.94, h * 0.41)
      ..lineTo(w * 0.5, h * 0.41)
      ..lineTo(w * 0.5, h * 0.60)
      ..lineTo(w * 0.76, h * 0.60)
      ..cubicTo(w * 0.74, h * 0.69, w * 0.68, h * 0.77, w * 0.59, h * 0.82)
      ..lineTo(w * 0.74, h * 0.94)
      ..cubicTo(w * 0.87, h * 0.82, w * 0.96, h * 0.68, w * 0.96, h * 0.51)
      ..close();
    canvas.drawPath(bluePath, blue);

    final Path greenPath = Path()
      ..moveTo(w * 0.5, h * 0.98)
      ..cubicTo(w * 0.63, h * 0.98, w * 0.74, h * 0.94, w * 0.82, h * 0.86)
      ..lineTo(w * 0.67, h * 0.74)
      ..cubicTo(w * 0.62, h * 0.78, w * 0.56, h * 0.80, w * 0.5, h * 0.80)
      ..cubicTo(w * 0.38, h * 0.80, w * 0.28, h * 0.72, w * 0.24, h * 0.61)
      ..lineTo(w * 0.08, h * 0.73)
      ..cubicTo(w * 0.16, h * 0.88, w * 0.32, h * 0.98, w * 0.5, h * 0.98)
      ..close();
    canvas.drawPath(greenPath, green);

    final Path yellowPath = Path()
      ..moveTo(w * 0.24, h * 0.61)
      ..cubicTo(w * 0.23, h * 0.57, w * 0.22, h * 0.54, w * 0.22, h * 0.5)
      ..cubicTo(w * 0.22, h * 0.46, w * 0.23, h * 0.43, w * 0.24, h * 0.39)
      ..lineTo(w * 0.08, h * 0.27)
      ..cubicTo(w * 0.03, h * 0.34, 0, h * 0.42, 0, h * 0.5)
      ..cubicTo(0, h * 0.58, w * 0.03, h * 0.66, w * 0.08, h * 0.73)
      ..lineTo(w * 0.24, h * 0.61)
      ..close();
    canvas.drawPath(yellowPath, yellow);

    final Path redPath = Path()
      ..moveTo(w * 0.5, h * 0.20)
      ..cubicTo(w * 0.57, h * 0.20, w * 0.63, h * 0.23, w * 0.68, h * 0.27)
      ..lineTo(w * 0.83, h * 0.12)
      ..cubicTo(w * 0.74, h * 0.04, w * 0.63, 0, w * 0.5, 0)
      ..cubicTo(w * 0.32, 0, w * 0.16, h * 0.10, w * 0.08, h * 0.27)
      ..lineTo(w * 0.24, h * 0.39)
      ..cubicTo(w * 0.28, h * 0.28, w * 0.38, h * 0.20, w * 0.5, h * 0.20)
      ..close();
    canvas.drawPath(redPath, red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
