// File: lib/utils/transform_utils.dart
// Description: Utility for mathematically transforming (scaling, stretching) canvas items.

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/canvas_item.dart';

class TransformUtils {
  /// Scales any CanvasItem proportionally by a given [factor] from a specific [origin].
  static CanvasItem scaleItem(CanvasItem item, double factor, Offset origin) {
    return stretchItem(item, factor, factor, origin);
  }

  /// Stretches any CanvasItem non-proportionally using [scaleX] and [scaleY] from a specific [origin].
  static CanvasItem stretchItem(CanvasItem item, double scaleX, double scaleY, Offset origin) {
    try {
      double strokeScale = (scaleX.abs() + scaleY.abs()) / 2.0;

      if (item is RectItem || item is RRectItem || item is OvalItem) {
        // All three share bounding box transformation math
        Rect baseRect = Rect.zero;
        if (item is RectItem) baseRect = item.rect;
        if (item is RRectItem) baseRect = item.rect;
        if (item is OvalItem) baseRect = item.rect;

        final double left = origin.dx + (baseRect.left - origin.dx) * scaleX;
        final double top = origin.dy + (baseRect.top - origin.dy) * scaleY;
        final double right = origin.dx + (baseRect.right - origin.dx) * scaleX;
        final double bottom = origin.dy + (baseRect.bottom - origin.dy) * scaleY;
        
        final newRect = Rect.fromLTRB(
          math.min(left, right), math.min(top, bottom), 
          math.max(left, right), math.max(top, bottom)
        );

        final newPaint = item.paint.copyWith(
          strokeWidth: item.paint.strokeWidth * strokeScale,
          extrusionOffset: Offset(item.paint.extrusionOffset.dx * scaleX, item.paint.extrusionOffset.dy * scaleY),
        );

        if (item is RectItem) {
          return RectItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: newPaint, rect: newRect);
        } else if (item is OvalItem) {
          return OvalItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: newPaint, rect: newRect);
        } else if (item is RRectItem) {
          return RRectItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: newPaint, rect: newRect, radius: math.max(0, item.radius * strokeScale));
        }
      } 
      else if (item is PathItem) {
        final newNodes = item.nodes.map((node) {
          final pos = Offset(origin.dx + (node.position.dx - origin.dx) * scaleX, origin.dy + (node.position.dy - origin.dy) * scaleY);
          
          final cp1 = node.controlPoint1 != null ? Offset(
            origin.dx + (node.controlPoint1!.dx - origin.dx) * scaleX, 
            origin.dy + (node.controlPoint1!.dy - origin.dy) * scaleY
          ) : null;
          
          final cp2 = node.controlPoint2 != null ? Offset(
            origin.dx + (node.controlPoint2!.dx - origin.dx) * scaleX, 
            origin.dy + (node.controlPoint2!.dy - origin.dy) * scaleY
          ) : null;
          
          return PathNode(position: pos, controlPoint1: cp1, controlPoint2: cp2);
        }).toList();

        return PathItem(
          id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf,
          paint: item.paint.copyWith(strokeWidth: item.paint.strokeWidth * strokeScale, extrusionOffset: Offset(item.paint.extrusionOffset.dx * scaleX, item.paint.extrusionOffset.dy * scaleY)),
          nodes: newNodes, isClosed: item.isClosed,
        );
      }
      else if (item is TextItem) {
        final newPos = Offset(origin.dx + (item.position.dx - origin.dx) * scaleX, origin.dy + (item.position.dy - origin.dy) * scaleY);
        return TextItem(
          id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf,
          paint: item.paint.copyWith(strokeWidth: item.paint.strokeWidth * strokeScale, extrusionOffset: Offset(item.paint.extrusionOffset.dx * scaleX, item.paint.extrusionOffset.dy * scaleY)),
          position: newPos, text: item.text, fontSize: math.max(1.0, item.fontSize * strokeScale), isBold: item.isBold,
        );
      }
      else if (item is LogicGroupItem) {
        final newChildren = item.children.map((child) => stretchItem(child, scaleX, scaleY, origin)).toList();
        return LogicGroupItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, condition: item.condition, children: newChildren);
      }
    } catch (e) {
      print('DEBUG ERROR: TransformUtils.stretchItem failed: $e');
    }
    
    return item;
  }
}