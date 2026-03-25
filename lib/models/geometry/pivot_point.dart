// File: lib/models/geometry/pivot_point.dart
// Description: Defines the anchor point for transformations (Scale/Rotate).

import 'package:flutter/material.dart';

enum AnchorAlignment { topLeft, topCenter, topRight, centerLeft, center, centerRight, bottomLeft, bottomCenter, bottomRight }

class PivotPoint {
  final AnchorAlignment alignment;
  final Offset customOffset;

  PivotPoint({this.alignment = AnchorAlignment.center, this.customOffset = Offset.zero});

  Offset getOffset(Rect bounds) {
    switch (alignment) {
      case AnchorAlignment.bottomCenter:
        return Offset(bounds.center.dx, bounds.bottom);
      case AnchorAlignment.topCenter:
        return Offset(bounds.center.dx, bounds.top);
      // ... handle other alignments
      default:
        return bounds.center;
    }
  }
}