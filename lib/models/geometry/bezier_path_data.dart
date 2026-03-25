// File: lib/models/geometry/bezier_path_data.dart
// Description: A logic-heavy model that computes a ui.Path from a list of nodes.

import 'package:flutter/material.dart';
import '../canvas_item.dart';

class BezierPathData {
  final List<PathNode> nodes;
  final bool isClosed;

  BezierPathData({required this.nodes, this.isClosed = true});

  /// Generates the actual Flutter Path object for the CustomPainter.
  Path generatePath() {
    final path = Path();
    if (nodes.isEmpty) return path;

    try {
      path.moveTo(nodes[0].position.dx, nodes[0].position.dy);

      for (int i = 0; i < nodes.length; i++) {
        final currentNode = nodes[i];
        final nextIndex = i + 1;
        
        // If we're at the end, determine if we need to curve back to the start
        if (nextIndex >= nodes.length) {
          if (isClosed) {
            final nextNode = nodes[0];
            if (currentNode.controlPoint2 != null && nextNode.controlPoint1 != null) {
              // Cubic Bezier to close the path
              path.cubicTo(
                currentNode.controlPoint2!.dx, currentNode.controlPoint2!.dy,
                nextNode.controlPoint1!.dx, nextNode.controlPoint1!.dy,
                nextNode.position.dx, nextNode.position.dy,
              );
            } else if (currentNode.controlPoint2 != null || nextNode.controlPoint1 != null) {
              // Quadratic Bezier to close the path
              final cp = currentNode.controlPoint2 ?? nextNode.controlPoint1!;
              path.quadraticBezierTo(cp.dx, cp.dy, nextNode.position.dx, nextNode.position.dy);
            } else {
              // Simple Line to close the path
              path.lineTo(nextNode.position.dx, nextNode.position.dy);
            }
            path.close();
          }
          break;
        }

        final nextNode = nodes[nextIndex];

        if (currentNode.controlPoint2 != null && nextNode.controlPoint1 != null) {
          // Cubic Bezier
          path.cubicTo(
            currentNode.controlPoint2!.dx, currentNode.controlPoint2!.dy,
            nextNode.controlPoint1!.dx, nextNode.controlPoint1!.dy,
            nextNode.position.dx, nextNode.position.dy,
          );
        } else if (currentNode.controlPoint2 != null || nextNode.controlPoint1 != null) {
          // Quadratic Bezier (Fallback to whichever control point exists)
          final cp = currentNode.controlPoint2 ?? nextNode.controlPoint1!;
          path.quadraticBezierTo(cp.dx, cp.dy, nextNode.position.dx, nextNode.position.dy);
        } else {
          // Simple Line
          path.lineTo(nextNode.position.dx, nextNode.position.dy);
        }
      }
    } catch (e) {
      print('DEBUG ERROR: Path generation failed: $e');
    }
    return path;
  }
}