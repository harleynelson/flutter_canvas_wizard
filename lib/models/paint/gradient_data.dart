// File: lib/models/paint/gradient_data.dart
// Description: Data model for linear and radial gradients.

import 'package:flutter/material.dart';

class GradientData {
  final List<Color> colors;
  final List<double> stops;
  final Offset begin;
  final Offset end;
  final TileMode tileMode;

  GradientData({
    required this.colors,
    required this.stops,
    this.begin = const Offset(-1.0, 0.0),
    this.end = const Offset(1.0, 0.0),
    this.tileMode = TileMode.clamp,
  });

  Shader toShader(Rect bounds) {
    return LinearGradient(
      begin: Alignment(begin.dx, begin.dy),
      end: Alignment(end.dx, end.dy),
      colors: colors,
      stops: stops,
      tileMode: tileMode,
    ).createShader(bounds);
  }

  Map<String, dynamic> toJson() => {
    'colors': colors.map((c) => c.toARGB32()).toList(),
    'stops': stops,
    'begin': {'x': begin.dx, 'y': begin.dy},
    'end': {'x': end.dx, 'y': end.dy},
  };
}