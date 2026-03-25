// File: lib/screens/editor_screen.dart
// Description: The main UI shell with a new robust hierarchy panel supporting markers and nested dragging.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/workspace_provider.dart';
import '../state/history/history_manager.dart';
import '../state/commands/workspace_commands.dart';
import '../models/canvas_item.dart';
import '../utils/shape_generator.dart';
import '../utils/expression_evaluator.dart';
import 'widgets/inspector_panel.dart';
import 'widgets/interactive_canvas.dart';
import 'widgets/ui/export_dialog.dart';
import 'widgets/ui/history_toolbar.dart';
import 'widgets/ui/import_modal.dart';
import '../services/import/import_scanner.dart';

class _HierarchyNode extends ConsumerStatefulWidget {
  final CanvasItem item;
  final int depth;

  const _HierarchyNode({required this.item, this.depth = 0});

  @override
  ConsumerState<_HierarchyNode> createState() => _HierarchyNodeState();
}

class _HierarchyNodeState extends ConsumerState<_HierarchyNode> {
  DropPosition? _dropPos;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);
    // FIXED: Check if the set contains this item's ID
    final isSelected = workspace.selectedItemIds.contains(widget.item.id);
    
    final isGhost = !ExpressionEvaluator.evaluate(widget.item.enabledIf, workspace.variables);
    final hasCondition = widget.item.enabledIf != null && widget.item.enabledIf!.trim().isNotEmpty;
    
    Widget nodeContent = Material(
      color: isSelected ? Colors.white10 : Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(workspaceProvider.notifier).selectItem(widget.item.id),
        child: Container(
          decoration: BoxDecoration(
            color: _dropPos == DropPosition.into ? Colors.orangeAccent.withOpacity(0.3) : Colors.transparent,
            border: Border(
              top: BorderSide(color: _dropPos == DropPosition.above ? Colors.blueAccent : Colors.transparent, width: 2),
              bottom: BorderSide(color: _dropPos == DropPosition.below ? Colors.blueAccent : Colors.transparent, width: 2),
            )
          ),
          padding: EdgeInsets.only(left: 8.0 + (widget.depth * 16.0), right: 8.0, top: 12.0, bottom: 12.0),
          child: Opacity(
            opacity: isGhost ? 0.3 : 1.0, 
            child: Row(
              children: [
                Icon(
                  widget.item is LogicGroupItem ? Icons.folder : 
                  (widget.item is TextItem ? Icons.text_fields : 
                  (widget.item is RectItem ? Icons.check_box_outline_blank : 
                  (widget.item is RRectItem ? Icons.crop_square : 
                  (widget.item is OvalItem ? Icons.circle_outlined : Icons.gesture)))),
                  color: widget.item is LogicGroupItem ? Colors.orangeAccent : Colors.white54,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.item.name, 
                    style: TextStyle(
                      color: isSelected ? Colors.blueAccent : Colors.white, 
                      fontSize: 13,
                      decoration: isGhost || !widget.item.isVisible ? TextDecoration.lineThrough : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasCondition)
                  const Tooltip(
                    message: 'Has Timeline Conditions',
                    child: Icon(Icons.timeline, size: 14, color: Colors.blueAccent),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    widget.item.isVisible ? Icons.visibility : Icons.visibility_off,
                    size: 16,
                    color: widget.item.isVisible ? Colors.white70 : Colors.white38,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Toggle Visibility',
                  onPressed: () {
                    try {
                      CanvasItem updatedItem;
                      // FIXED: Included transform: i.transform below to prevent reverting to Matrix4.identity()
                      if (widget.item is RectItem) {
                        final i = widget.item as RectItem;
                        updatedItem = RectItem(id: i.id, name: i.name, isVisible: !i.isVisible, enabledIf: i.enabledIf, paint: i.paint, transform: i.transform, rect: i.rect);
                      } else if (widget.item is RRectItem) {
                        final i = widget.item as RRectItem;
                        updatedItem = RRectItem(id: i.id, name: i.name, isVisible: !i.isVisible, enabledIf: i.enabledIf, paint: i.paint, transform: i.transform, rect: i.rect, radius: i.radius);
                      } else if (widget.item is OvalItem) {
                        final i = widget.item as OvalItem;
                        updatedItem = OvalItem(id: i.id, name: i.name, isVisible: !i.isVisible, enabledIf: i.enabledIf, paint: i.paint, transform: i.transform, rect: i.rect);
                      } else if (widget.item is PathItem) {
                        final i = widget.item as PathItem;
                        updatedItem = PathItem(id: i.id, name: i.name, isVisible: !i.isVisible, enabledIf: i.enabledIf, paint: i.paint, transform: i.transform, nodes: i.nodes, isClosed: i.isClosed);
                      } else if (widget.item is TextItem) { 
                        final i = widget.item as TextItem;
                        updatedItem = TextItem(id: i.id, name: i.name, isVisible: !i.isVisible, enabledIf: i.enabledIf, paint: i.paint, transform: i.transform, text: i.text, position: i.position, fontSize: i.fontSize, isBold: i.isBold);
                      } else if (widget.item is LogicGroupItem) {
                        final i = widget.item as LogicGroupItem;
                        updatedItem = LogicGroupItem(id: i.id, name: i.name, isVisible: !i.isVisible, enabledIf: i.enabledIf, paint: i.paint, transform: i.transform, condition: i.condition, children: i.children);
                      } else {
                        return;
                      }
                      ref.read(historyProvider.notifier).execute(
                        UpdateCommand(widget.item, updatedItem, ref.read(workspaceProvider.notifier))
                      );
                    } catch (e) {
                      print('DEBUG ERROR: Visibility toggle failed: $e');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Widget draggableNode = LongPressDraggable<String>(
      data: widget.item.id,
      delay: const Duration(milliseconds: 150),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(widget.item.name, style: const TextStyle(color: Colors.white)),
        ),
      ),
      child: nodeContent,
    );

    Widget targetWrapper = DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != widget.item.id,
      onMove: (details) {
        try {
          final RenderBox box = context.findRenderObject() as RenderBox;
          final Offset localPos = box.globalToLocal(details.offset);
          final double h = box.size.height;
          
          DropPosition pos;
          if (localPos.dy < h * 0.25) pos = DropPosition.above;
          else if (localPos.dy > h * 0.75) pos = DropPosition.below;
          else pos = DropPosition.into;
          
          if (_dropPos != pos) {
            setState(() => _dropPos = pos);
          }
        } catch (e) {
          print('DEBUG ERROR: Drag targeting calculation failed: $e');
        }
      },
      onLeave: (_) => setState(() => _dropPos = null),
      onAcceptWithDetails: (details) {
        if (_dropPos != null) {
          ref.read(workspaceProvider.notifier).moveItemRelative(details.data, widget.item.id, _dropPos!);
        }
        setState(() => _dropPos = null);
      },
      builder: (context, candidateData, rejectedData) => draggableNode,
    );

    if (widget.item is LogicGroupItem) {
      final logicGroup = widget.item as LogicGroupItem;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          targetWrapper,
          if (logicGroup.children.isNotEmpty)
            ...logicGroup.children.map((child) => _HierarchyNode(item: child, depth: widget.depth + 1)),
        ],
      );
    }

    return targetWrapper;
  }
}

class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  Widget _buildTimelineToolbar(WorkspaceState workspace, WidgetRef ref, BuildContext context) {
    final currentStage = workspace.variables['stage'] ?? 1.0;
    
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF252526),
        border: Border(bottom: BorderSide(color: Colors.black54, width: 1))
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.timeline, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 12),
          const Text('Timeline Stage:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(4)),
            child: Text(currentStage.toInt().toString(), style: const TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: Colors.blueAccent.withOpacity(0.5),
                inactiveTrackColor: Colors.white10,
                thumbColor: Colors.blueAccent,
                overlayColor: Colors.blueAccent.withOpacity(0.1),
              ),
              child: Slider(
                value: currentStage,
                min: 0,
                max: 10,
                divisions: 10, 
                label: 'Stage ${currentStage.toInt()}',
                onChanged: (val) {
                  ref.read(workspaceProvider.notifier).setVariable('stage', val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for visually framing the list
  Widget _buildLayerMarker(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.black12,
        border: Border(
          bottom: BorderSide(color: Colors.white10, width: 1),
          top: BorderSide(color: Colors.white10, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider);
    final historyState = ref.watch(historyProvider);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          try {
            final isCtrl = HardwareKeyboard.instance.isControlPressed;
            final isShift = HardwareKeyboard.instance.isShiftPressed;

            if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
              // FIXED: Handle multi-delete via loop
              final selectedItems = ref.read(workspaceProvider.notifier).selectedItems;
              if (selectedItems.isNotEmpty) {
                for (var item in selectedItems) {
                  final parentId = ref.read(workspaceProvider.notifier).getParentId(item.id);
                  ref.read(historyProvider.notifier).execute(RemoveCommand(item, parentId, ref.read(workspaceProvider.notifier)));
                }
              }
              return KeyEventResult.handled;
            }

            if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
              if (isShift) ref.read(historyProvider.notifier).redo();
              else ref.read(historyProvider.notifier).undo();
              return KeyEventResult.handled;
            }

            if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyY) {
              ref.read(historyProvider.notifier).redo();
              return KeyEventResult.handled;
            }
          } catch (e) {
            print('DEBUG ERROR: Key handling failed: $e');
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          title: const Text('Flutter Canvas Wizard', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF252526),
          actions: [
            HistoryToolbar(
              canUndo: historyState.canUndo,
              canRedo: historyState.canRedo,
              onUndo: () => ref.read(historyProvider.notifier).undo(),
              onRedo: () => ref.read(historyProvider.notifier).redo(),
            ),
            const VerticalDivider(color: Colors.white12, indent: 10, endIndent: 10, width: 20),
            
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: workspace.isTransformMode ? Colors.cyanAccent.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: workspace.isTransformMode ? Colors.cyanAccent : Colors.transparent),
              ),
              child: IconButton(
                icon: Icon(Icons.transform, size: 20, color: workspace.isTransformMode ? Colors.cyanAccent : Colors.white70),
                tooltip: 'Transform Mode (Scale/Stretch)',
                onPressed: () => ref.read(workspaceProvider.notifier).toggleTransformMode(),
              ),
            ),
            const VerticalDivider(color: Colors.white12, indent: 10, endIndent: 10, width: 20),

            PopupMenuButton<double>(
              tooltip: 'Grid Snap Settings',
              initialValue: workspace.gridSnapSize,
              icon: Icon(
                workspace.snapToGrid ? Icons.auto_awesome_mosaic : Icons.auto_awesome_mosaic_outlined, 
                color: workspace.snapToGrid ? Colors.yellowAccent : Colors.grey
              ),
              onSelected: (value) {
                if (value == -1) {
                  ref.read(workspaceProvider.notifier).toggleGridSnap();
                } else {
                  ref.read(workspaceProvider.notifier).setGridSnapSize(value);
                  if (!workspace.snapToGrid) ref.read(workspaceProvider.notifier).toggleGridSnap();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: -1, child: Text(workspace.snapToGrid ? 'Disable Snap' : 'Enable Snap')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 5.0, child: Text('Snap: 5px')),
                const PopupMenuItem(value: 10.0, child: Text('Snap: 10px')),
                const PopupMenuItem(value: 20.0, child: Text('Snap: 20px')),
                const PopupMenuItem(value: 50.0, child: Text('Snap: 50px')),
                const PopupMenuItem(value: 100.0, child: Text('Snap: 100px')),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.download, color: Colors.greenAccent),
              tooltip: 'Import Dart Code',
              onPressed: () {
                try {
                  showDialog(
                    context: context,
                    builder: (context) => ImportModal(
                      onImport: (source) {
                        final items = ImportScanner.extractItems(source);
                        if (items.isNotEmpty) {
                          final group = LogicGroupItem(
                            id: 'import_${DateTime.now().millisecondsSinceEpoch}',
                            name: 'Imported Logic',
                            isVisible: true,
                            paint: CanvasPaint(),
                            condition: 'true',
                            children: items,
                          );
                          ref.read(historyProvider.notifier).execute(
                            AddCommand(group, null, ref.read(workspaceProvider.notifier))
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Successfully imported ${items.length} items.')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No supported shapes found in code.')),
                          );
                        }
                      },
                    ),
                  );
                } catch (e) {
                  print('DEBUG ERROR: Import button click failed: $e');
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.code, color: Colors.blueAccent),
              tooltip: 'Export Dart Code',
              onPressed: () {
                try {
                  showDialog(
                    context: context,
                    builder: (context) => ExportDialog(items: workspace.items),
                  );
                } catch (e) {
                  print('DEBUG ERROR: Export button click failed: $e');
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            _buildTimelineToolbar(workspace, ref, context),
            
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 250,
                    color: const Color(0xFF2D2D30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Hierarchy', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.create_new_folder, size: 18, color: Colors.orangeAccent),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Add Group',
                                    onPressed: () {
                                      try {
                                        final newItem = LogicGroupItem(
                                          id: 'logic_${DateTime.now().millisecondsSinceEpoch}',
                                          name: 'New Group',
                                          condition: 'true',
                                          paint: CanvasPaint(),
                                          children: [],
                                        );
                                        ref.read(historyProvider.notifier).execute(AddCommand(newItem, null, ref.read(workspaceProvider.notifier)));
                                      } catch (e) {
                                        print('DEBUG ERROR: Add Group failed: $e');
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    tooltip: 'Add Shapes',
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.add_box, size: 18, color: Colors.greenAccent),
                                    onSelected: (value) {
                                      try {
                                        final paintId = DateTime.now().millisecondsSinceEpoch;
                                        final defaultPaint = CanvasPaint(fillColor: Colors.transparent, strokeWidth: 3, strokeColor: Colors.greenAccent);
                                        CanvasItem? newItem;

                                        switch (value) {
                                          case 'rect':
                                            newItem = RectItem(id: 'rect_$paintId', name: 'Rectangle', rect: const Rect.fromLTRB(-40, -40, 40, 40), paint: defaultPaint);
                                            break;
                                          case 'rrect':
                                            newItem = RRectItem(id: 'rrect_$paintId', name: 'Rounded Rect', rect: const Rect.fromLTRB(-40, -40, 40, 40), radius: 10.0, paint: defaultPaint);
                                            break;
                                          case 'oval':
                                            newItem = OvalItem(id: 'oval_$paintId', name: 'Oval', rect: const Rect.fromLTRB(-40, -30, 40, 30), paint: defaultPaint);
                                            break;
                                          case 'path':
                                            newItem = PathItem(
                                              id: 'path_$paintId', name: 'Bezier Path', paint: defaultPaint, isClosed: false,
                                              nodes: [ PathNode(position: const Offset(-40, 0), controlPoint2: const Offset(-20, -40)), PathNode(position: const Offset(40, 0), controlPoint1: const Offset(20, 40)) ],
                                            );
                                            break;
                                          case 'text': 
                                            newItem = TextItem(id: 'text_$paintId', name: 'Text Block', text: 'Hello World', position: const Offset(-40, -10), fontSize: 24.0, paint: CanvasPaint(fillColor: Colors.white, strokeWidth: 0, strokeColor: Colors.transparent));
                                            break;
                                          case 'circle':
                                            newItem = ShapeGenerator.createCircle(id: 'circle_$paintId', name: 'Circle', center: Offset.zero, radius: 40, paint: defaultPaint);
                                            break;
                                          case 'triangle':
                                            newItem = ShapeGenerator.createPolygon(id: 'triangle_$paintId', name: 'Triangle', center: Offset.zero, sides: 3, radius: 40, paint: defaultPaint);
                                            break;
                                          case 'star':
                                            newItem = ShapeGenerator.createStar(id: 'star_$paintId', name: 'Star', center: Offset.zero, points: 5, innerRadius: 20, outerRadius: 40, paint: defaultPaint);
                                            break;
                                        }

                                        if (newItem != null) {
                                          ref.read(historyProvider.notifier).execute(AddCommand(newItem, null, ref.read(workspaceProvider.notifier)));
                                        }
                                      } catch (e) {
                                        print('DEBUG ERROR: Shape generation selection failed: $e');
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'rect', child: ListTile(leading: Icon(Icons.check_box_outline_blank), title: Text('Rectangle'))),
                                      PopupMenuItem(value: 'rrect', child: ListTile(leading: Icon(Icons.crop_square), title: Text('Rounded Rect'))),
                                      PopupMenuItem(value: 'oval', child: ListTile(leading: Icon(Icons.circle_outlined), title: Text('Oval / Ellipse'))),
                                      PopupMenuItem(value: 'path', child: ListTile(leading: Icon(Icons.gesture), title: Text('Bezier Path'))),
                                      PopupMenuItem(value: 'text', child: ListTile(leading: Icon(Icons.text_fields), title: Text('Text Block'))), 
                                      PopupMenuDivider(),
                                      PopupMenuItem(value: 'circle', child: ListTile(leading: Icon(Icons.circle), title: Text('Vector Circle'))),
                                      PopupMenuItem(value: 'triangle', child: ListTile(leading: Icon(Icons.change_history), title: Text('Triangle'))),
                                      PopupMenuItem(value: 'star', child: ListTile(leading: Icon(Icons.star_border), title: Text('Star'))),
                                    ],
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.black54),
                        Expanded(
                          child: DragTarget<String>(
                            onAcceptWithDetails: (details) {
                              ref.read(workspaceProvider.notifier).reparentItem(details.data, null);
                            },
                            builder: (context, candidateData, rejectedData) {
                              final isHovered = candidateData.isNotEmpty;
                              return Container(
                                color: isHovered ? Colors.white10 : Colors.transparent,
                                child: ListView(
                                  children: [
                                    _buildLayerMarker('BACKGROUND / BOTTOM', Icons.keyboard_double_arrow_down),
                                    ...workspace.items.map((item) => _HierarchyNode(item: item)).toList(),
                                    if (workspace.items.isNotEmpty)
                                      _buildLayerMarker('FOREGROUND / TOP', Icons.keyboard_double_arrow_up),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: const Color(0xFF1E1E1E),
                      child: const ClipRect(
                        child: InteractiveCanvas(),
                      ),
                    ),
                  ),
                  Container(
                    width: 300,
                    color: const Color(0xFF2D2D30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Inspector', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const Divider(height: 1, color: Colors.black54),
                        const Expanded(
                          child: InspectorPanel(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}