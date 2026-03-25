// File: lib/models/editor/preview_context.dart
// Description: Defines different scaling contexts to test asset visibility.

import 'package:flutter/material.dart';

class PreviewContext {
  final String name;
  final double scale;
  final double strokeMultiplier;

  PreviewContext({
    required this.name,
    required this.scale,
    this.strokeMultiplier = 1.0,
  });

  static List<PreviewContext> defaults = [
    PreviewContext(name: "World (1:1)", scale: 1.0),
    PreviewContext(name: "Map (0.4x)", scale: 0.4, strokeMultiplier: 1.2), // Thicker lines for map
    PreviewContext(name: "Icon (0.1x)", scale: 0.1, strokeMultiplier: 2.0),
  ];
}