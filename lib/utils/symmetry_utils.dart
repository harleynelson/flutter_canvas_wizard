// File: lib/utils/symmetry_utils.dart
// Description: Math for mirroring points and nodes across the X or Y axis.

import 'package:flutter/material.dart';

enum SymmetryAxis { horizontal, vertical, none }

class SymmetryUtils {
  /// Returns a point mirrored across the specified axis relative to a center.
  static Offset mirrorPoint(Offset point, Offset center, SymmetryAxis axis) {
    switch (axis) {
      case SymmetryAxis.vertical:
        // Flip across the vertical line passing through center.dx
        double dist = point.dx - center.dx;
        return Offset(center.dx - dist, point.dy);
      case SymmetryAxis.horizontal:
        // Flip across the horizontal line passing through center.dy
        double dist = point.dy - center.dy;
        return Offset(point.dx, center.dy - dist);
      case SymmetryAxis.none:
        return point;
    }
  }
}