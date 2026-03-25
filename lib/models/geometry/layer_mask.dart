// File: lib/models/geometry/layer_mask.dart
// Description: Defines a clipping area or mask for a group of items.

import 'package:flutter/material.dart';

class LayerMask {
  final String id;
  final Path maskPath;
  final bool inverted; // If true, clips everything INSIDE the path

  LayerMask({
    required this.id,
    required this.maskPath,
    this.inverted = false,
  });

  void apply(Canvas canvas, VoidCallback drawContent) {
    canvas.save();
    // In Flutter, we use ClipPath to define the mask
    canvas.clipPath(maskPath);
    drawContent();
    canvas.restore();
  }
}