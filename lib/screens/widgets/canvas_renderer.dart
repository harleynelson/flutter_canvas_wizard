// File: lib/screens/widgets/canvas_renderer.dart
// Description: Renders the models and overlays interactive editing elements, now with Ghosting and Multi-select support.

import 'package:flutter/material.dart';
import '../../models/canvas_item.dart';
import '../../models/geometry/bezier_path_data.dart';
import '../../utils/bounding_box_utils.dart'; 
import '../../utils/expression_evaluator.dart';
import 'interactive_canvas.dart'; 

class EditorCanvasPainter extends CustomPainter {
  final List<CanvasItem> items;
  final Set<String> selectedItemIds; // NEW: Multi-select support
  final String? hoveredItemId;
  final HandleType hoveredHandle;
  final Offset? hoverPos;
  final int? hoveredNodeIndex; 
  final double gridSnapSize;
  
  // Camera & Global State
  final Offset cameraPan;
  final double cameraZoom;
  final bool isTransformMode;
  final Map<String, double> variables;
  
  // Marquee State
  final Rect? marqueeRect; 
  
  final bool isExportMode;

  EditorCanvasPainter({
    required this.items,
    this.selectedItemIds = const {},
    this.hoveredItemId,
    this.hoveredHandle = HandleType.none,
    this.hoverPos,
    this.hoveredNodeIndex,
    this.gridSnapSize = 10.0,
    this.cameraPan = Offset.zero,
    this.cameraZoom = 1.0,
    this.isTransformMode = false,
    this.variables = const {},
    this.marqueeRect,
    this.isExportMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.translate(cameraPan.dx, cameraPan.dy);
      canvas.scale(cameraZoom);

      if (!isExportMode) {
        _drawGrid(canvas, size);
        _drawOriginAxis(canvas, size);
      }

      for (var item in items) {
        _renderItem(canvas, item, inheritedGhost: false);
      }

      if (!isExportMode) {
        if (hoveredItemId != null && !selectedItemIds.contains(hoveredItemId)) {
          final hoveredItem = _findItemRecursive(items, hoveredItemId);
          if (hoveredItem != null) _drawHoverHighlight(canvas, hoveredItem);
        }

        final selectedItems = _findItemsRecursive(items, selectedItemIds);
        if (selectedItems.isNotEmpty) {
          if (isTransformMode) {
             _drawTransformBox(canvas, selectedItems); // Draw one big box
          } else {
             for (var item in selectedItems) {
               _drawSelectionHighlight(canvas, item); // Draw individual highlights
             }
          }
        }
        
        // Draw Marquee
        if (marqueeRect != null) {
          final paintFill = Paint()..color = Colors.blueAccent.withOpacity(0.2)..style = PaintingStyle.fill;
          final paintStroke = Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 1.0 / cameraZoom;
          canvas.drawRect(marqueeRect!, paintFill);
          canvas.drawRect(marqueeRect!, paintStroke);
        }
      }
      
      canvas.restore();
    } catch (e) {
      print('DEBUG ERROR: EditorCanvasPainter.paint failed: $e');
    }
  }

  void _renderItem(Canvas canvas, CanvasItem item, {bool inheritedGhost = false}) {
    if (!item.isVisible) return;
    bool isGhost = inheritedGhost || !ExpressionEvaluator.evaluate(item.enabledIf, variables);

    try {
      if (item is RectItem) _drawRectItem(canvas, item, isGhost);
      else if (item is RRectItem) _drawRRectItem(canvas, item, isGhost);
      else if (item is OvalItem) _drawOvalItem(canvas, item, isGhost);
      else if (item is PathItem) _drawPathItem(canvas, item, isGhost);
      else if (item is TextItem) _drawTextItem(canvas, item, isGhost);
      else if (item is LogicGroupItem) {
        for (var child in item.children) _renderItem(canvas, child, inheritedGhost: isGhost);
      }
    } catch (e) {
      print('DEBUG ERROR: _renderItem failed for ${item.id}: $e');
    }
  }

