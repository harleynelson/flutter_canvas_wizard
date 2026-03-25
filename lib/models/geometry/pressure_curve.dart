// File: lib/models/geometry/pressure_curve.dart
// Description: Applies a mathematical curve to the thickness of a path.

import 'package:flutter/material.dart';
import 'stroke_point.dart';

class PressureCurve {
  final Curve curve;
  final double baseWidth;

  PressureCurve({this.curve = Curves.easeInOut, this.baseWidth = 5.0});

  List<StrokePoint> applyToPoints(List<Offset> rawPoints) {
    return List.generate(rawPoints.length, (i) {
      // Calculate t (0.0 at start, 1.0 at end)
      double t = i / (rawPoints.length - 1);
      // Use the curve to determine pressure (e.g., thin at ends, thick in middle)
      double pressure = 1.0 - (2 * (t - 0.5)).abs(); // Simple diamond taper
      
      return StrokePoint(
        point: rawPoints[i],
        width: baseWidth,
        pressure: curve.transform(pressure),
      );
    });
  }
}