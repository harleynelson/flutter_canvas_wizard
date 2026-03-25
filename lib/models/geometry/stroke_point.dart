// File: lib/models/geometry/stroke_point.dart
// Description: Defines a point on a path with a custom thickness for variable width rendering.

import 'package:flutter/material.dart';

class StrokePoint {
  final Offset point;
  final double width;
  final double pressure; // 0.0 to 1.0, used to calculate final thickness

  StrokePoint({
    required this.point,
    this.width = 4.0,
    this.pressure = 1.0,
  });

  double get effectiveWidth => width * pressure;
}