  void _drawTextItem(Canvas canvas, TextItem item, bool isGhost) {
    try {
      final fillColor = isGhost ? item.paint.fillColor.withOpacity(0.1) : item.paint.fillColor;
      final textStyle = TextStyle(color: fillColor, fontSize: item.fontSize, fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal);

      if (item.paint.fillColor != Colors.transparent) {
        final textPainter = TextPainter(text: TextSpan(text: item.text, style: textStyle), textDirection: TextDirection.ltr);
        textPainter.layout();
        textPainter.paint(canvas, item.position);
      }

      final sWidth = isGhost ? (item.paint.strokeWidth == 0 ? 1.0 / cameraZoom : item.paint.strokeWidth) : item.paint.strokeWidth;
      if (sWidth > 0 || isGhost) {
        final strokeColor = isGhost ? Colors.white.withOpacity(0.2) : item.paint.strokeColor;
        final strokeStyle = textStyle.copyWith(foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = sWidth..color = strokeColor);
        final strokePainter = TextPainter(text: TextSpan(text: item.text, style: strokeStyle), textDirection: TextDirection.ltr);
        strokePainter.layout();
        strokePainter.paint(canvas, item.position);
      }
    } catch (e) {
      print('DEBUG ERROR: _drawTextItem failed for ${item.id}: $e');
    }
  }

  void _drawRRectItem(Canvas canvas, RRectItem item, bool isGhost) {
    try {
      final paint = Paint()..strokeCap = item.paint.strokeCap..blendMode = item.paint.blendMode;
      final fillColor = isGhost ? item.paint.fillColor.withOpacity(0.1) : item.paint.fillColor;
      final strokeColor = isGhost ? Colors.white.withOpacity(0.2) : item.paint.strokeColor;
      final sWidth = isGhost ? (item.paint.strokeWidth == 0 ? 1.0 / cameraZoom : item.paint.strokeWidth) : item.paint.strokeWidth;

      for (int i = item.paint.extrusionSteps; i >= 0; i--) {
        final offset = Offset(item.paint.extrusionOffset.dx * i, item.paint.extrusionOffset.dy * i);
        final rrect = RRect.fromRectAndRadius(item.rect.shift(offset), Radius.circular(item.radius));

        if (item.paint.fillColor != Colors.transparent) canvas.drawRRect(rrect, paint..color = i == 0 ? fillColor : fillColor.withOpacity(isGhost ? 0.05 : 0.8)..style = PaintingStyle.fill);
        if (sWidth > 0 || isGhost) canvas.drawRRect(rrect, paint..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = sWidth);
      }
    } catch (e) {
      print('DEBUG ERROR: _drawRRectItem failed for ${item.id}: $e');
    }
  }

  void _drawOvalItem(Canvas canvas, OvalItem item, bool isGhost) {
    try {
      final paint = Paint()..strokeCap = item.paint.strokeCap..blendMode = item.paint.blendMode;
      final fillColor = isGhost ? item.paint.fillColor.withOpacity(0.1) : item.paint.fillColor;
      final strokeColor = isGhost ? Colors.white.withOpacity(0.2) : item.paint.strokeColor;
      final sWidth = isGhost ? (item.paint.strokeWidth == 0 ? 1.0 / cameraZoom : item.paint.strokeWidth) : item.paint.strokeWidth;

      for (int i = item.paint.extrusionSteps; i >= 0; i--) {
        final offset = Offset(item.paint.extrusionOffset.dx * i, item.paint.extrusionOffset.dy * i);
        final rect = item.rect.shift(offset);

        if (item.paint.fillColor != Colors.transparent) canvas.drawOval(rect, paint..color = i == 0 ? fillColor : fillColor.withOpacity(isGhost ? 0.05 : 0.8)..style = PaintingStyle.fill);
        if (sWidth > 0 || isGhost) canvas.drawOval(rect, paint..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = sWidth);
      }
    } catch (e) {
      print('DEBUG ERROR: _drawOvalItem failed for ${item.id}: $e');
    }
  }

