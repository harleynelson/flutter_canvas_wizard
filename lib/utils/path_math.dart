// File: lib/utils/path_math.dart
// Description: Pure math utility for vector calculations, hit-testing, and bounding boxes.

import 'dart:ui';
import 'dart:math' as math;
import '../models/canvas_item.dart';

class PathMath {
  /// Determines if a point is within a certain [tolerance] of a line segment.
  static bool isPointOnLine(Offset point, Offset start, Offset end, double tolerance) {
    try {
      final double l2 = (start.dx - end.dx) * (start.dx - end.dx) + (start.dy - end.dy) * (start.dy - end.dy);
      if (l2 == 0.0) return (point - start).distance <= tolerance;
      
      double t = ((point.dx - start.dx) * (end.dx - start.dx) + (point.dy - start.dy) * (end.dy - start.dy)) / l2;
      t = math.max(0, math.min(1, t));
      
      final projection = Offset(
        start.dx + t * (end.dx - start.dx),
        start.dy + t * (end.dy - start.dy),
      );
      
      return (point - projection).distance <= tolerance;
    } catch (e) {
      print('DEBUG ERROR: isPointOnLine failed: $e');
      return false;
    }
  }

  /// Samples a cubic bezier curve to check if a point is near it.
  static bool hitTestBezier(Offset p0, Offset p1, Offset p2, Offset p3, Offset point, double tolerance) {
    try {
      const int samples = 15; // Sufficient density for hit testing
      Offset prev = p0;
      for (int i = 1; i <= samples; i++) {
        double t = i / samples;
        double mt = 1.0 - t;
        Offset current = p0 * (mt * mt * mt) + p1 * (3 * mt * mt * t) + p2 * (3 * mt * t * t) + p3 * (t * t * t);
        if (isPointOnLine(point, prev, current, tolerance)) return true;
        prev = current;
      }
      return false;
    } catch (e) {
      print('DEBUG ERROR: hitTestBezier failed: $e');
      return false;
    }
  }

  /// Finds the index of the path segment (edge) that was clicked.
  static int? getHitSegmentIndex(List<PathNode> nodes, bool isClosed, Offset point, double tolerance) {
    try {
      if (nodes.length < 2) return null;

      for (int i = 0; i < nodes.length; i++) {
        int nextIndex = i + 1;
        if (nextIndex >= nodes.length) {
          if (!isClosed) break;
          nextIndex = 0;
        }

        final start = nodes[i];
        final end = nodes[nextIndex];

        bool hit = false;
        if (start.controlPoint2 != null || end.controlPoint1 != null) {
          hit = hitTestBezier(
            start.position,
            start.controlPoint2 ?? start.position,
            end.controlPoint1 ?? end.position,
            end.position,
            point,
            tolerance,
          );
        } else {
          hit = isPointOnLine(point, start.position, end.position, tolerance);
        }

        if (hit) return i;
      }
      return null;
    } catch (e) {
      print('DEBUG ERROR: getHitSegmentIndex failed: $e');
      return null;
    }
  }

  /// Calculates the bounding box of a list of points.
  static Rect getBoundingBox(List<Offset> points) {
    try {
      if (points.isEmpty) return Rect.zero;
      double minX = points[0].dx;
      double maxX = points[0].dx;
      double minY = points[0].dy;
      double maxY = points[0].dy;

      for (var p in points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      return Rect.fromLTRB(minX, minY, maxX, maxY);
    } catch (e) {
      print('DEBUG ERROR: getBoundingBox failed: $e');
      return Rect.zero;
    }
  }
}