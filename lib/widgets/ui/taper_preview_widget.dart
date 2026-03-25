// File: lib/widgets/ui/taper_preview_widget.dart
// Description: A small UI widget to visualize the thickness profile of a path.

import 'package:flutter/material.dart';

class TaperPreviewWidget extends StatelessWidget {
  final List<double> stops; // Pressure values from 0.0 to 1.0

  const TaperPreviewWidget({super.key, required this.stops});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(4),
      ),
      child: CustomPaint(
        painter: _TaperPainter(stops),
      ),
    );
  }
}

class _TaperPainter extends CustomPainter {
  final List<double> stops;
  _TaperPainter(this.stops);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blueAccent..style = PaintingStyle.fill;
    final path = Path();
    
    if (stops.isEmpty) return;

    path.moveTo(0, size.height / 2);
    for (int i = 0; i < stops.length; i++) {
      double x = (i / (stops.length - 1)) * size.width;
      double h = stops[i] * (size.height / 2);
      path.lineTo(x, size.height / 2 - h);
    }
    for (int i = stops.length - 1; i >= 0; i--) {
      double x = (i / (stops.length - 1)) * size.width;
      double h = stops[i] * (size.height / 2);
      path.lineTo(x, size.height / 2 + h);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}