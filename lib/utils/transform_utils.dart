// File: lib/utils/transform_utils.dart
// Description: Utility for mathematically transforming (scaling, translating, rotating, flipping) canvas items using Matrix4.

import 'package:flutter/material.dart';
import '../models/canvas_item.dart';

class TransformUtils {
  /// Translates an item by a given [delta].
  static CanvasItem translateItem(CanvasItem item, Offset delta) {
    try {
      final translationMatrix = Matrix4.translationValues(delta.dx, delta.dy, 0.0);
      final newTransform = translationMatrix.multiplied(item.transform);
      return item.copyWithTransform(newTransform);
    } catch (e) {
      print('DEBUG ERROR: TransformUtils.translateItem failed: $e');
      return item;
    }
  }

  /// Scales/Stretches any CanvasItem using [scaleX] and [scaleY] from a specific [origin].
  static CanvasItem stretchItem(CanvasItem item, double scaleX, double scaleY, Offset origin) {
    try {
      final scaleMatrix = Matrix4.identity()
        ..translate(origin.dx, origin.dy)
        ..scale(scaleX, scaleY, 1.0)
        ..translate(-origin.dx, -origin.dy);

      final newTransform = scaleMatrix.multiplied(item.transform);
      return item.copyWithTransform(newTransform);
    } catch (e) {
      print('DEBUG ERROR: TransformUtils.stretchItem failed: $e');
      return item;
    }
  }

  /// Scales any CanvasItem proportionally by a given [factor] from a specific [origin].
  static CanvasItem scaleItem(CanvasItem item, double factor, Offset origin) {
    return stretchItem(item, factor, factor, origin);
  }

  /// Rotates an item by [angleRadians] around a specific [origin].
  static CanvasItem rotateItem(CanvasItem item, double angleRadians, Offset origin) {
    try {
      final rotationMatrix = Matrix4.identity()
        ..translate(origin.dx, origin.dy)
        ..rotateZ(angleRadians)
        ..translate(-origin.dx, -origin.dy);

      final newTransform = rotationMatrix.multiplied(item.transform);
      return item.copyWithTransform(newTransform);
    } catch (e) {
      print('DEBUG ERROR: TransformUtils.rotateItem failed: $e');
      return item;
    }
  }

  /// Flips an item horizontally or vertically around a specific [origin].
  static CanvasItem flipItem(CanvasItem item, bool flipX, bool flipY, Offset origin) {
    try {
      final flipMatrix = Matrix4.identity()
        ..translate(origin.dx, origin.dy)
        ..scale(flipX ? -1.0 : 1.0, flipY ? -1.0 : 1.0, 1.0)
        ..translate(-origin.dx, -origin.dy);

      final newTransform = flipMatrix.multiplied(item.transform);
      return item.copyWithTransform(newTransform);
    } catch (e) {
      print('DEBUG ERROR: TransformUtils.flipItem failed: $e');
      return item;
    }
  }
}