  void _drawRectItem(Canvas canvas, RectItem item, bool isGhost) {
    try {
      final paint = Paint()..strokeCap = item.paint.strokeCap..blendMode = item.paint.blendMode;
      final fillColor = isGhost ? item.paint.fillColor.withOpacity(0.1) : item.paint.fillColor;
      final strokeColor = isGhost ? Colors.white.withOpacity(0.2) : item.paint.strokeColor;
      final sWidth = isGhost ? (item.paint.strokeWidth == 0 ? 1.0 / cameraZoom : item.paint.strokeWidth) : item.paint.strokeWidth;

      for (int i = item.paint.extrusionSteps; i >= 0; i--) {
        final offset = Offset(item.paint.extrusionOffset.dx * i, item.paint.extrusionOffset.dy * i);
        final rect = item.rect.shift(offset);

        if (item.paint.fillColor != Colors.transparent) canvas.drawRect(rect, paint..color = i == 0 ? fillColor : fillColor.withOpacity(isGhost ? 0.05 : 0.8)..style = PaintingStyle.fill);
        if (sWidth > 0 || isGhost) canvas.drawRect(rect, paint..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = sWidth);
      }
    } catch (e) {
      print('DEBUG ERROR: _drawRectItem failed for ${item.id}: $e');
    }
  }

  void _drawPathItem(Canvas canvas, PathItem item, bool isGhost) {
    try {
      final paint = Paint()..strokeCap = item.paint.strokeCap..blendMode = item.paint.blendMode;
      final path = BezierPathData(nodes: item.nodes, isClosed: item.isClosed).generatePath();
      final fillColor = isGhost ? item.paint.fillColor.withOpacity(0.1) : item.paint.fillColor;
      final strokeColor = isGhost ? Colors.white.withOpacity(0.2) : item.paint.strokeColor;
      final sWidth = isGhost ? (item.paint.strokeWidth == 0 ? 1.0 / cameraZoom : item.paint.strokeWidth) : item.paint.strokeWidth;

      if (item.paint.fillColor != Colors.transparent) canvas.drawPath(path, paint..color = fillColor..style = PaintingStyle.fill);
      if (sWidth > 0 || isGhost) canvas.drawPath(path, paint..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = sWidth);
    } catch (e) {
      print('DEBUG ERROR: _drawPathItem failed for ${item.id}: $e');
    }
  }

  // Updated to combine bounding box of ALL selected items
  void _drawTransformBox(Canvas canvas, List<CanvasItem> selectedItems) {
    try {
       final Rect bounds = BoundingBoxUtils.getCombinedRect(selectedItems);
       if (bounds == Rect.zero) return;

       final paddedRect = bounds.inflate(4.0 / cameraZoom);
       final boxPaint = Paint()..color = Colors.cyanAccent..style = PaintingStyle.stroke..strokeWidth = 1.5 / cameraZoom;
       canvas.drawRect(paddedRect, boxPaint);

       final nodeFill = Paint()..color = Colors.white..style = PaintingStyle.fill;
       final nodeHoverFill = Paint()..color = Colors.cyanAccent..style = PaintingStyle.fill;

       _drawNode(canvas, paddedRect.topLeft, hoveredHandle == HandleType.topLeft ? nodeHoverFill : nodeFill);
       _drawNode(canvas, paddedRect.topRight, hoveredHandle == HandleType.topRight ? nodeHoverFill : nodeFill);
       _drawNode(canvas, paddedRect.bottomLeft, hoveredHandle == HandleType.bottomLeft ? nodeHoverFill : nodeFill);
       _drawNode(canvas, paddedRect.bottomRight, hoveredHandle == HandleType.bottomRight ? nodeHoverFill : nodeFill);
       _drawNode(canvas, Offset(paddedRect.center.dx, paddedRect.top), hoveredHandle == HandleType.topEdge ? nodeHoverFill : nodeFill);
       _drawNode(canvas, Offset(paddedRect.center.dx, paddedRect.bottom), hoveredHandle == HandleType.bottomEdge ? nodeHoverFill : nodeFill);
       _drawNode(canvas, Offset(paddedRect.left, paddedRect.center.dy), hoveredHandle == HandleType.leftEdge ? nodeHoverFill : nodeFill);
       _drawNode(canvas, Offset(paddedRect.right, paddedRect.center.dy), hoveredHandle == HandleType.rightEdge ? nodeHoverFill : nodeFill);

    } catch (e) {
       print('DEBUG ERROR: _drawTransformBox failed: $e');
    }
  }

