// File: lib/utils/bounding_box_utils.dart
// Description: Utilities for calculating combined boundaries for multiple items, respecting affine transformations (rotation, scale).

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/canvas_item.dart';
import 'path_math.dart'; 

class BoundingBoxUtils {
  /// Takes a local rect and a transformation matrix, and returns a new 
  /// axis-aligned Rect that fully encloses the transformed corners.
  static Rect _getTransformedRectBounds(Rect localRect, Matrix4 transform) {
    try {
      final tl = MatrixUtils.transformPoint(transform, localRect.topLeft);
      final tr = MatrixUtils.transformPoint(transform, localRect.topRight);
      final bl = MatrixUtils.transformPoint(transform, localRect.bottomLeft);
      final br = MatrixUtils.transformPoint(transform, localRect.bottomRight);

      double minX = math.min(math.min(tl.dx, tr.dx), math.min(bl.dx, br.dx));
      double maxX = math.max(math.max(tl.dx, tr.dx), math.max(bl.dx, br.dx));
      double minY = math.min(math.min(tl.dy, tr.dy), math.min(bl.dy, br.dy));
      double maxY = math.max(math.max(tl.dy, tr.dy), math.max(bl.dy, br.dy));

      return Rect.fromLTRB(minX, minY, maxX, maxY);
    } catch (e) {
      print('DEBUG ERROR: _getTransformedRectBounds failed: $e');
      return localRect;
    }
  }

  static Rect getCombinedRect(List<CanvasItem> items) {
    if (items.isEmpty) return Rect.zero;
    
    Rect combined = Rect.largest; 
    bool first = true;

    try {
      for (var item in items) {
        Rect localBounds = Rect.zero;
        
        if (item is RectItem) localBounds = item.rect;
        else if (item is RRectItem) localBounds = item.rect;
        else if (item is OvalItem) localBounds = item.rect;
        else if (item is PathItem) localBounds = PathMath.getBoundingBox(item.nodes.map((n) => n.position).toList());
        else if (item is TextItem) {
          final approxWidth = item.text.length * (item.fontSize * 0.6);
          localBounds = Rect.fromLTWH(item.position.dx, item.position.dy, approxWidth, item.fontSize * 1.2);
        } 
        else if (item is LogicGroupItem) {
          // A group's local bounds are the combined bounds of its children
          localBounds = getCombinedRect(item.children);
        }

        if (localBounds != Rect.zero) {
          // Apply the item's matrix to its local bounds to get its actual footprint in the current space
          Rect transformedBounds = _getTransformedRectBounds(localBounds, item.transform);
          
          if (first) {
            combined = transformedBounds;
            first = false;
          } else {
            combined = combined.expandToInclude(transformedBounds);
          }
        }
      }
    } catch (e) {
      print('DEBUG ERROR: BoundingBoxUtils.getCombinedRect failed: $e');
    }
    
    return first ? Rect.zero : combined;
  }
}