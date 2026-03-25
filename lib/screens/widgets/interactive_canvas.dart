// File: lib/screens/widgets/interactive_canvas.dart
// Description: Handles gesture detection, hierarchical matrix-aware hit-testing, marquee selection, and dynamic shape transformations. Added Rotate handling and Shift+Ctrl Stroke Scaling logic.

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/workspace_provider.dart';
import '../../state/history/history_manager.dart';
import '../../state/commands/workspace_commands.dart';
import '../../models/canvas_item.dart';
import '../../models/geometry/bezier_path_data.dart';
import '../../utils/path_math.dart';
import '../../utils/bounding_box_utils.dart';
import '../../utils/transform_utils.dart';
import '../../utils/expression_evaluator.dart';
import 'canvas_renderer.dart';
import 'ui/shortcut_helper_overlay.dart';

enum HandleType { 
  none, move, rotate, 
  topLeft, topEdge, topRight, rightEdge, bottomRight, bottomEdge, bottomLeft, leftEdge,
  pathNode, pathControl1, pathControl2, pathEdge 
}

class HitResult {
  final String? itemId;
  final HandleType handle;
  final int? nodeIndex;
  HitResult({this.itemId, this.handle = HandleType.none, this.nodeIndex});
}

class InteractiveCanvas extends ConsumerStatefulWidget {
  const InteractiveCanvas({super.key});

  @override
  ConsumerState<InteractiveCanvas> createState() => _InteractiveCanvasState();
}

class _InteractiveCanvasState extends ConsumerState<InteractiveCanvas> {
  Offset _cameraPan = Offset.zero;
  double _cameraZoom = 1.0;

  String? _draggingItemId;
  HandleType _activeHandle = HandleType.none;
  Offset? _dragStartLocalPosition;
  
  Map<String, CanvasItem> _dragOriginalItemsState = {}; 
  Map<String, Rect> _dragStartRects = {};
  List<PathNode>? _dragStartNodes; 
  int? _draggingNodeIndex;

  Offset? _marqueeStart;
  Offset? _marqueeEnd;

  String? _hoveredItemId;
  HandleType _hoveredHandle = HandleType.none;
  int? _hoveredNodeIndex;
  Offset? _hoverPos;

  // Active transformation trackers for UI tooltips
  double? _currentRotationAngle;
  double? _currentScaleX;
  double? _currentScaleY;

  bool _hasDragged = false;
  final double _hitTolerance = 12.0;

  Offset _getLogicalPosition(Offset localPosition, Size size) {
    try {
      final double centerX = size.width / 2;
      final double centerY = size.height / 2;
      return Offset(
        (localPosition.dx - centerX - _cameraPan.dx) / _cameraZoom,
        (localPosition.dy - centerY - _cameraPan.dy) / _cameraZoom,
      );
    } catch (e) {
      print('DEBUG ERROR: _getLogicalPosition failed: $e');
      return Offset.zero;
    }
  }