  CanvasItem? _findItemRecursive(List<CanvasItem> list, String? id) {
    if (id == null) return null;
    for (var item in list) {
      if (item.id == id) return item;
      if (item is LogicGroupItem) {
        final found = _findItemRecursive(item.children, id);
        if (found != null) return found;
      }
    }
    return null;
  }
  
  List<CanvasItem> _findItemsRecursive(List<CanvasItem> list, Set<String> ids) {
    List<CanvasItem> found = [];
    if (ids.isEmpty) return found;
    void search(List<CanvasItem> items) {
      for (var item in items) {
        if (ids.contains(item.id)) found.add(item);
        if (item is LogicGroupItem) search(item.children);
      }
    }
    search(list);
    return found;
  }

  void _drawGrid(Canvas canvas, Size size) {
    try {
      final double left = (-size.width / 2 - cameraPan.dx) / cameraZoom;
      final double right = (size.width / 2 - cameraPan.dx) / cameraZoom;
      final double top = (-size.height / 2 - cameraPan.dy) / cameraZoom;
      final double bottom = (size.height / 2 - cameraPan.dy) / cameraZoom;

      final minorPaint = Paint()..color = Colors.white.withOpacity(0.03)..style = PaintingStyle.stroke..strokeWidth = 1 / cameraZoom;
      final majorPaint = Paint()..color = Colors.white.withOpacity(0.08)..style = PaintingStyle.stroke..strokeWidth = 1 / cameraZoom;

      final double step = 50.0;
      final int startX = (left / step).floor();
      final int endX = (right / step).ceil();
      final int startY = (top / step).floor();
      final int endY = (bottom / step).ceil();

      for (int i = startX; i <= endX; i++) {
        double x = i * step;
        canvas.drawLine(Offset(x, top), Offset(x, bottom), (i % 2 == 0) ? majorPaint : minorPaint);
      }
      for (int i = startY; i <= endY; i++) {
        double y = i * step;
        canvas.drawLine(Offset(left, y), Offset(right, y), (i % 2 == 0) ? majorPaint : minorPaint);
      }
    } catch (e) {
      print('DEBUG ERROR: _drawGrid failed: $e');
    }
  }

  void _drawOriginAxis(Canvas canvas, Size size) {
    try {
      final double left = (-size.width / 2 - cameraPan.dx) / cameraZoom;
      final double right = (size.width / 2 - cameraPan.dx) / cameraZoom;
      final double top = (-size.height / 2 - cameraPan.dy) / cameraZoom;
      final double bottom = (size.height / 2 - cameraPan.dy) / cameraZoom;

      final axisPaint = Paint()..color = Colors.green.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 1.5 / cameraZoom;

      canvas.drawLine(Offset(0, top), Offset(0, bottom), axisPaint);
      canvas.drawLine(Offset(left, 0), Offset(right, 0), axisPaint);

      final textStyle = TextStyle(color: Colors.white54, fontSize: 10 / cameraZoom, fontWeight: FontWeight.bold);

      final double step = 100.0; 
      final int startX = (left / step).floor();
      final int endX = (right / step).ceil();
      final int startY = (top / step).floor();
      final int endY = (bottom / step).ceil();

      final double tickDist = 3 / cameraZoom;
      final double textOffset = 4 / cameraZoom;

      for (int i = startX; i <= endX; i++) {
        if (i == 0) continue; 
        double x = i * step;
        final tp = TextPainter(text: TextSpan(text: '${x.toInt()}', style: textStyle), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(x + textOffset, textOffset));
        canvas.drawLine(Offset(x, -tickDist), Offset(x, tickDist), axisPaint);
      }
      for (int i = startY; i <= endY; i++) {
        if (i == 0) continue; 
        double y = i * step;
        final tp = TextPainter(text: TextSpan(text: '${y.toInt()}', style: textStyle), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(textOffset, y + (2 / cameraZoom)));
        canvas.drawLine(Offset(-tickDist, y), Offset(tickDist, y), axisPaint);
      }
    } catch (e) {
      print('DEBUG ERROR: _drawOriginAxis failed: $e');
    }
  }

