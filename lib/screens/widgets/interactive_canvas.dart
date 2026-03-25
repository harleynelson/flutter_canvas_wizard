// File: lib/screens/widgets/interactive_canvas.dart
// Description: Handles gesture detection, hover states, hierarchical hit-testing, marquee selection, and dynamic shape transformations. Supports multi-selection dragging.

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

enum HandleType { 
  none, move, 
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
  
  // Multi-Selection Drag Maps
  Map<String, CanvasItem> _dragOriginalItemsState = {}; 
  Map<String, Rect> _dragStartRects = {};
  List<PathNode>? _dragStartNodes; // Kept single for specific path editing
  int? _draggingNodeIndex;

  // Marquee Selection
  Offset? _marqueeStart;
  Offset? _marqueeEnd;

  String? _hoveredItemId;
  HandleType _hoveredHandle = HandleType.none;
  int? _hoveredNodeIndex;
  Offset? _hoverPos;

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

      // Transform Mode: Combined Bounding Box Hit Test
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
            final handle = _getRectHandleHit(boundingBox.inflate(4.0 / _cameraZoom), logicalPos);
            if (handle != HandleType.none) {
               return HitResult(itemId: selectedItems.first.id, handle: handle);
            }
          }
        }
      }

      // Normal Mode: Individual Item Hit Test
      if (!workspace.isTransformMode && workspace.selectedItemIds.isNotEmpty) {
        if (workspace.selectedItemIds.length == 1) {
          final selectedItem = _findItemRecursive(workspace.items, workspace.selectedItemIds.first);
          if (selectedItem != null && selectedItem.isVisible && !_isItemGhosted(selectedItem, workspace)) {
            if (selectedItem is RectItem || selectedItem is RRectItem || selectedItem is OvalItem) {
              final rect = selectedItem is RectItem ? selectedItem.rect : (selectedItem is RRectItem ? selectedItem.rect : (selectedItem as OvalItem).rect);
              final handle = _getRectHandleHit(rect, logicalPos);
              if (handle != HandleType.none) return HitResult(itemId: selectedItem.id, handle: handle);
            } else if (selectedItem is TextItem) {
              final rect = BoundingBoxUtils.getCombinedRect([selectedItem]);
              final handle = _getRectHandleHit(rect, logicalPos);
              if (handle != HandleType.none) return HitResult(itemId: selectedItem.id, handle: handle);
            } else if (selectedItem is PathItem) {
              for (int i = 0; i < selectedItem.nodes.length; i++) {
                final node = selectedItem.nodes[i];
                if (node.controlPoint1 != null && (logicalPos - node.controlPoint1!).distance <= scaledTolerance) return HitResult(itemId: selectedItem.id, handle: HandleType.pathControl1, nodeIndex: i);
                if (node.controlPoint2 != null && (logicalPos - node.controlPoint2!).distance <= scaledTolerance) return HitResult(itemId: selectedItem.id, handle: HandleType.pathControl2, nodeIndex: i);
                if ((logicalPos - node.position).distance <= scaledTolerance) return HitResult(itemId: selectedItem.id, handle: HandleType.pathNode, nodeIndex: i);
              }
              final edgeIndex = PathMath.getHitSegmentIndex(selectedItem.nodes, selectedItem.isClosed, logicalPos, scaledTolerance);
              if (edgeIndex != null) return HitResult(itemId: selectedItem.id, handle: HandleType.pathEdge, nodeIndex: edgeIndex);

              final path = BezierPathData(nodes: selectedItem.nodes, isClosed: selectedItem.isClosed).generatePath();
              if (path.contains(logicalPos)) return HitResult(itemId: selectedItem.id, handle: HandleType.move);
            }
          }
        }
      }

      // Base Canvas Hit Test
      HitResult hitTestRecursive(List<CanvasItem> items, Offset pos) {
        for (int i = items.length - 1; i >= 0; i--) {
          final item = items[i];
          if (item.isVisible && !_isItemGhosted(item, workspace)) {
            if (item is LogicGroupItem) {
              final childHit = hitTestRecursive(item.children, pos);
              if (childHit.itemId != null) return childHit;

              final bounds = BoundingBoxUtils.getCombinedRect([item]);
              if (bounds.contains(pos)) return HitResult(itemId: item.id, handle: HandleType.move);
            } else if (item is RectItem || item is RRectItem || item is OvalItem) {
              final rect = item is RectItem ? item.rect : (item is RRectItem ? item.rect : (item as OvalItem).rect);
              if (_getRectHandleHit(rect, pos) == HandleType.move) return HitResult(itemId: item.id, handle: HandleType.move);
            } else if (item is TextItem) {
              if (BoundingBoxUtils.getCombinedRect([item]).contains(pos)) return HitResult(itemId: item.id, handle: HandleType.move);
            } else if (item is PathItem) {
              final path = BezierPathData(nodes: item.nodes, isClosed: item.isClosed).generatePath();
              if (path.contains(pos)) return HitResult(itemId: item.id, handle: HandleType.move);
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Listener(
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
                            paint: item.paint, nodes: newNodes, isClosed: item.isClosed
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
                    // Start Marquee if clicked empty space
                    if (!isMultiSelectKey) ref.read(workspaceProvider.notifier).selectItem(null);
                    setState(() {
                      _marqueeStart = logicalPos;
                      _marqueeEnd = logicalPos;
                      _draggingItemId = null;
                      _activeHandle = HandleType.none;
                    });
                  } else {
                    // Update selection
                    if (!workspace.selectedItemIds.contains(hit.itemId)) {
                       ref.read(workspaceProvider.notifier).selectItem(hit.itemId, multi: isMultiSelectKey);
                    }

                    // Prepare drag states maps
                    _dragStartLocalPosition = logicalPos;
                    _draggingItemId = hit.itemId;
                    _activeHandle = hit.handle;
                    _draggingNodeIndex = hit.nodeIndex;
                    _dragOriginalItemsState.clear();
                    _dragStartRects.clear();
                    
                    final selectedItems = ref.read(workspaceProvider.notifier).selectedItems;

                    if (workspace.isTransformMode && selectedItems.isNotEmpty) {
                       _dragStartRects['__combined__'] = BoundingBoxUtils.getCombinedRect(selectedItems);
                    }

                    for (var item in selectedItems) {
                      _dragOriginalItemsState[item.id] = item;
                      if (item is RectItem) _dragStartRects[item.id] = item.rect;
                      else if (item is RRectItem) _dragStartRects[item.id] = item.rect;
                      else if (item is OvalItem) _dragStartRects[item.id] = item.rect;
                      else if (item is TextItem) _dragStartRects[item.id] = BoundingBoxUtils.getCombinedRect([item]);
                      
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

                  // 1. Marquee Update
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

                  // HELPER: Safely translate an item by a coordinate delta
                  CanvasItem translateItem(CanvasItem cItem, Offset d) {
                    if (cItem is RectItem) return RectItem(id: cItem.id, name: cItem.name, isVisible: cItem.isVisible, enabledIf: cItem.enabledIf, paint: cItem.paint, rect: cItem.rect.shift(d));
                    if (cItem is RRectItem) return RRectItem(id: cItem.id, name: cItem.name, isVisible: cItem.isVisible, enabledIf: cItem.enabledIf, paint: cItem.paint, rect: cItem.rect.shift(d), radius: cItem.radius);
                    if (cItem is OvalItem) return OvalItem(id: cItem.id, name: cItem.name, isVisible: cItem.isVisible, enabledIf: cItem.enabledIf, paint: cItem.paint, rect: cItem.rect.shift(d));
                    if (cItem is TextItem) return TextItem(id: cItem.id, name: cItem.name, isVisible: cItem.isVisible, enabledIf: cItem.enabledIf, paint: cItem.paint, text: cItem.text, position: cItem.position + d, fontSize: cItem.fontSize, isBold: cItem.isBold);
                    if (cItem is PathItem) {
                      return PathItem(id: cItem.id, name: cItem.name, isVisible: cItem.isVisible, enabledIf: cItem.enabledIf, paint: cItem.paint, isClosed: cItem.isClosed, nodes: cItem.nodes.map((n) => PathNode(
                        position: n.position + d,
                        controlPoint1: n.controlPoint1 != null ? n.controlPoint1! + d : null,
                        controlPoint2: n.controlPoint2 != null ? n.controlPoint2! + d : null,
                      )).toList());
                    }
                    if (cItem is LogicGroupItem) return LogicGroupItem(id: cItem.id, name: cItem.name, isVisible: cItem.isVisible, enabledIf: cItem.enabledIf, paint: cItem.paint, condition: cItem.condition, children: cItem.children.map((c) => translateItem(c, d)).toList());
                    return cItem;
                  }

                  // 2. Multi-Item Transform & Translation
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
                          final movedItem = translateItem(original, moveDelta); // FIXED HERE
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
                          ref.read(workspaceProvider.notifier).updateItem(stretchedItem);
                       }
                     }
                     return;
                  }

                  // 3. Multi-Item Move (Non-Transform Mode)
                  if (selectedItems.length > 1 && _activeHandle == HandleType.move) {
                     Offset finalDelta = delta;
                     // Calculate an anchor to snap the entire group by the first item
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
                        
                        final movedItem = translateItem(original, finalDelta); // FIXED HERE
                        ref.read(workspaceProvider.notifier).updateItem(movedItem);
                     }
                     return;
                  }

                  // 4. Single-Item Direct Shape Editing (Retained Logic)
                  if (selectedItems.length == 1) {
                     final item = selectedItems.first;
                     final itemRect = _dragStartRects[item.id];
                     
                     if ((item is RectItem || item is RRectItem || item is OvalItem) && itemRect != null) {
                         double left = itemRect.left;
                         double top = itemRect.top;
                         double right = itemRect.right;
                         double bottom = itemRect.bottom;
               
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
               
                         final newRect = Rect.fromLTRB(
                           left < right ? left : right, top < bottom ? top : bottom,
                           left < right ? right : left, top < bottom ? bottom : top,
                         );
                         
                         if (item is RectItem) ref.read(workspaceProvider.notifier).updateItem(RectItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, rect: newRect));
                         else if (item is RRectItem) ref.read(workspaceProvider.notifier).updateItem(RRectItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, rect: newRect, radius: item.radius));
                         else if (item is OvalItem) ref.read(workspaceProvider.notifier).updateItem(OvalItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, rect: newRect));
                     }
                     else if (item is TextItem && _activeHandle == HandleType.move) {
                        final originalText = _dragOriginalItemsState[item.id] as TextItem;
                        Offset newPos = originalText.position + delta;
                        if (workspace.snapToGrid) newPos = Offset(_snap(newPos.dx, workspace.gridSnapSize), _snap(newPos.dy, workspace.gridSnapSize));
                        ref.read(workspaceProvider.notifier).updateItem(TextItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, text: item.text, position: newPos, fontSize: item.fontSize, isBold: item.isBold));
                     }
                     else if (item is PathItem && _dragStartNodes != null) {
                        List<PathNode> newNodes = _dragStartNodes!.map((n) => PathNode(position: n.position, controlPoint1: n.controlPoint1, controlPoint2: n.controlPoint2)).toList();
              
                        if (_activeHandle == HandleType.move) {
                          Offset snapDelta = delta;
                          if (workspace.snapToGrid) {
                            final startNode0 = _dragStartNodes![0].position;
                            final targetNode0 = startNode0 + delta;
                            final snappedNode0 = Offset(_snap(targetNode0.dx, workspace.gridSnapSize), _snap(targetNode0.dy, workspace.gridSnapSize));
                            snapDelta = snappedNode0 - startNode0;
                          }
                          for (int i = 0; i < newNodes.length; i++) {
                            newNodes[i].position = _dragStartNodes![i].position + snapDelta;
                            if (newNodes[i].controlPoint1 != null) newNodes[i].controlPoint1 = _dragStartNodes![i].controlPoint1! + snapDelta;
                            if (newNodes[i].controlPoint2 != null) newNodes[i].controlPoint2 = _dragStartNodes![i].controlPoint2! + snapDelta;
                          }
                        } else if (_draggingNodeIndex != null) {
                          final i = _draggingNodeIndex!;
                          
                          if (_activeHandle == HandleType.pathEdge) {
                            int nextIndex = (i + 1) % newNodes.length;
                            void moveNode(int idx) {
                              var newPos = _dragStartNodes![idx].position + delta;
                              if (workspace.snapToGrid) newPos = Offset(_snap(newPos.dx, workspace.gridSnapSize), _snap(newPos.dy, workspace.gridSnapSize));
                              final posDelta = newPos - _dragStartNodes![idx].position;
                              newNodes[idx].position = newPos;
                              if (newNodes[idx].controlPoint1 != null) newNodes[idx].controlPoint1 = _dragStartNodes![idx].controlPoint1! + posDelta;
                              if (newNodes[idx].controlPoint2 != null) newNodes[idx].controlPoint2 = _dragStartNodes![idx].controlPoint2! + posDelta;
                            }
                            moveNode(i); moveNode(nextIndex);
                          } 
                          else if (_activeHandle == HandleType.pathNode) {
                            var newPos = _dragStartNodes![i].position + delta;
                            bool snappedToClose = false;
                            if (!item.isClosed && (i == 0 || i == newNodes.length - 1) && newNodes.length > 2) {
                               int otherIndex = (i == 0) ? newNodes.length - 1 : 0;
                               if ((newPos - _dragStartNodes![otherIndex].position).distance <= (_hitTolerance / _cameraZoom) * 2) {
                                   newPos = _dragStartNodes![otherIndex].position;
                                   snappedToClose = true;
                               }
                            }
                            if (!snappedToClose && workspace.snapToGrid) newPos = Offset(_snap(newPos.dx, workspace.gridSnapSize), _snap(newPos.dy, workspace.gridSnapSize));
                            final posDelta = newPos - _dragStartNodes![i].position;
                            newNodes[i].position = newPos;
                            if (newNodes[i].controlPoint1 != null) newNodes[i].controlPoint1 = _dragStartNodes![i].controlPoint1! + posDelta;
                            if (newNodes[i].controlPoint2 != null) newNodes[i].controlPoint2 = _dragStartNodes![i].controlPoint2! + posDelta;
                          }
                          else if (_activeHandle == HandleType.pathControl1 && _dragStartNodes![i].controlPoint1 != null) {
                            var newPos = _dragStartNodes![i].controlPoint1! + delta;
                            if (workspace.snapToGrid) newPos = Offset(_snap(newPos.dx, workspace.gridSnapSize), _snap(newPos.dy, workspace.gridSnapSize));
                            newNodes[i].controlPoint1 = newPos;
                          }
                          else if (_activeHandle == HandleType.pathControl2 && _dragStartNodes![i].controlPoint2 != null) {
                            var newPos = _dragStartNodes![i].controlPoint2! + delta;
                            if (workspace.snapToGrid) newPos = Offset(_snap(newPos.dx, workspace.gridSnapSize), _snap(newPos.dy, workspace.gridSnapSize));
                            newNodes[i].controlPoint2 = newPos;
                          } 
                        }
              
                        ref.read(workspaceProvider.notifier).updateItem(PathItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, nodes: newNodes, isClosed: item.isClosed));
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
                    // --- SIMULATED TAP LOGIC (Path adding node) ---
                    if (_draggingItemId != null && _activeHandle == HandleType.pathEdge && _draggingNodeIndex != null) {
                      final item = _findItemRecursive(workspace.items, _draggingItemId);
                      if (item is PathItem && _dragStartLocalPosition != null) {
                        final newNodes = List<PathNode>.from(item.nodes);
                        var newPos = _dragStartLocalPosition!;
                        if (workspace.snapToGrid) newPos = Offset(_snap(newPos.dx, workspace.gridSnapSize), _snap(newPos.dy, workspace.gridSnapSize));
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
                        final updatedItem = PathItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, nodes: newNodes, isClosed: item.isClosed);
                        ref.read(historyProvider.notifier).execute(UpdateCommand(item, updatedItem, ref.read(workspaceProvider.notifier)));
                      }
                    }
                  } else if (_hasDragged) {
                    // --- DRAG END COMMIT ---
                    final selectedItems = ref.read(workspaceProvider.notifier).selectedItems;

                    // Handling path snapping/closing logic for single item
                    if (selectedItems.length == 1) {
                        final item = selectedItems.first;
                        final original = _dragOriginalItemsState[item.id];
                        if (original is PathItem && _activeHandle == HandleType.pathNode && _draggingNodeIndex != null) {
                          if (item is PathItem && !item.isClosed && item.nodes.length > 2) {
                            final int i = _draggingNodeIndex!;
                            final int otherIndex = (i == 0) ? item.nodes.length - 1 : 0;
                            if ((item.nodes[i].position - item.nodes[otherIndex].position).distance <= (_hitTolerance / _cameraZoom) * 2) {
                              final newNodes = List<PathNode>.from(item.nodes);
                              if (i == item.nodes.length - 1) {
                                final draggedNode = newNodes.removeLast();
                                if (draggedNode.controlPoint1 != null) newNodes[0] = PathNode(position: newNodes[0].position, controlPoint1: draggedNode.controlPoint1, controlPoint2: newNodes[0].controlPoint2);
                              } else {
                                final draggedNode = newNodes.removeAt(0);
                                if (draggedNode.controlPoint2 != null) newNodes.last = PathNode(position: newNodes.last.position, controlPoint1: newNodes.last.controlPoint1, controlPoint2: draggedNode.controlPoint2);
                              }
                              final updatedItem = PathItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, nodes: newNodes, isClosed: true);
                              ref.read(workspaceProvider.notifier).updateItem(updatedItem);
                              ref.read(historyProvider.notifier).execute(UpdateCommand(original, updatedItem, ref.read(workspaceProvider.notifier)));
                              _clearDragState();
                              return;
                            }
                          }
                        }
                    }

                    // For every item dragged, if it differs from the original, we should commit to history.
                    // Note: If many items are dragged, issuing many UpdateCommands individually will bloat the history undo stack.
                    // To keep previous functionality identical while supporting multiple, we execute updates loop.
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
                  hoverPos: _hoverPos,
                  hoveredNodeIndex: _hoveredNodeIndex,
                  gridSnapSize: workspace.gridSnapSize,
                  cameraPan: _cameraPan,
                  cameraZoom: _cameraZoom,
                  isTransformMode: workspace.isTransformMode,
                  variables: workspace.variables, 
                  marqueeRect: _marqueeStart != null && _marqueeEnd != null ? Rect.fromPoints(_marqueeStart!, _marqueeEnd!) : null,
                ),
                size: canvasSize,
              ),
            ),
          ),
        );
      }
    );
  }
}