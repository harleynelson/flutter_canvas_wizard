// File: lib/utils/shape_generator.dart
// Description: Utility class to generate mathematical PathItems for pre-built shapes (Circles, Polygons, Stars).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/canvas_item.dart';

class ShapeGenerator {
  /// Generates a circular PathItem using 4 cubic bezier curves.
  static PathItem createCircle({
    required String id,
    required String name,
    required Offset center,
    required double radius,
    required CanvasPaint paint,
  }) {
    try {
      // Magic number to approximate a circle with 4 bezier curves
      final double kappa = 4.0 * ((math.sqrt(2) - 1.0) / 3.0);
      final double controlDist = radius * kappa;

      final nodes = [
        // Top
        PathNode(
          position: Offset(center.dx, center.dy - radius),
          controlPoint1: Offset(center.dx - controlDist, center.dy - radius),
          controlPoint2: Offset(center.dx + controlDist, center.dy - radius),
        ),
        // Right
        PathNode(
          position: Offset(center.dx + radius, center.dy),
          controlPoint1: Offset(center.dx + radius, center.dy - controlDist),
          controlPoint2: Offset(center.dx + radius, center.dy + controlDist),
        ),
        // Bottom
        PathNode(
          position: Offset(center.dx, center.dy + radius),
          controlPoint1: Offset(center.dx + controlDist, center.dy + radius),
          controlPoint2: Offset(center.dx - controlDist, center.dy + radius),
        ),
        // Left
        PathNode(
          position: Offset(center.dx - radius, center.dy),
          controlPoint1: Offset(center.dx - radius, center.dy + controlDist),
          controlPoint2: Offset(center.dx - radius, center.dy - controlDist),
        ),
      ];

      return PathItem(
        id: id,
        name: name,
        paint: paint,
        nodes: nodes,
        isClosed: true,
      );
    } catch (e) {
      print('DEBUG ERROR: ShapeGenerator.createCircle failed: $e');
      // Fallback to empty path on error
      return PathItem(id: id, name: 'Error Circle', paint: paint, nodes: []);
    }
  }

  /// Generates a regular polygon (Triangle, Pentagon, Hexagon, etc.)
  static PathItem createPolygon({
    required String id,
    required String name,
    required Offset center,
    required int sides,
    required double radius,
    required CanvasPaint paint,
  }) {
    try {
      if (sides < 3) sides = 3;
      final List<PathNode> nodes = [];
      final double angleStep = (math.pi * 2) / sides;
      
      // Start at the top (-pi/2)
      double currentAngle = -math.pi / 2;

      for (int i = 0; i < sides; i++) {
        final double x = center.dx + radius * math.cos(currentAngle);
        final double y = center.dy + radius * math.sin(currentAngle);
        
        nodes.add(PathNode(position: Offset(x, y)));
        currentAngle += angleStep;
      }

      return PathItem(
        id: id,
        name: name,
        paint: paint,
        nodes: nodes,
        isClosed: true,
      );
    } catch (e) {
      print('DEBUG ERROR: ShapeGenerator.createPolygon failed: $e');
      return PathItem(id: id, name: 'Error Polygon', paint: paint, nodes: []);
    }
  }

  /// Generates a star shape
  static PathItem createStar({
    required String id,
    required String name,
    required Offset center,
    required int points,
    required double innerRadius,
    required double outerRadius,
    required CanvasPaint paint,
  }) {
    try {
      if (points < 3) points = 3;
      final List<PathNode> nodes = [];
      final double angleStep = math.pi / points; // Half-steps for inner/outer vertices
      
      // Start at the top (-pi/2)
      double currentAngle = -math.pi / 2;

      for (int i = 0; i < points * 2; i++) {
        final double r = (i % 2 == 0) ? outerRadius : innerRadius;
        final double x = center.dx + r * math.cos(currentAngle);
        final double y = center.dy + r * math.sin(currentAngle);
        
        nodes.add(PathNode(position: Offset(x, y)));
        currentAngle += angleStep;
      }

      return PathItem(
        id: id,
        name: name,
        paint: paint,
        nodes: nodes,
        isClosed: true,
      );
    } catch (e) {
      print('DEBUG ERROR: ShapeGenerator.createStar failed: $e');
      return PathItem(id: id, name: 'Error Star', paint: paint, nodes: []);
    }
  }
}