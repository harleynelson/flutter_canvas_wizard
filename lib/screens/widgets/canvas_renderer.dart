// File: lib/screens/widgets/canvas_renderer.dart
// Description: Renders the models applying their Matrix4 transformations, and overlays rotated interactive highlighting elements. Now separates Fill/Stroke to maintain unscaled stroke widths.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../models/canvas_item.dart';
import '../../models/geometry/bezier_path_data.dart';
import '../../utils/bounding_box_utils.dart'; 
import '../../utils/expression_evaluator.dart';
import 'interactive_canvas.dart'; 
import '../../utils/path_math.dart'; 

class EditorCanvasPainter extends CustomPainter {
  final List<CanvasItem> items;
  final Set<String> selectedItemIds;
  final String? hoveredItemId;
  final HandleType hoveredHandle;
  final HandleType activeHandle;
  final Offset? hoverPos;
  final int? hoveredNodeIndex; 
  final double gridSnapSize;
  
  final Offset cameraPan;
  final double cameraZoom;
  final bool isTransformMode;
  final Map<String, double> variables;
  
  final Rect? marqueeRect; 
  final bool isExportMode;

  EditorCanvasPainter({
    required this.items,
    this.selectedItemIds = const {},
    this.hoveredItemId,
    this.hoveredHandle = HandleType.none,
    this.activeHandle = HandleType.none,
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
             _drawTransformBox(canvas, selectedItems); 
          } else {
             for (var item in selectedItems) {
               _drawSelectionHighlight(canvas, item);
             }
          }
        }
        
        if (marqueeRect != null) {
          final paintFill = Paint()..color = Colors.blueAccent.withOpacity(0.2)..style = PaintingStyle.fill;
          final paintStroke = Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 1.0 / cameraZoom;
          canvas.drawRect(marqueeRect!, paintFill);
          canvas.drawRect(marqueeRect!, paintStroke);
        }