  double _snap(double value, double gridSize) {
    return (value / gridSize).roundToDouble() * gridSize;
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

  CanvasItem _copyWithPaint(CanvasItem item, CanvasPaint newPaint) {
    if (item is RectItem) return RectItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: newPaint, transform: item.transform, rect: item.rect);
    if (item is RRectItem) return RRectItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: newPaint, transform: item.transform, rect: item.rect, radius: item.radius);
    if (item is OvalItem) return OvalItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: newPaint, transform: item.transform, rect: item.rect);
    if (item is PathItem) return PathItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: newPaint, transform: item.transform, nodes: item.nodes, isClosed: item.isClosed);
    if (item is TextItem) return TextItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: newPaint, transform: item.transform, text: item.text, position: item.position, fontSize: item.fontSize, isBold: item.isBold);
    if (item is LogicGroupItem) return LogicGroupItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: newPaint, transform: item.transform, condition: item.condition, children: item.children);
    return item;
  }

  HandleType _getRectHandleHit(Rect rect, Offset pos) {
    try {
      final scaledTolerance = _hitTolerance / _cameraZoom;

      if ((pos - rect.topLeft).distance <= scaledTolerance) return HandleType.topLeft;
      if ((pos - rect.topRight).distance <= scaledTolerance) return HandleType.topRight;
      if ((pos - rect.bottomLeft).distance <= scaledTolerance) return HandleType.bottomLeft;
      if ((pos - rect.bottomRight).distance <= scaledTolerance) return HandleType.bottomRight;

      bool isWithinX = pos.dx >= rect.left && pos.dx <= rect.right;
      bool isWithinY = pos.dy >= rect.top && pos.dy <= rect.bottom;

      if (isWithinX && (pos.dy - rect.top).abs() <= scaledTolerance) return HandleType.topEdge;
      if (isWithinX && (pos.dy - rect.bottom).abs() <= scaledTolerance) return HandleType.bottomEdge;
      if (isWithinY && (pos.dx - rect.left).abs() <= scaledTolerance) return HandleType.leftEdge;
      if (isWithinY && (pos.dx - rect.right).abs() <= scaledTolerance) return HandleType.rightEdge;

      if (rect.contains(pos)) return HandleType.move;
    } catch (e) {
      print('DEBUG ERROR: Rect hit test failed: $e');
    }
    return HandleType.none;
  }

  HandleType _getTransformedRectHandleHit(CanvasItem item, Rect localRect, Offset globalPos) {
    final scaledTolerance = _hitTolerance / _cameraZoom;
    
    final tl = MatrixUtils.transformPoint(item.transform, localRect.topLeft);
    final tr = MatrixUtils.transformPoint(item.transform, localRect.topRight);
    final bl = MatrixUtils.transformPoint(item.transform, localRect.bottomLeft);
    final br = MatrixUtils.transformPoint(item.transform, localRect.bottomRight);

    if ((globalPos - tl).distance <= scaledTolerance) return HandleType.topLeft;
    if ((globalPos - tr).distance <= scaledTolerance) return HandleType.topRight;
    if ((globalPos - bl).distance <= scaledTolerance) return HandleType.bottomLeft;
    if ((globalPos - br).distance <= scaledTolerance) return HandleType.bottomRight;

    double distToSegment(Offset p, Offset a, Offset b) {
      final l2 = (a - b).distanceSquared;
      if (l2 == 0) return (p - a).distance;
      double t = ((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2;
      t = t.clamp(0.0, 1.0);
      final proj = Offset(a.dx + t * (b.dx - a.dx), a.dy + t * (b.dy - a.dy));
      return (p - proj).distance;
    }

    if (distToSegment(globalPos, tl, tr) <= scaledTolerance) return HandleType.topEdge;
    if (distToSegment(globalPos, bl, br) <= scaledTolerance) return HandleType.bottomEdge;
    if (distToSegment(globalPos, tl, bl) <= scaledTolerance) return HandleType.leftEdge;
    if (distToSegment(globalPos, tr, br) <= scaledTolerance) return HandleType.rightEdge;

    return HandleType.none;
  }

  Rect _getItemLocalRect(CanvasItem item) {
    if (item is RectItem) return item.rect;
    if (item is RRectItem) return item.rect;
    if (item is OvalItem) return item.rect;
    if (item is TextItem) return Rect.fromLTWH(item.position.dx, item.position.dy, item.text.length * (item.fontSize * 0.6), item.fontSize * 1.2);
    if (item is LogicGroupItem) return BoundingBoxUtils.getCombinedRect(item.children); 
    return Rect.zero;
  }

  bool _isItemGhosted(CanvasItem item, WorkspaceState workspace) {
    try {
      return !ExpressionEvaluator.evaluate(item.enabledIf, workspace.variables);
    } catch (e) {
      return false;
    }
  }

  HitResult _performHitTest(Offset logicalPos, WorkspaceState workspace) {
    try {
      final scaledTolerance = _hitTolerance / _cameraZoom;

      if (workspace.isTransformMode && workspace.selectedItemIds.isNotEmpty) {
        List<CanvasItem> selectedItems = [];
        void findSelected(List<CanvasItem> items) {
          for (var item in items) {
            if (workspace.selectedItemIds.contains(item.id)) selectedItems.add(item);
            if (item is LogicGroupItem) findSelected(item.children);
          }
        }
        findSelected(workspace.items);
        
        if (selectedItems.isNotEmpty) {
          final boundingBox = BoundingBoxUtils.getCombinedRect(selectedItems);
          if (boundingBox != Rect.zero) {
            final moveHandlePos = Offset(boundingBox.center.dx, boundingBox.top - (30.0 / _cameraZoom));
            final rotateHandlePos = Offset(boundingBox.center.dx, boundingBox.top - (60.0 / _cameraZoom));

            if ((logicalPos - rotateHandlePos).distance <= (12.0 / _cameraZoom)) return HitResult(itemId: selectedItems.first.id, handle: HandleType.rotate);
            if ((logicalPos - moveHandlePos).distance <= (12.0 / _cameraZoom)) return HitResult(itemId: selectedItems.first.id, handle: HandleType.move);

            final handle = _getRectHandleHit(boundingBox.inflate(4.0 / _cameraZoom), logicalPos);
            if (handle != HandleType.none) {
               return HitResult(itemId: selectedItems.first.id, handle: handle);
            }
          }
        }
      }

      if (!workspace.isTransformMode && workspace.selectedItemIds.isNotEmpty) {
        if (workspace.selectedItemIds.length == 1) {
          final selectedItem = _findItemRecursive(workspace.items, workspace.selectedItemIds.first);
          if (selectedItem != null && selectedItem.isVisible && !_isItemGhosted(selectedItem, workspace)) {
            
            final bounds = BoundingBoxUtils.getCombinedRect([selectedItem]);
            if (bounds != Rect.zero) {
               final moveHandlePos = Offset(bounds.center.dx, bounds.top - (30.0 / _cameraZoom));
               final rotateHandlePos = Offset(bounds.center.dx, bounds.top - (60.0 / _cameraZoom));
               if ((logicalPos - rotateHandlePos).distance <= (12.0 / _cameraZoom)) return HitResult(itemId: selectedItem.id, handle: HandleType.rotate);
               if ((logicalPos - moveHandlePos).distance <= (12.0 / _cameraZoom)) return HitResult(itemId: selectedItem.id, handle: HandleType.move);
            }

            if (selectedItem is RectItem || selectedItem is RRectItem || selectedItem is OvalItem || selectedItem is TextItem || selectedItem is LogicGroupItem) {
              final localRect = _getItemLocalRect(selectedItem);
              if (localRect != Rect.zero) {
                final handle = _getTransformedRectHandleHit(selectedItem, localRect, logicalPos);
                if (handle != HandleType.none) return HitResult(itemId: selectedItem.id, handle: handle);
              }
            } 
            else if (selectedItem is PathItem) {
              for (int i = 0; i < selectedItem.nodes.length; i++) {
                final node = selectedItem.nodes[i];
                Offset gPos = MatrixUtils.transformPoint(selectedItem.transform, node.position);
                
                if (node.controlPoint1 != null) {
                   Offset gCp1 = MatrixUtils.transformPoint(selectedItem.transform, node.controlPoint1!);
                   if ((logicalPos - gCp1).distance <= scaledTolerance) return HitResult(itemId: selectedItem.id, handle: HandleType.pathControl1, nodeIndex: i);
                }
                if (node.controlPoint2 != null) {
                   Offset gCp2 = MatrixUtils.transformPoint(selectedItem.transform, node.controlPoint2!);
                   if ((logicalPos - gCp2).distance <= scaledTolerance) return HitResult(itemId: selectedItem.id, handle: HandleType.pathControl2, nodeIndex: i);
                }
                if ((logicalPos - gPos).distance <= scaledTolerance) return HitResult(itemId: selectedItem.id, handle: HandleType.pathNode, nodeIndex: i);
              }
              
              final globalNodes = selectedItem.nodes.map((n) => PathNode(
                position: MatrixUtils.transformPoint(selectedItem.transform, n.position),
                controlPoint1: n.controlPoint1 != null ? MatrixUtils.transformPoint(selectedItem.transform, n.controlPoint1!) : null,
                controlPoint2: n.controlPoint2 != null ? MatrixUtils.transformPoint(selectedItem.transform, n.controlPoint2!) : null,
              )).toList();

              final edgeIndex = PathMath.getHitSegmentIndex(globalNodes, selectedItem.isClosed, logicalPos, scaledTolerance);
              if (edgeIndex != null) return HitResult(itemId: selectedItem.id, handle: HandleType.pathEdge, nodeIndex: edgeIndex);
            }
          }
        }
      }

      HitResult hitTestRecursive(List<CanvasItem> items, Offset globalPos) {
        for (int i = items.length - 1; i >= 0; i--) {
          final item = items[i];
          if (item.isVisible && !_isItemGhosted(item, workspace)) {
            if (item is LogicGroupItem) {
              final childHit = hitTestRecursive(item.children, globalPos);
              if (childHit.itemId != null) return childHit;
            } else {
              final inverse = Matrix4.tryInvert(item.transform) ?? Matrix4.identity();
              final localPos = MatrixUtils.transformPoint(inverse, globalPos);
              final tol = scaledTolerance; 

              bool hit = false;
              bool hasFill = item.paint.fillColor.alpha > 0 || item.paint.fillColorParam != null;
              double effectiveTol = tol + (item.paint.strokeWidth / 2);

              if (item is RectItem || item is RRectItem || item is OvalItem) {
                final rect = item is RectItem ? item.rect : (item is RRectItem ? item.rect : (item as OvalItem).rect);
                
                if (hasFill) {
                   final path = Path();
                   if (item is RectItem) path.addRect(rect.inflate(effectiveTol));
                   else if (item is RRectItem) path.addRRect(RRect.fromRectAndRadius(rect.inflate(effectiveTol), Radius.circular(item.radius + effectiveTol)));
                   else if (item is OvalItem) path.addOval(rect.inflate(effectiveTol));
                   hit = path.contains(localPos);
                } else {
                   final outerPath = Path();
                   if (item is RectItem) outerPath.addRect(rect.inflate(effectiveTol));
                   else if (item is RRectItem) outerPath.addRRect(RRect.fromRectAndRadius(rect.inflate(effectiveTol), Radius.circular(item.radius + effectiveTol)));
                   else if (item is OvalItem) outerPath.addOval(rect.inflate(effectiveTol));
                   
                   if (outerPath.contains(localPos)) {
                      final innerRect = rect.deflate(effectiveTol);
                      if (innerRect.width > 0 && innerRect.height > 0) {
                          final innerPath = Path();
                          if (item is RectItem) innerPath.addRect(innerRect);
                          else if (item is RRectItem) innerPath.addRRect(RRect.fromRectAndRadius(innerRect, Radius.circular(math.max(0, item.radius - effectiveTol))));
                          else if (item is OvalItem) innerPath.addOval(innerRect);
                          hit = !innerPath.contains(localPos);
                      } else {
                          hit = true; 
                      }
                   }
                }
              } else if (item is TextItem) {
                final rect = Rect.fromLTWH(item.position.dx, item.position.dy, item.text.length * (item.fontSize * 0.6), item.fontSize * 1.2);
                hit = rect.contains(localPos);
              } else if (item is PathItem) {
                if (hasFill) {
                  final path = BezierPathData(nodes: item.nodes, isClosed: item.isClosed).generatePath();
                  hit = path.contains(localPos);
                }
                if (!hit) {
                  hit = PathMath.getHitSegmentIndex(item.nodes, item.isClosed, localPos, effectiveTol) != null;
                }
              }

              if (hit) return HitResult(itemId: item.id, handle: HandleType.move);
            }
          }
        }
        return HitResult();
      }

      final baseHit = hitTestRecursive(workspace.items, logicalPos);
      if (baseHit.itemId != null) return baseHit;

    } catch (e) {
      print('DEBUG ERROR: _performHitTest failed: $e');
    }

    return HitResult(); 
  }

  void _clearDragState() {
    setState(() {
      _draggingItemId = null;
      _dragStartLocalPosition = null;
      _dragOriginalItemsState.clear();
      _dragStartRects.clear();
      _dragStartNodes = null;
      _draggingNodeIndex = null;
      _activeHandle = HandleType.none;
      _marqueeStart = null;
      _marqueeEnd = null;
      _currentRotationAngle = null;
      _currentScaleX = null;
      _currentScaleY = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          children: [
            Listener(
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent) {
                  try {
                    setState(() {
                      double zoomDelta = pointerSignal.scrollDelta.dy > 0 ? 0.9 : 1.1;
                      _cameraZoom = (_cameraZoom * zoomDelta).clamp(0.1, 10.0);
                    });
                  } catch (e) {
                    print('DEBUG ERROR: Scroll Zoom failed: $e');
                  }
                }
              },
              onPointerMove: (event) {
                if ((event.buttons & kMiddleMouseButton) != 0) {
                  try {
                    setState(() => _cameraPan += event.delta);
                  } catch (e) {
                    print('DEBUG ERROR: Camera pan failed: $e');
                  }
                }
              },
              child: MouseRegion(
                onHover: (event) {
                  final logicalPos = _getLogicalPosition(event.localPosition, canvasSize);
                  final hit = _performHitTest(logicalPos, workspace);
                  
                  setState(() {
                    _hoveredItemId = hit.itemId;
                    _hoveredHandle = hit.handle;
                    _hoveredNodeIndex = hit.nodeIndex;
                    _hoverPos = logicalPos; 
                  });
                },
                onExit: (_) {
                  setState(() {
                    _hoveredItemId = null;
                    _hoveredHandle = HandleType.none;
                    _hoveredNodeIndex = null;
                    _hoverPos = null;
                  });
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, 
                  dragStartBehavior: DragStartBehavior.down, 
                  onSecondaryTapDown: (details) {
                    final logicalPos = _getLogicalPosition(details.localPosition, canvasSize);
                    final hit = _performHitTest(logicalPos, workspace);

                    if (hit.itemId != null && hit.handle == HandleType.pathNode && hit.nodeIndex != null) {
                      final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                      final position = RelativeRect.fromRect(
                        details.globalPosition & const Size(40, 40),
                        Offset.zero & overlay.size,
                      );

                      showMenu(
                        context: context,
                        position: position,
                        color: const Color(0xFF2D2D30),
                        elevation: 8,
                        items: [
                          const PopupMenuItem(
                            value: 'delete_node',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                SizedBox(width: 8),
                                Text('Delete Node', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ).then((value) {
                        if (value == 'delete_node') {
                          try {
                            final item = _findItemRecursive(workspace.items, hit.itemId);
                            if (item is PathItem && item.nodes.length > 1) {
                              final newNodes = List<PathNode>.from(item.nodes)..removeAt(hit.nodeIndex!);
                              final updatedItem = PathItem(
                                id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, 
                                paint: item.paint, transform: item.transform, nodes: newNodes, isClosed: item.isClosed
                              );
                              ref.read(historyProvider.notifier).execute(
                                UpdateCommand(item, updatedItem, ref.read(workspaceProvider.notifier))
                              );
                            }
                          } catch (e) {
                            print('DEBUG ERROR: Delete node from context menu failed: $e');
                          }
                        }
                      });
                    }
                  },
                  onPanDown: (details) {
                    try {
                      _hasDragged = false;
                      final logicalPos = _getLogicalPosition(details.localPosition, canvasSize);
                      final hit = _performHitTest(logicalPos, workspace);
                      final isMultiSelectKey = HardwareKeyboard.instance.isShiftPressed || HardwareKeyboard.instance.isControlPressed;

                      if (hit.itemId == null) {
                        if (!isMultiSelectKey) ref.read(workspaceProvider.notifier).selectItem(null);
                        setState(() {
                          _marqueeStart = logicalPos;
                          _marqueeEnd = logicalPos;
                          _draggingItemId = null;
                          _activeHandle = HandleType.none;
                          _currentRotationAngle = null;
                          _currentScaleX = null;
                          _currentScaleY = null;
                        });
                      } else {
                        if (!workspace.selectedItemIds.contains(hit.itemId)) {
                           ref.read(workspaceProvider.notifier).selectItem(hit.itemId, multi: isMultiSelectKey);
                        }

                        _dragStartLocalPosition = logicalPos;
                        _draggingItemId = hit.itemId;
                        _activeHandle = hit.handle;
                        _draggingNodeIndex = hit.nodeIndex;
                        _dragOriginalItemsState.clear();
                        _dragStartRects.clear();
                        _currentRotationAngle = null;
                        _currentScaleX = null;
                        _currentScaleY = null;
                        
                        final selectedItems = ref.read(workspaceProvider.notifier).selectedItems;

                        if (workspace.isTransformMode && selectedItems.isNotEmpty) {
                           _dragStartRects['__combined__'] = BoundingBoxUtils.getCombinedRect(selectedItems);
                        }

                        for (var item in selectedItems) {
                          _dragOriginalItemsState[item.id] = item;
                          _dragStartRects[item.id] = _getItemLocalRect(item);
                          
                          if (item.id == hit.itemId && item is PathItem) {
                            _dragStartNodes = item.nodes.map((n) => PathNode(
                              position: n.position, controlPoint1: n.controlPoint1, controlPoint2: n.controlPoint2,
                            )).toList();
                          }
                        }
                      }
                    } catch (e) {
                      print('DEBUG ERROR: onPanDown initialization failed: $e');
                    }
                  },
                  onPanUpdate: (details) {
                    try {
                      if (details.delta.distance > 0) _hasDragged = true;
                      final logicalPos = _getLogicalPosition(details.localPosition, canvasSize);
                      
                      // Keep track of cursor position during drag for HUD rendering
                      setState(() { _hoverPos = logicalPos; });

                      if (_marqueeStart != null) {
                        setState(() => _marqueeEnd = logicalPos);
                        final marqueeRect = Rect.fromPoints(_marqueeStart!, _marqueeEnd!);
                        final Set<String> itemsInMarquee = {};
                        
                        void checkIntersection(List<CanvasItem> items) {
                          for (var item in items) {
                             if (!item.isVisible || _isItemGhosted(item, workspace)) continue;
                             final bounds = BoundingBoxUtils.getCombinedRect([item]);
                             if (marqueeRect.overlaps(bounds)) itemsInMarquee.add(item.id);
                             if (item is LogicGroupItem) checkIntersection(item.children);
                          }
                        }
                        checkIntersection(workspace.items);
                        ref.read(workspaceProvider.notifier).selectItems(itemsInMarquee);
                        return;
                      }

                      if (_draggingItemId == null || _dragStartLocalPosition == null) return;
                      final delta = logicalPos - _dragStartLocalPosition!;
                      final selectedItems = ref.read(workspaceProvider.notifier).selectedItems;
                      if (selectedItems.isEmpty) return;
                      bool isShiftCtrl = HardwareKeyboard.instance.isShiftPressed && HardwareKeyboard.instance.isControlPressed;

                      // Rotate Execution
                      if (_activeHandle == HandleType.rotate) {
                        bool isCtrl = HardwareKeyboard.instance.isControlPressed;
                        for (var item in selectedItems) {
                           final original = _dragOriginalItemsState[item.id];
                           if (original == null) continue;
                           final combinedRect = _dragStartRects['__combined__'] ?? BoundingBoxUtils.getCombinedRect([original]);
                           final center = combinedRect.center;
                           final startVec = _dragStartLocalPosition! - center;
                           final currentVec = logicalPos - center;
                           
                           double rawAngleDelta = math.atan2(currentVec.dy, currentVec.dx) - math.atan2(startVec.dy, startVec.dx);
                           double angleDelta = rawAngleDelta;
                           
                           if (!isCtrl) {
                              double snapAngle = math.pi / 12; // 15 degrees
                              angleDelta = (rawAngleDelta / snapAngle).round() * snapAngle;
                           }

                           setState(() { _currentRotationAngle = angleDelta; });

                           final rotatedItem = TransformUtils.rotateItem(original, angleDelta, center);
                           ref.read(workspaceProvider.notifier).updateItem(rotatedItem);
                        }
                        return;
                      }

                      // Multi-Item Transform
                      if (workspace.isTransformMode) {
                         final combinedRect = _dragStartRects['__combined__'];
                         if (combinedRect == null) return;

                         double left = combinedRect.left;
                         double top = combinedRect.top;
                         double right = combinedRect.right;
                         double bottom = combinedRect.bottom;

                         switch (_activeHandle) {
                            case HandleType.topLeft: left += delta.dx; top += delta.dy; break;
                            case HandleType.topEdge: top += delta.dy; break;
                            case HandleType.topRight: right += delta.dx; top += delta.dy; break;
                            case HandleType.rightEdge: right += delta.dx; break;
                            case HandleType.bottomRight: right += delta.dx; bottom += delta.dy; break;
                            case HandleType.bottomEdge: bottom += delta.dy; break;
                            case HandleType.bottomLeft: left += delta.dx; bottom += delta.dy; break;
                            case HandleType.leftEdge: left += delta.dx; break;
                            case HandleType.move:
                              left += delta.dx; top += delta.dy;
                              right += delta.dx; bottom += delta.dy;
                              break;
                            default: break;
                         }

                         if (workspace.snapToGrid) {
                            if (_activeHandle != HandleType.move) {
                              if (_activeHandle.name.toLowerCase().contains('left')) left = _snap(left, workspace.gridSnapSize);
                              if (_activeHandle.name.toLowerCase().contains('top')) top = _snap(top, workspace.gridSnapSize);
                              if (_activeHandle.name.toLowerCase().contains('right')) right = _snap(right, workspace.gridSnapSize);
                              if (_activeHandle.name.toLowerCase().contains('bottom')) bottom = _snap(bottom, workspace.gridSnapSize);
                            } else {
                              final snapLeft = _snap(left, workspace.gridSnapSize);
                              final snapTop = _snap(top, workspace.gridSnapSize);
                              final width = right - left;
                              final height = bottom - top;
                              left = snapLeft; top = snapTop;
                              right = left + width; bottom = top + height;
                            }
                         }

                         for (var item in selectedItems) {
                           final original = _dragOriginalItemsState[item.id];
                           if (original == null) continue;

                           if (_activeHandle == HandleType.move) {
                              final moveDelta = Offset(left, top) - combinedRect.topLeft;
                              final movedItem = TransformUtils.translateItem(original, moveDelta); 
                              ref.read(workspaceProvider.notifier).updateItem(movedItem);
                           } else {
                              double origWidth = combinedRect.width == 0 ? 1 : combinedRect.width;
                              double origHeight = combinedRect.height == 0 ? 1 : combinedRect.height;
                              double scaleX = (right - left) / origWidth;
                              double scaleY = (bottom - top) / origHeight;

                              if (HardwareKeyboard.instance.isShiftPressed) {
                                double maxScale = math.max(scaleX.abs(), scaleY.abs());
                                scaleX = scaleX < 0 ? -maxScale : maxScale;
                                scaleY = scaleY < 0 ? -maxScale : maxScale;
                              }
                              
                              setState(() {
                                _currentScaleX = scaleX;
                                _currentScaleY = scaleY;
                              });

                              Offset origin = combinedRect.center;
                              if (_activeHandle == HandleType.topLeft) origin = combinedRect.bottomRight;
                              else if (_activeHandle == HandleType.topRight) origin = combinedRect.bottomLeft;
                              else if (_activeHandle == HandleType.bottomLeft) origin = combinedRect.topRight;
                              else if (_activeHandle == HandleType.bottomRight) origin = combinedRect.topLeft;
                              else if (_activeHandle == HandleType.topEdge) origin = Offset(combinedRect.center.dx, combinedRect.bottom);
                              else if (_activeHandle == HandleType.bottomEdge) origin = Offset(combinedRect.center.dx, combinedRect.top);
                              else if (_activeHandle == HandleType.leftEdge) origin = Offset(combinedRect.right, combinedRect.center.dy);
                              else if (_activeHandle == HandleType.rightEdge) origin = Offset(combinedRect.left, combinedRect.center.dy);

                              final stretchedItem = TransformUtils.stretchItem(original, scaleX, scaleY, origin);
                              
                              if (isShiftCtrl) {
                                double maxScale = math.max(scaleX.abs(), scaleY.abs());
                                final newStroke = original.paint.strokeWidth * maxScale;
                                final newPaint = stretchedItem.paint.copyWith(strokeWidth: newStroke);
                                ref.read(workspaceProvider.notifier).updateItem(_copyWithPaint(stretchedItem, newPaint));
                              } else {
                                ref.read(workspaceProvider.notifier).updateItem(stretchedItem);
                              }
                           }
                         }
                         return;
                      }

                      if (selectedItems.length > 1 && _activeHandle == HandleType.move) {
                         Offset finalDelta = delta;
                         if (workspace.snapToGrid) {
                             final firstOriginal = _dragOriginalItemsState[selectedItems.first.id];
                             if (firstOriginal != null) {
                                 final bounds = BoundingBoxUtils.getCombinedRect([firstOriginal]);
                                 final startPos = bounds.topLeft;
                                 final targetPos = startPos + delta;
                                 final snappedPos = Offset(_snap(targetPos.dx, workspace.gridSnapSize), _snap(targetPos.dy, workspace.gridSnapSize));
                                 finalDelta = snappedPos - startPos;
                             }
                         }

                         for (var item in selectedItems) {
                            final original = _dragOriginalItemsState[item.id];
                            if (original == null) continue;
                            final movedItem = TransformUtils.translateItem(original, finalDelta); 
                            ref.read(workspaceProvider.notifier).updateItem(movedItem);
                         }
                         return;
                      }

                      if (selectedItems.length == 1) {
                         final item = selectedItems.first;
                         final itemRect = _dragStartRects[item.id];
                         final inverse = Matrix4.tryInvert(item.transform) ?? Matrix4.identity();
                         
                         Offset globalTarget = _dragStartLocalPosition! + delta;
                         
                         Offset localStart = MatrixUtils.transformPoint(inverse, _dragStartLocalPosition!);
                         Offset localTarget = MatrixUtils.transformPoint(inverse, globalTarget);
                         Offset localDelta = localTarget - localStart;

                         if (_activeHandle == HandleType.move) {
                            Offset finalDelta = delta;
                            if (workspace.snapToGrid) {
                                final originalItem = _dragOriginalItemsState[item.id]!;
                                final bounds = BoundingBoxUtils.getCombinedRect([originalItem]);
                                final startPos = bounds.topLeft;
                                final targetPos = startPos + delta;
                                final snappedPos = Offset(_snap(targetPos.dx, workspace.gridSnapSize), _snap(targetPos.dy, workspace.gridSnapSize));
                                finalDelta = snappedPos - startPos;
                            }
                            final movedItem = TransformUtils.translateItem(_dragOriginalItemsState[item.id]!, finalDelta); 
                            ref.read(workspaceProvider.notifier).updateItem(movedItem);
                            return;
                         }

                         if ((item is RectItem || item is RRectItem || item is OvalItem) && itemRect != null) {
                             double left = itemRect.left;
                             double top = itemRect.top;
                             double right = itemRect.right;
                             double bottom = itemRect.bottom;
                   
                             switch (_activeHandle) {
                               case HandleType.topLeft: left += localDelta.dx; top += localDelta.dy; break;
                               case HandleType.topEdge: top += localDelta.dy; break;
                               case HandleType.topRight: right += localDelta.dx; top += localDelta.dy; break;
                               case HandleType.rightEdge: right += localDelta.dx; break;
                               case HandleType.bottomRight: right += localDelta.dx; bottom += localDelta.dy; break;
                               case HandleType.bottomEdge: bottom += localDelta.dy; break;
                               case HandleType.bottomLeft: left += localDelta.dx; bottom += localDelta.dy; break;
                               case HandleType.leftEdge: left += localDelta.dx; break;
                               default: break;
                             }

                             if (workspace.snapToGrid) {
                                 Offset snapLocalPointToGlobalGrid(Offset localPoint) {
                                     Offset globalP = MatrixUtils.transformPoint(item.transform, localPoint);
                                     Offset snappedGlobal = Offset(_snap(globalP.dx, workspace.gridSnapSize), _snap(globalP.dy, workspace.gridSnapSize));
                                     return MatrixUtils.transformPoint(inverse, snappedGlobal);
                                 }

                                 if (_activeHandle == HandleType.leftEdge) left = snapLocalPointToGlobalGrid(Offset(left, itemRect.center.dy)).dx;
                                 if (_activeHandle == HandleType.rightEdge) right = snapLocalPointToGlobalGrid(Offset(right, itemRect.center.dy)).dx;
                                 if (_activeHandle == HandleType.topEdge) top = snapLocalPointToGlobalGrid(Offset(itemRect.center.dx, top)).dy;
                                 if (_activeHandle == HandleType.bottomEdge) bottom = snapLocalPointToGlobalGrid(Offset(itemRect.center.dx, bottom)).dy;
                                 
                                 if (_activeHandle == HandleType.topLeft) {
                                     var p = snapLocalPointToGlobalGrid(Offset(left, top));
                                     left = p.dx; top = p.dy;
                                 }
                                 if (_activeHandle == HandleType.topRight) {
                                     var p = snapLocalPointToGlobalGrid(Offset(right, top));
                                     right = p.dx; top = p.dy;
                                 }
                                 if (_activeHandle == HandleType.bottomLeft) {
                                     var p = snapLocalPointToGlobalGrid(Offset(left, bottom));
                                     left = p.dx; bottom = p.dy;
                                 }
                                 if (_activeHandle == HandleType.bottomRight) {
                                     var p = snapLocalPointToGlobalGrid(Offset(right, bottom));
                                     right = p.dx; bottom = p.dy;
                                 }
                             }

                             double origWidth = itemRect.width == 0 ? 1 : itemRect.width;
                             double origHeight = itemRect.height == 0 ? 1 : itemRect.height;

                             // Single-item Proportional Scale Override
                             bool isCorner = _activeHandle == HandleType.topLeft || _activeHandle == HandleType.topRight || _activeHandle == HandleType.bottomLeft || _activeHandle == HandleType.bottomRight;
                             if (HardwareKeyboard.instance.isShiftPressed && isCorner) {
                                 double scaleX = (right - left) / origWidth;
                                 double scaleY = (bottom - top) / origHeight;
                                 double maxScale = math.max(scaleX.abs(), scaleY.abs());
                                 
                                 // Preserve sign orientation
                                 scaleX = scaleX < 0 ? -maxScale : maxScale;
                                 scaleY = scaleY < 0 ? -maxScale : maxScale;

                                 if (_activeHandle == HandleType.topLeft) { 
                                     left = right - (origWidth * scaleX); 
                                     top = bottom - (origHeight * scaleY); 
                                 } else if (_activeHandle == HandleType.topRight) { 
                                     right = left + (origWidth * scaleX); 
                                     top = bottom - (origHeight * scaleY); 
                                 } else if (_activeHandle == HandleType.bottomLeft) { 
                                     left = right - (origWidth * scaleX); 
                                     bottom = top + (origHeight * scaleY); 
                                 } else if (_activeHandle == HandleType.bottomRight) { 
                                     right = left + (origWidth * scaleX); 
                                     bottom = top + (origHeight * scaleY); 
                                 }
                             }

                             // Calculate UI Tooltip scales based on final bounds
                             setState(() {
                               _currentScaleX = (right - left).abs() / origWidth;
                               _currentScaleY = (bottom - top).abs() / origHeight;
                             });
                   
                             final newRect = Rect.fromLTRB(
                               left < right ? left : right, top < bottom ? top : bottom,
                               left < right ? right : left, top < bottom ? bottom : top,
                             );

                             CanvasPaint currentPaint = item.paint;
                             if (isShiftCtrl && _activeHandle != HandleType.move) {
                                double changedWidth = (right - left).abs();
                                double scale = changedWidth / origWidth;
                                final newStroke = _dragOriginalItemsState[item.id]!.paint.strokeWidth * scale;
                                currentPaint = item.paint.copyWith(strokeWidth: newStroke);
                             }
                             
                             if (item is RectItem) ref.read(workspaceProvider.notifier).updateItem(RectItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: currentPaint, transform: item.transform, rect: newRect));
                             else if (item is RRectItem) ref.read(workspaceProvider.notifier).updateItem(RRectItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: currentPaint, transform: item.transform, rect: newRect, radius: item.radius));
                             else if (item is OvalItem) ref.read(workspaceProvider.notifier).updateItem(OvalItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: currentPaint, transform: item.transform, rect: newRect));
                         }
                         else if (item is PathItem && _dragStartNodes != null && _draggingNodeIndex != null) {
                            List<PathNode> newNodes = _dragStartNodes!.map((n) => PathNode(position: n.position, controlPoint1: n.controlPoint1, controlPoint2: n.controlPoint2)).toList();
                            final i = _draggingNodeIndex!;
                              
                            Offset snapLocalPointToGlobalGrid(Offset localPoint) {
                                Offset globalP = MatrixUtils.transformPoint(item.transform, localPoint);
                                Offset snappedGlobal = Offset(_snap(globalP.dx, workspace.gridSnapSize), _snap(globalP.dy, workspace.gridSnapSize));
                                return MatrixUtils.transformPoint(inverse, snappedGlobal);
                            }

                            if (_activeHandle == HandleType.pathEdge) {
                              int nextIndex = (i + 1) % newNodes.length;
                              Offset targetPos1 = _dragStartNodes![i].position + localDelta;
                              Offset finalLocalDelta = localDelta;

                              if (workspace.snapToGrid) {
                                  Offset snappedPos1 = snapLocalPointToGlobalGrid(targetPos1);
                                  finalLocalDelta = snappedPos1 - _dragStartNodes![i].position;
                              }

                              void applyDelta(int idx) {
                                newNodes[idx].position = _dragStartNodes![idx].position + finalLocalDelta;
                                if (newNodes[idx].controlPoint1 != null) newNodes[idx].controlPoint1 = _dragStartNodes![idx].controlPoint1! + finalLocalDelta;
                                if (newNodes[idx].controlPoint2 != null) newNodes[idx].controlPoint2 = _dragStartNodes![idx].controlPoint2! + finalLocalDelta;
                              }
                              applyDelta(i); 
                              applyDelta(nextIndex);
                            } 
                            else if (_activeHandle == HandleType.pathNode) {
                              var newPos = _dragStartNodes![i].position + localDelta;
                              Offset snappedDelta = localDelta;
                              
                              if (workspace.snapToGrid) {
                                  newPos = snapLocalPointToGlobalGrid(newPos);
                                  snappedDelta = newPos - _dragStartNodes![i].position;
                              }
                              
                              bool snappedToClose = false;
                              if (!item.isClosed && (i == 0 || i == newNodes.length - 1) && newNodes.length > 2) {
                                 int otherIndex = (i == 0) ? newNodes.length - 1 : 0;
                                 Offset gPos = MatrixUtils.transformPoint(item.transform, newPos);
                                 Offset gOther = MatrixUtils.transformPoint(item.transform, _dragStartNodes![otherIndex].position);
                                 if ((gPos - gOther).distance <= (_hitTolerance / _cameraZoom) * 2) {
                                     newPos = _dragStartNodes![otherIndex].position;
                                     snappedToClose = true;
                                 }
                              }
                              newNodes[i].position = newPos;
                              if (newNodes[i].controlPoint1 != null) newNodes[i].controlPoint1 = _dragStartNodes![i].controlPoint1! + snappedDelta;
                              if (newNodes[i].controlPoint2 != null) newNodes[i].controlPoint2 = _dragStartNodes![i].controlPoint2! + snappedDelta;
                            }
                            else if (_activeHandle == HandleType.pathControl1 && _dragStartNodes![i].controlPoint1 != null) {
                              var newPos = _dragStartNodes![i].controlPoint1! + localDelta;
                              if (workspace.snapToGrid) newPos = snapLocalPointToGlobalGrid(newPos);
                              newNodes[i].controlPoint1 = newPos;
                            }
                            else if (_activeHandle == HandleType.pathControl2 && _dragStartNodes![i].controlPoint2 != null) {
                              var newPos = _dragStartNodes![i].controlPoint2! + localDelta;
                              if (workspace.snapToGrid) newPos = snapLocalPointToGlobalGrid(newPos);
                              newNodes[i].controlPoint2 = newPos;
                            } 
                  
                            ref.read(workspaceProvider.notifier).updateItem(PathItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, transform: item.transform, nodes: newNodes, isClosed: item.isClosed));
                         }
                      }

                    } catch (e) {
                      print('DEBUG ERROR: onPanUpdate failed: $e');
                    }
                  },
                  onPanEnd: (details) async {
                    try {
                      if (_marqueeStart != null) {
                        setState(() { _marqueeStart = null; _marqueeEnd = null; });
                        return;
                      }

                      if (!_hasDragged && workspace.selectedItemIds.length == 1) {
                        if (_draggingItemId != null && _activeHandle == HandleType.pathEdge && _draggingNodeIndex != null) {
                          final item = _findItemRecursive(workspace.items, _draggingItemId);
                          if (item is PathItem && _dragStartLocalPosition != null) {
                            final inverse = Matrix4.tryInvert(item.transform) ?? Matrix4.identity();
                            var globalPos = _dragStartLocalPosition!;
                            if (workspace.snapToGrid) globalPos = Offset(_snap(globalPos.dx, workspace.gridSnapSize), _snap(globalPos.dy, workspace.gridSnapSize));
                            var newPos = MatrixUtils.transformPoint(inverse, globalPos);
                            
                            final newNodes = List<PathNode>.from(item.nodes);
                            final int i = _draggingNodeIndex!;
                            final startNode = item.nodes[i];
                            final endNode = item.nodes[(i + 1) % item.nodes.length];
                            final bool isCurve = startNode.controlPoint2 != null || endNode.controlPoint1 != null;
                            Offset? newCp1, newCp2;
                            if (isCurve) {
                              newCp1 = newPos + ((startNode.position - newPos) * 0.25);
                              newCp2 = newPos + ((endNode.position - newPos) * 0.25);
                            }
                            newNodes.insert(i + 1, PathNode(position: newPos, controlPoint1: newCp1, controlPoint2: newCp2));
                            final updatedItem = PathItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, transform: item.transform, nodes: newNodes, isClosed: item.isClosed);
                            ref.read(historyProvider.notifier).execute(UpdateCommand(item, updatedItem, ref.read(workspaceProvider.notifier)));
                          }
                        }
                      } else if (_hasDragged) {
                        final selectedItems = ref.read(workspaceProvider.notifier).selectedItems;

                        if (selectedItems.length == 1) {
                            final item = selectedItems.first;
                            final original = _dragOriginalItemsState[item.id];
                            if (original is PathItem && _activeHandle == HandleType.pathNode && _draggingNodeIndex != null) {
                              if (item is PathItem && !item.isClosed && item.nodes.length > 2) {
                                final int i = _draggingNodeIndex!;
                                final int otherIndex = (i == 0) ? item.nodes.length - 1 : 0;
                                Offset gPos = MatrixUtils.transformPoint(item.transform, item.nodes[i].position);
                                Offset gOther = MatrixUtils.transformPoint(item.transform, item.nodes[otherIndex].position);
                                
                                if ((gPos - gOther).distance <= (_hitTolerance / _cameraZoom) * 2) {
                                  final newNodes = List<PathNode>.from(item.nodes);
                                  if (i == item.nodes.length - 1) {
                                    final draggedNode = newNodes.removeLast();
                                    if (draggedNode.controlPoint1 != null) newNodes[0] = PathNode(position: newNodes[0].position, controlPoint1: draggedNode.controlPoint1, controlPoint2: newNodes[0].controlPoint2);
                                  } else {
                                    final draggedNode = newNodes.removeAt(0);
                                    if (draggedNode.controlPoint2 != null) newNodes.last = PathNode(position: newNodes.last.position, controlPoint1: newNodes.last.controlPoint1, controlPoint2: draggedNode.controlPoint2);
                                  }
                                  final updatedItem = PathItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, transform: item.transform, nodes: newNodes, isClosed: true);
                                  ref.read(workspaceProvider.notifier).updateItem(updatedItem);
                                  ref.read(historyProvider.notifier).execute(UpdateCommand(original, updatedItem, ref.read(workspaceProvider.notifier)));
                                  _clearDragState();
                                  return;
                                }
                              }
                            }
                        }

                        for (var item in selectedItems) {
                            final original = _dragOriginalItemsState[item.id];
                            if (original != null && original != item) {
                              ref.read(historyProvider.notifier).execute(UpdateCommand(original, item, ref.read(workspaceProvider.notifier)));
                            }
                        }
                      }
                    } catch (e) {
                      print('DEBUG ERROR: onPanEnd commit failed: $e');
                    }
                    _clearDragState();
                  },
                  onPanCancel: () => _clearDragState(),
                  child: CustomPaint(
                    painter: EditorCanvasPainter(
                      items: workspace.items,
                      selectedItemIds: workspace.selectedItemIds,
                      hoveredItemId: _hoveredItemId,
                      hoveredHandle: _hoveredHandle,
                      activeHandle: _activeHandle,
                      hoverPos: _hoverPos,
                      hoveredNodeIndex: _hoveredNodeIndex,
                      gridSnapSize: workspace.gridSnapSize,
                      cameraPan: _cameraPan,
                      cameraZoom: _cameraZoom,
                      isTransformMode: workspace.isTransformMode,
                      variables: workspace.variables, 
                      marqueeRect: _marqueeStart != null && _marqueeEnd != null ? Rect.fromPoints(_marqueeStart!, _marqueeEnd!) : null,
                      currentRotationAngle: _currentRotationAngle,
                      currentScaleX: _currentScaleX,
                      currentScaleY: _currentScaleY,
                    ),
                    size: canvasSize,
                  ),
                ),
              ),
            ),
            
            ShortcutHelperOverlay(
              selectedCount: workspace.selectedItemIds.length,
              isTransformMode: workspace.isTransformMode,
            ),
          ],
        );
      }
    );
  }
}