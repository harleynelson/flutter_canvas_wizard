// File: lib/utils/bounding_box_utils.dart
// Description: Utilities for calculating combined boundaries for multiple items.

import 'package:flutter/material.dart';
import '../models/canvas_item.dart';
import 'path_math.dart'; // Added import for path bounding boxes

class BoundingBoxUtils {
  static Rect getCombinedRect(List<CanvasItem> items) {
    if (items.isEmpty) return Rect.zero;
    
    Rect combined = Rect.largest; 
    bool first = true;

    try {
      for (var item in items) {
        Rect itemBounds = Rect.zero;
        
        if (item is RectItem) {
          itemBounds = item.rect;
        } else if (item is RRectItem) {
          itemBounds = item.rect;
        } else if (item is OvalItem) {
          itemBounds = item.rect;
        } else if (item is PathItem) {
          itemBounds = PathMath.getBoundingBox(item.nodes.map((n) => n.position).toList());
        } else if (item is TextItem) {
          // Rough approximation for bounding box without full TextPainter layout cost
          final approxWidth = item.text.length * (item.fontSize * 0.6);
          itemBounds = Rect.fromLTWH(item.position.dx, item.position.dy, approxWidth, item.fontSize * 1.2);
        } else if (item is LogicGroupItem) {
          itemBounds = getCombinedRect(item.children);
        }

        if (itemBounds != Rect.zero) {
          if (first) {
            combined = itemBounds;
            first = false;
          } else {
            combined = combined.expandToInclude(itemBounds);
          }
        }
      }
    } catch (e) {
      print('DEBUG ERROR: BoundingBoxUtils.getCombinedRect failed: $e');
    }
    
    return first ? Rect.zero : combined;
  }
}