        // --- NEW: Draw Rotation Snap Lines ---
        if (activeHandle == HandleType.rotate && selectedItemIds.isNotEmpty) {
           bool isCtrl = HardwareKeyboard.instance.isControlPressed;
           if (!isCtrl) {
              final selectedItems = _findItemsRecursive(items, selectedItemIds);
              final bounds = BoundingBoxUtils.getCombinedRect(selectedItems);
              if (bounds != Rect.zero) {
                  final center = bounds.center;
                  final radius = math.max(bounds.width, bounds.height) + (100.0 / cameraZoom);
                  
                  final snapPaint = Paint()..color = Colors.white.withOpacity(0.15)..style = PaintingStyle.stroke..strokeWidth = 1.0 / cameraZoom;
                  final boldSnapPaint = Paint()..color = Colors.cyanAccent.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 1.0 / cameraZoom;

                  for (int i = 0; i < 24; i++) {
                      double angle = i * (math.pi / 12);
                      Offset endPoint = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
                      // Make major axes slightly more visible
                      canvas.drawLine(center, endPoint, i % 6 == 0 ? boldSnapPaint : snapPaint);
                  }
              }
           }
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
      if (item is LogicGroupItem) {
        canvas.save();
        canvas.transform(item.transform.storage);
        for (var child in item.children) _renderItem(canvas, child, inheritedGhost: isGhost);
        canvas.restore();
        return;
      }

      if (item is RectItem) _drawRectItem(canvas, item, isGhost);
      else if (item is RRectItem) _drawRRectItem(canvas, item, isGhost);
      else if (item is OvalItem) _drawOvalItem(canvas, item, isGhost);
      else if (item is PathItem) _drawPathItem(canvas, item, isGhost);
      else if (item is TextItem) _drawTextItem(canvas, item, isGhost);

    } catch (e) {
      print('DEBUG ERROR: _renderItem failed for ${item.id}: $e');
    }
  }

  void _drawTextItem(Canvas canvas, TextItem item, bool isGhost) {
    try {
      final fillColor = isGhost ? item.paint.fillColor.withOpacity(0.1) : item.paint.fillColor;
      final textStyle = TextStyle(color: fillColor, fontSize: item.fontSize, fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal);

      canvas.save();
      canvas.transform(item.transform.storage);
      if (item.paint.fillColor != Colors.transparent) {
        final textPainter = TextPainter(text: TextSpan(text: item.text, style: textStyle), textDirection: TextDirection.ltr);
        textPainter.layout();
        textPainter.paint(canvas, item.position);
      }
      canvas.restore();

      final sWidth = isGhost ? (item.paint.strokeWidth == 0 ? 1.0 / cameraZoom : item.paint.strokeWidth) : item.paint.strokeWidth;
      if (sWidth > 0 || isGhost) {
        // Inverse scaling stroke so matrix doesn't grow the thickness
        final scaleX = item.transform.getRow(0).xyz.length;
        final scaleY = item.transform.getRow(1).xyz.length;
        final maxScale = math.max(scaleX, scaleY);
        final effectiveStroke = sWidth / (maxScale == 0 ? 1 : maxScale);

        canvas.save();
        canvas.transform(item.transform.storage);
        final strokeColor = isGhost ? Colors.white.withOpacity(0.2) : item.paint.strokeColor;
        final strokeStyle = textStyle.copyWith(foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = effectiveStroke..color = strokeColor);
        final strokePainter = TextPainter(text: TextSpan(text: item.text, style: strokeStyle), textDirection: TextDirection.ltr);
        strokePainter.layout();
        strokePainter.paint(canvas, item.position);
        canvas.restore();
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

      if (item.paint.fillColor != Colors.transparent) {
        canvas.save();
        canvas.transform(item.transform.storage);
        for (int i = item.paint.extrusionSteps; i >= 0; i--) {
          final offset = Offset(item.paint.extrusionOffset.dx * i, item.paint.extrusionOffset.dy * i);
          final rrect = RRect.fromRectAndRadius(item.rect.shift(offset), Radius.circular(item.radius));
          canvas.drawRRect(rrect, paint..color = i == 0 ? fillColor : fillColor.withOpacity(isGhost ? 0.05 : 0.8)..style = PaintingStyle.fill);
        }
        canvas.restore();
      }

      if (sWidth > 0 || isGhost) {
        for (int i = item.paint.extrusionSteps; i >= 0; i--) {
          final offset = Offset(item.paint.extrusionOffset.dx * i, item.paint.extrusionOffset.dy * i);
          final path = Path()..addRRect(RRect.fromRectAndRadius(item.rect.shift(offset), Radius.circular(item.radius)));
          final transformedPath = path.transform(item.transform.storage);
          canvas.drawPath(transformedPath, paint..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = sWidth);
        }
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

      if (item.paint.fillColor != Colors.transparent) {
        canvas.save();
        canvas.transform(item.transform.storage);
        for (int i = item.paint.extrusionSteps; i >= 0; i--) {
          final offset = Offset(item.paint.extrusionOffset.dx * i, item.paint.extrusionOffset.dy * i);
          canvas.drawOval(item.rect.shift(offset), paint..color = i == 0 ? fillColor : fillColor.withOpacity(isGhost ? 0.05 : 0.8)..style = PaintingStyle.fill);
        }
        canvas.restore();
      }

      if (sWidth > 0 || isGhost) {
        for (int i = item.paint.extrusionSteps; i >= 0; i--) {
          final offset = Offset(item.paint.extrusionOffset.dx * i, item.paint.extrusionOffset.dy * i);
          final path = Path()..addOval(item.rect.shift(offset));
          final transformedPath = path.transform(item.transform.storage);
          canvas.drawPath(transformedPath, paint..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = sWidth);
        }
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

      if (item.paint.fillColor != Colors.transparent) {
        canvas.save();
        canvas.transform(item.transform.storage);
        for (int i = item.paint.extrusionSteps; i >= 0; i--) {
          final offset = Offset(item.paint.extrusionOffset.dx * i, item.paint.extrusionOffset.dy * i);
          canvas.drawRect(item.rect.shift(offset), paint..color = i == 0 ? fillColor : fillColor.withOpacity(isGhost ? 0.05 : 0.8)..style = PaintingStyle.fill);
        }
        canvas.restore();
      }

      if (sWidth > 0 || isGhost) {
        for (int i = item.paint.extrusionSteps; i >= 0; i--) {
          final offset = Offset(item.paint.extrusionOffset.dx * i, item.paint.extrusionOffset.dy * i);
          final path = Path()..addRect(item.rect.shift(offset));
          final transformedPath = path.transform(item.transform.storage);
          canvas.drawPath(transformedPath, paint..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = sWidth);
        }
      }
    } catch (e) {
      print('DEBUG ERROR: _drawRectItem failed for ${item.id}: $e');
    }
  }

  void _drawPathItem(Canvas canvas, PathItem item, bool isGhost) {
    try {
      final paint = Paint()..strokeCap = item.paint.strokeCap..blendMode = item.paint.blendMode;
      final localPath = BezierPathData(nodes: item.nodes, isClosed: item.isClosed).generatePath();
      final fillColor = isGhost ? item.paint.fillColor.withOpacity(0.1) : item.paint.fillColor;
      final strokeColor = isGhost ? Colors.white.withOpacity(0.2) : item.paint.strokeColor;
      final sWidth = isGhost ? (item.paint.strokeWidth == 0 ? 1.0 / cameraZoom : item.paint.strokeWidth) : item.paint.strokeWidth;

      if (item.paint.fillColor != Colors.transparent) {
        canvas.save();
        canvas.transform(item.transform.storage);
        canvas.drawPath(localPath, paint..color = fillColor..style = PaintingStyle.fill);
        canvas.restore();
      }

      if (sWidth > 0 || isGhost) {
        final transformedPath = localPath.transform(item.transform.storage);
        canvas.drawPath(transformedPath, paint..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = sWidth);
      }
    } catch (e) {
      print('DEBUG ERROR: _drawPathItem failed for ${item.id}: $e');
    }
  }

  Path _getItemLocalPath(CanvasItem item) {
    if (item is RectItem) return Path()..addRect(item.rect);
    if (item is RRectItem) return Path()..addRRect(RRect.fromRectAndRadius(item.rect, Radius.circular(item.radius)));
    if (item is OvalItem) return Path()..addOval(item.rect);
    if (item is PathItem) return BezierPathData(nodes: item.nodes, isClosed: item.isClosed).generatePath();
    if (item is TextItem) {
       final approxWidth = item.text.length * (item.fontSize * 0.6);
       return Path()..addRect(Rect.fromLTWH(item.position.dx, item.position.dy, approxWidth, item.fontSize * 1.2));
    }
    if (item is LogicGroupItem && item.children.isNotEmpty) return Path()..addRect(BoundingBoxUtils.getCombinedRect(item.children));
    return Path();
  }

  void _drawHoverHighlight(Canvas canvas, CanvasItem item) {
    try {
      final hoverPaint = Paint()..color = Colors.blue.withOpacity(0.7)..style = PaintingStyle.stroke..strokeWidth = 4 / cameraZoom;
      Path localPath = _getItemLocalPath(item);
      Path globalPath = localPath.transform(item.transform.storage);
      canvas.drawPath(globalPath, hoverPaint);
    } catch (e) {
      print('DEBUG ERROR: Hover highlight failed: $e');
    }
  }

  Rect _getItemLocalRect(CanvasItem item) {
    if (item is RectItem) return item.rect;
    if (item is RRectItem) return item.rect;
    if (item is OvalItem) return item.rect;
    if (item is TextItem) return Rect.fromLTWH(item.position.dx, item.position.dy, item.text.length * (item.fontSize * 0.6), item.fontSize * 1.2);
    if (item is LogicGroupItem) return BoundingBoxUtils.getCombinedRect(item.children);
    return Rect.zero;
  }

  void _drawSelectionHighlight(Canvas canvas, CanvasItem selectedItem) {
    try {
      final strokeW = 2.0 / cameraZoom;
      final nodeFill = Paint()..color = Colors.white..style = PaintingStyle.fill;
      final nodeHoverFill = Paint()..color = Colors.yellowAccent..style = PaintingStyle.fill;
      final handleFill1 = Paint()..color = Colors.orangeAccent..style = PaintingStyle.fill; 
      final handleFill2 = Paint()..color = Colors.blueAccent..style = PaintingStyle.fill;   
      final linePaint = Paint()..color = Colors.blueAccent.withOpacity(0.5)..strokeWidth = 1.0 / cameraZoom;

      if (selectedItem is RectItem || selectedItem is RRectItem || selectedItem is OvalItem || selectedItem is TextItem || selectedItem is LogicGroupItem) {
        final localRect = _getItemLocalRect(selectedItem);
        if (localRect == Rect.zero) return;

        final tl = MatrixUtils.transformPoint(selectedItem.transform, localRect.topLeft);
        final tr = MatrixUtils.transformPoint(selectedItem.transform, localRect.topRight);
        final bl = MatrixUtils.transformPoint(selectedItem.transform, localRect.bottomLeft);
        final br = MatrixUtils.transformPoint(selectedItem.transform, localRect.bottomRight);

        final outlinePath = Path()..moveTo(tl.dx, tl.dy)..lineTo(tr.dx, tr.dy)..lineTo(br.dx, br.dy)..lineTo(bl.dx, bl.dy)..close();
        canvas.drawPath(outlinePath, Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = strokeW);

        if (selectedItem is LogicGroupItem && selectedItem.condition != 'true' && selectedItem.condition.trim().isNotEmpty) {
           final textPainter = TextPainter(
              text: TextSpan(text: 'if (${selectedItem.condition})', style: TextStyle(color: Colors.orangeAccent, fontSize: 12 / cameraZoom, fontWeight: FontWeight.bold, backgroundColor: Colors.black54)),
              textDirection: TextDirection.ltr,
            )..layout();
            textPainter.paint(canvas, Offset(tl.dx, tl.dy - (18.0 / cameraZoom)));
        }

        if (hoveredItemId == selectedItem.id) {
          final edgePaint = Paint()..color = Colors.yellowAccent..style = PaintingStyle.stroke..strokeWidth = 3 / cameraZoom;
          if (hoveredHandle == HandleType.topEdge) canvas.drawLine(tl, tr, edgePaint);
          if (hoveredHandle == HandleType.bottomEdge) canvas.drawLine(bl, br, edgePaint);
          if (hoveredHandle == HandleType.leftEdge) canvas.drawLine(tl, bl, edgePaint);
          if (hoveredHandle == HandleType.rightEdge) canvas.drawLine(tr, br, edgePaint);
        }

        if (selectedItemIds.length == 1) {
          _drawNode(canvas, tl, (hoveredItemId == selectedItem.id && hoveredHandle == HandleType.topLeft) ? nodeHoverFill : nodeFill);
          _drawNode(canvas, tr, (hoveredItemId == selectedItem.id && hoveredHandle == HandleType.topRight) ? nodeHoverFill : nodeFill);
          _drawNode(canvas, bl, (hoveredItemId == selectedItem.id && hoveredHandle == HandleType.bottomLeft) ? nodeHoverFill : nodeFill);
          _drawNode(canvas, br, (hoveredItemId == selectedItem.id && hoveredHandle == HandleType.bottomRight) ? nodeHoverFill : nodeFill);
        }
      }
      else if (selectedItem is PathItem) {
        final path = BezierPathData(nodes: selectedItem.nodes, isClosed: selectedItem.isClosed).generatePath();
        canvas.drawPath(path.transform(selectedItem.transform.storage), Paint()..color = Colors.blueAccent.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 3.0 / cameraZoom);
          
        if (hoveredItemId == selectedItem.id && hoveredHandle == HandleType.pathEdge && hoveredNodeIndex != null) {
            int i = hoveredNodeIndex!;
            int nextIndex = (i + 1) % selectedItem.nodes.length;
            
            final start = selectedItem.nodes[i];
            final end = selectedItem.nodes[nextIndex];
            
            final segmentPath = Path()..moveTo(start.position.dx, start.position.dy);
            if (start.controlPoint2 != null && end.controlPoint1 != null) {
               segmentPath.cubicTo(start.controlPoint2!.dx, start.controlPoint2!.dy, end.controlPoint1!.dx, end.controlPoint1!.dy, end.position.dx, end.position.dy);
            } else if (start.controlPoint2 != null || end.controlPoint1 != null) {
               final cp = start.controlPoint2 ?? end.controlPoint1!;
               segmentPath.quadraticBezierTo(cp.dx, cp.dy, end.position.dx, end.position.dy);
            } else {
               segmentPath.lineTo(end.position.dx, end.position.dy);
            }
            
            canvas.drawPath(segmentPath.transform(selectedItem.transform.storage), Paint()..color = Colors.greenAccent..style = PaintingStyle.stroke..strokeWidth = 4.0 / cameraZoom);
            
            if (hoverPos != null) {
               final addPaint = Paint()..color = Colors.greenAccent..style = PaintingStyle.fill;
               canvas.drawCircle(hoverPos!, 7.0 / cameraZoom, addPaint);
               
               final plusStroke = Paint()..color = const Color(0xFF1E1E1E)..style = PaintingStyle.stroke..strokeWidth = 2.0 / cameraZoom..strokeCap = StrokeCap.round;
               canvas.drawLine(hoverPos! + Offset(-3.5/cameraZoom, 0), hoverPos! + Offset(3.5/cameraZoom, 0), plusStroke);
               canvas.drawLine(hoverPos! + Offset(0, -3.5/cameraZoom), hoverPos! + Offset(0, 3.5/cameraZoom), plusStroke);
            }
        }

        if (selectedItemIds.length == 1) {
          for (int i = 0; i < selectedItem.nodes.length; i++) {
            var node = selectedItem.nodes[i];
            bool isHoveredNode = hoveredItemId == selectedItem.id && hoveredNodeIndex == i;

            Offset gPos = MatrixUtils.transformPoint(selectedItem.transform, node.position);

            if (node.controlPoint1 != null) {
              Offset gCp1 = MatrixUtils.transformPoint(selectedItem.transform, node.controlPoint1!);
              canvas.drawLine(gPos, gCp1, linePaint);
              _drawNode(canvas, gCp1, (isHoveredNode && hoveredHandle == HandleType.pathControl1) ? nodeHoverFill : handleFill1, isCircle: true);
            }
            if (node.controlPoint2 != null) {
              Offset gCp2 = MatrixUtils.transformPoint(selectedItem.transform, node.controlPoint2!);
              canvas.drawLine(gPos, gCp2, linePaint);
              _drawNode(canvas, gCp2, (isHoveredNode && hoveredHandle == HandleType.pathControl2) ? nodeHoverFill : handleFill2, isCircle: true);
            }
            _drawNode(canvas, gPos, (isHoveredNode && hoveredHandle == HandleType.pathNode) ? nodeHoverFill : nodeFill);
          }
        }
      } 

      if (selectedItemIds.length == 1) {
         final bounds = BoundingBoxUtils.getCombinedRect([selectedItem]);
         if (bounds != Rect.zero) {
             final moveHandlePos = Offset(bounds.center.dx, bounds.top - (30.0 / cameraZoom));
             final rotateHandlePos = Offset(bounds.center.dx, bounds.top - (60.0 / cameraZoom)); // ROTATE HANDLE

             bool isHoveringMove = hoveredItemId == selectedItem.id && hoveredHandle == HandleType.move;
             bool isHoveringRotate = hoveredItemId == selectedItem.id && hoveredHandle == HandleType.rotate;

             final moveHandlePaint = Paint()..color = isHoveringMove ? Colors.yellowAccent : Colors.white..style = PaintingStyle.fill;
             final rotateHandlePaint = Paint()..color = isHoveringRotate ? Colors.yellowAccent : Colors.white..style = PaintingStyle.fill;
             final stroke = Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 2.0 / cameraZoom;

             // Connecting Line
             canvas.drawLine(Offset(bounds.center.dx, bounds.top), rotateHandlePos, Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 1.5 / cameraZoom);

             // Move Handle
             canvas.drawCircle(moveHandlePos, 10.0 / cameraZoom, moveHandlePaint);
             canvas.drawCircle(moveHandlePos, 10.0 / cameraZoom, stroke);
             final crosshairPaint = Paint()..color = const Color(0xFF1E1E1E)..style = PaintingStyle.stroke..strokeWidth = 1.5 / cameraZoom..strokeCap = StrokeCap.round;
             canvas.drawLine(moveHandlePos + Offset(-5.0 / cameraZoom, 0), moveHandlePos + Offset(5.0 / cameraZoom, 0), crosshairPaint);
             canvas.drawLine(moveHandlePos + Offset(0, -5.0 / cameraZoom), moveHandlePos + Offset(0, 5.0 / cameraZoom), crosshairPaint);
             final arrowOffset = 2.0 / cameraZoom;
             final endOffset = 5.0 / cameraZoom;
             canvas.drawLine(moveHandlePos + Offset(-endOffset, 0), moveHandlePos + Offset(-endOffset + arrowOffset, -arrowOffset), crosshairPaint);
             canvas.drawLine(moveHandlePos + Offset(-endOffset, 0), moveHandlePos + Offset(-endOffset + arrowOffset, arrowOffset), crosshairPaint);
             canvas.drawLine(moveHandlePos + Offset(endOffset, 0), moveHandlePos + Offset(endOffset - arrowOffset, -arrowOffset), crosshairPaint);
             canvas.drawLine(moveHandlePos + Offset(endOffset, 0), moveHandlePos + Offset(endOffset - arrowOffset, arrowOffset), crosshairPaint);
             canvas.drawLine(moveHandlePos + Offset(0, -endOffset), moveHandlePos + Offset(-arrowOffset, -endOffset + arrowOffset), crosshairPaint);
             canvas.drawLine(moveHandlePos + Offset(0, -endOffset), moveHandlePos + Offset(arrowOffset, -endOffset + arrowOffset), crosshairPaint);
             canvas.drawLine(moveHandlePos + Offset(0, endOffset), moveHandlePos + Offset(-arrowOffset, endOffset - arrowOffset), crosshairPaint);
             canvas.drawLine(moveHandlePos + Offset(0, endOffset), moveHandlePos + Offset(arrowOffset, endOffset - arrowOffset), crosshairPaint);

             // Rotate Handle
             canvas.drawCircle(rotateHandlePos, 8.0 / cameraZoom, rotateHandlePaint);
             canvas.drawCircle(rotateHandlePos, 8.0 / cameraZoom, stroke);
             canvas.drawCircle(rotateHandlePos, 3.0 / cameraZoom, Paint()..color = Colors.blueAccent..style = PaintingStyle.fill);
         }
      }

    } catch (e) {
       print('DEBUG ERROR: Selection highlight failed: $e');
    }
  }

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

  void _drawNode(Canvas canvas, Offset center, Paint paint, {bool isCircle = false}) {
    final radius = 4.0 / cameraZoom;
    if (isCircle) {
      canvas.drawCircle(center, radius, paint);
    } else {
      canvas.drawRect(Rect.fromCenter(center: center, width: radius * 2, height: radius * 2), paint);
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

  @override
  bool shouldRepaint(covariant EditorCanvasPainter oldDelegate) => true;
}