// File: lib/utils/path_reconstructor.dart
// Description: Rebuilds PathItem models from multi-line Dart path declarations, now supporting bezier curves.

import 'dart:ui';
import '../models/canvas_item.dart';

class PathReconstructor {
  static List<PathNode> parsePathBody(String body) {
    final List<PathNode> nodes = [];
    
    try {
      // Look for moveTo, lineTo, quadraticBezierTo, and cubicTo
      final commandPattern = RegExp(r"(moveTo|lineTo|quadraticBezierTo|cubicTo)\(([^)]+)\)");
      
      for (final match in commandPattern.allMatches(body)) {
        final command = match.group(1)!;
        final argsStr = match.group(2)!;
        
        // Split arguments by comma and safely parse them to doubles
        final args = argsStr.split(',').map((s) => double.tryParse(s.trim()) ?? 0.0).toList();
        
        if (command == 'moveTo' || command == 'lineTo') {
          if (args.length >= 2) {
            nodes.add(PathNode(position: Offset(args[0], args[1])));
          }
        } 
        else if (command == 'quadraticBezierTo') {
          if (args.length >= 4 && nodes.isNotEmpty) {
            // In our data model, a quadratic curve stores its control point in the destination node
            nodes.add(PathNode(
              position: Offset(args[2], args[3]),
              controlPoint1: Offset(args[0], args[1]), 
            ));
          }
        } 
        else if (command == 'cubicTo') {
          if (args.length >= 6 && nodes.isNotEmpty) {
            // A cubic curve splits its control points between the previous node (cp2) and the new node (cp1)
            nodes.last.controlPoint2 = Offset(args[0], args[1]);
            nodes.add(PathNode(
              position: Offset(args[4], args[5]),
              controlPoint1: Offset(args[2], args[3]),
            ));
          }
        }
      }
    } catch (e) {
      print('DEBUG ERROR: PathReconstructor failed: $e');
    }

    return nodes;
  }
}