  void _drawHoverHighlight(Canvas canvas, CanvasItem item) {
    try {
      final hoverPaint = Paint()..color = Colors.white.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 4 / cameraZoom;
        
      if (item is RectItem) canvas.drawRect(item.rect, hoverPaint);
      else if (item is RRectItem) canvas.drawRRect(RRect.fromRectAndRadius(item.rect, Radius.circular(item.radius)), hoverPaint);
      else if (item is OvalItem) canvas.drawOval(item.rect, hoverPaint);
      else if (item is PathItem) canvas.drawPath(BezierPathData(nodes: item.nodes, isClosed: item.isClosed).generatePath(), hoverPaint);
      else if (item is LogicGroupItem && item.children.isNotEmpty) {
        final rect = BoundingBoxUtils.getCombinedRect(item.children);
        if (rect != Rect.zero) canvas.drawRect(rect.inflate(8.0), hoverPaint);
      }
    } catch (e) {
      print('DEBUG ERROR: Hover highlight failed: $e');
    }
  }

  void _drawSelectionHighlight(Canvas canvas, CanvasItem selectedItem) {
    try {
      final strokeW = 2.0 / cameraZoom;
      final nodeFill = Paint()..color = Colors.white..style = PaintingStyle.fill;
      final nodeHoverFill = Paint()..color = Colors.yellowAccent..style = PaintingStyle.fill;
      final handleFill1 = Paint()..color = Colors.orangeAccent..style = PaintingStyle.fill; 
      final handleFill2 = Paint()..color = Colors.blueAccent..style = PaintingStyle.fill;   
      final linePaint = Paint()..color = Colors.blueAccent.withOpacity(0.5)..strokeWidth = 1.0 / cameraZoom;

      if (selectedItem is RectItem || selectedItem is RRectItem || selectedItem is OvalItem) {
        Rect baseRect = Rect.zero;
        if (selectedItem is RectItem) {
          baseRect = selectedItem.rect;
          canvas.drawRect(baseRect, Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = strokeW);
        } else if (selectedItem is RRectItem) {
          baseRect = selectedItem.rect;
          canvas.drawRRect(RRect.fromRectAndRadius(baseRect, Radius.circular(selectedItem.radius)), Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = strokeW);
        } else if (selectedItem is OvalItem) {
          baseRect = selectedItem.rect;
          canvas.drawOval(baseRect, Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = strokeW);
        }
        
        if (hoveredItemId == selectedItem.id) {
          final edgePaint = Paint()..color = Colors.yellowAccent..style = PaintingStyle.stroke..strokeWidth = 3 / cameraZoom;
          if (hoveredHandle == HandleType.topEdge) canvas.drawLine(baseRect.topLeft, baseRect.topRight, edgePaint);
          if (hoveredHandle == HandleType.bottomEdge) canvas.drawLine(baseRect.bottomLeft, baseRect.bottomRight, edgePaint);
          if (hoveredHandle == HandleType.leftEdge) canvas.drawLine(baseRect.topLeft, baseRect.bottomLeft, edgePaint);
          if (hoveredHandle == HandleType.rightEdge) canvas.drawLine(baseRect.topRight, baseRect.bottomRight, edgePaint);
        }

        // Only draw interactive nodes if this is the ONLY item selected
        if (selectedItemIds.length == 1) {
          _drawNode(canvas, baseRect.topLeft, (hoveredItemId == selectedItem.id && hoveredHandle == HandleType.topLeft) ? nodeHoverFill : nodeFill);
          _drawNode(canvas, baseRect.topRight, (hoveredItemId == selectedItem.id && hoveredHandle == HandleType.topRight) ? nodeHoverFill : nodeFill);
          _drawNode(canvas, baseRect.bottomLeft, (hoveredItemId == selectedItem.id && hoveredHandle == HandleType.bottomLeft) ? nodeHoverFill : nodeFill);
          _drawNode(canvas, baseRect.bottomRight, (hoveredItemId == selectedItem.id && hoveredHandle == HandleType.bottomRight) ? nodeHoverFill : nodeFill);
        }
      }
      else if (selectedItem is PathItem) {
        final path = BezierPathData(nodes: selectedItem.nodes, isClosed: selectedItem.isClosed).generatePath();
        canvas.drawPath(path, Paint()..color = Colors.blueAccent.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 3.0 / cameraZoom);
          
        if (selectedItemIds.length == 1) {
          for (int i = 0; i < selectedItem.nodes.length; i++) {
            var node = selectedItem.nodes[i];
            bool isHoveredNode = hoveredItemId == selectedItem.id && hoveredNodeIndex == i;

            if (node.controlPoint1 != null) {
              canvas.drawLine(node.position, node.controlPoint1!, linePaint);
              _drawNode(canvas, node.controlPoint1!, (isHoveredNode && hoveredHandle == HandleType.pathControl1) ? nodeHoverFill : handleFill1, isCircle: true);
            }
            if (node.controlPoint2 != null) {
              canvas.drawLine(node.position, node.controlPoint2!, linePaint);
              _drawNode(canvas, node.controlPoint2!, (isHoveredNode && hoveredHandle == HandleType.pathControl2) ? nodeHoverFill : handleFill2, isCircle: true);
            }
            _drawNode(canvas, node.position, (isHoveredNode && hoveredHandle == HandleType.pathNode) ? nodeHoverFill : nodeFill);
          }
        }
      } 
      else if (selectedItem is LogicGroupItem && selectedItem.children.isNotEmpty) {
        final rect = BoundingBoxUtils.getCombinedRect(selectedItem.children);
        if (rect != Rect.zero) {
          final paddedRect = rect.inflate(8.0 / cameraZoom);
          canvas.drawRect(paddedRect, Paint()..color = Colors.orangeAccent..style = PaintingStyle.stroke..strokeWidth = 2.0 / cameraZoom);

          if (selectedItem.condition != 'true' && selectedItem.condition.trim().isNotEmpty) {
            final textPainter = TextPainter(
              text: TextSpan(text: 'if (${selectedItem.condition})', style: TextStyle(color: Colors.orangeAccent, fontSize: 12 / cameraZoom, fontWeight: FontWeight.bold, backgroundColor: Colors.black54)),
              textDirection: TextDirection.ltr,
            )..layout();
            textPainter.paint(canvas, Offset(paddedRect.left, paddedRect.top - (18.0 / cameraZoom)));
          }
        }
      }
    } catch (e) {
       print('DEBUG ERROR: Selection highlight failed: $e');
    }
  }

  void _drawNode(Canvas canvas, Offset center, Paint paint, {bool isCircle = false}) {
    final radius = 4.0 / cameraZoom;
    if (isCircle) {
      canvas.drawCircle(center, radius, paint);
    } else {
      canvas.drawRect(Rect.fromCenter(center: center, width: radius * 2, height: radius * 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant EditorCanvasPainter oldDelegate) => true;
}