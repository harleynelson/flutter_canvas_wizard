// File: lib/utils/vws_painter_utils.dart
// Description: Math for generating an envelope path around a line with variable thickness.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/geometry/stroke_point.dart';

class VWSPainterUtils {
  /// Generates a closed path that wraps a line with variable thickness.
  static Path generateVariablePath(List<StrokePoint> points) {
    if (points.length < 2) return Path();
    
    final path = Path();
    final List<Offset> leftSide = [];
    final List<Offset> rightSide = [];

    for (int i = 0; i < points.length; i++) {
      final p = points[i].point;
      final double w = points[i].effectiveWidth / 2;

      // Calculate direction vector to find the perpendicular "Normal"
      Offset direction;
      if (i < points.length - 1) {
        direction = points[i + 1].point - p;
      } else {
        direction = p - points[i - 1].point;
      }

      // Perpendicular vector (Normal)
      final double length = direction.distance;
      final Offset normal = Offset(-direction.dy / length, direction.dx / length);

      leftSide.add(p + (normal * w));
      rightSide.insert(0, p - (normal * w)); // Insert at 0 to create a loop
    }

    // Combine left and right sides into one continuous closed loop
    path.moveTo(leftSide[0].dx, leftSide[0].dy);
    for (var p in leftSide) path.lineTo(p.dx, p.dy);
    for (var p in rightSide) path.lineTo(p.dx, p.dy);
    path.close();

    return path;
  }
}