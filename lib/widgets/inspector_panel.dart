// File: lib/widgets/inspector_panel.dart
// Description: Advanced property editor overhauled with Accordions, better terminology, and designer-friendly grouping. Now supports TextItem properties.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/workspace_provider.dart';
import '../state/history/history_manager.dart';
import '../state/commands/workspace_commands.dart';
import '../models/canvas_item.dart';
import '../utils/bounding_box_utils.dart';
import '../utils/transform_utils.dart';
import 'color_picker_dialog.dart';
import 'ui/inspector_slider.dart';
import 'ui/property_accordion.dart';

class InspectorPanel extends ConsumerStatefulWidget {
  const InspectorPanel({super.key});

  @override
  ConsumerState<InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends ConsumerState<InspectorPanel> {
  bool _showAdvancedLogic = false;

  String _hexFromColor(Color color) {
    return color.value.toRadixString(16).toUpperCase().padLeft(8, '0');
  }

  void _updateItem(CanvasItem updatedItem, CanvasItem oldItem) {
    try {
      ref.read(historyProvider.notifier).execute(
        UpdateCommand(oldItem, updatedItem, ref.read(workspaceProvider.notifier))
      );
    } catch (e) {
      print('DEBUG ERROR: Inspector update failed: $e');
    }
  }

  Future<void> _showColorPicker(String label, Color currentColor, Function(Color) onSelected) async {
    try {
      final Color? newColor = await showDialog<Color>(
        context: context,
        builder: (context) => ColorPickerDialog(initialColor: currentColor),
      );
      if (newColor != null) {
        onSelected(newColor);
      }
    } catch (e) {
      print('DEBUG ERROR: Color picker failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);
    final selectedId = workspace.selectedItemId;

    if (selectedId == null) {
      return const Center(
        child: Text('No item selected', style: TextStyle(color: Colors.white54)),
      );
    }

    CanvasItem? findItemRecursive(List<CanvasItem> list, String id) {
      for (var item in list) {
        if (item.id == id) return item;
        if (item is LogicGroupItem) {
          final found = findItemRecursive(item.children, id);
          if (found != null) return found;
        }
      }
      return null;
    }

    final item = findItemRecursive(workspace.items, selectedId) ?? 
                 RectItem(id: 'err', name: 'Error', rect: Rect.zero, paint: CanvasPaint());

    return ListView(
      padding: const EdgeInsets.only(bottom: 24.0),
      children: [
        // --- IDENTITY (Always visible) ---
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: ${item.id}', style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              _buildStringRow('Name', item.name, (val) {
                if (item is RectItem) {
                  _updateItem(RectItem(id: item.id, name: val, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, rect: item.rect), item);
                } else if (item is RRectItem) {
                  _updateItem(RRectItem(id: item.id, name: val, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, rect: item.rect, radius: item.radius), item);
                } else if (item is OvalItem) {
                  _updateItem(OvalItem(id: item.id, name: val, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, rect: item.rect), item);
                } else if (item is PathItem) {
                  _updateItem(PathItem(id: item.id, name: val, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, nodes: item.nodes, isClosed: item.isClosed), item);
                } else if (item is TextItem) {
                  _updateItem(TextItem(id: item.id, name: val, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, text: item.text, position: item.position, fontSize: item.fontSize, isBold: item.isBold), item);
                } else if (item is LogicGroupItem) {
                  _updateItem(LogicGroupItem(id: item.id, name: val, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, condition: item.condition, children: item.children), item);
                }
              }),
            ],
          ),
        ),

        // --- TRANSFORM & SHAPE DATA ---
        if (item is RectItem || item is RRectItem || item is OvalItem || item is PathItem || item is TextItem)
          PropertyAccordion(
            title: item is PathItem ? 'Path Nodes' : 'Transform & Data',
            initiallyExpanded: true,
            children: [
              if (item is RectItem) _buildRectFields(item),
              if (item is RRectItem) _buildRRectFields(item),
              if (item is OvalItem) _buildOvalFields(item),
              if (item is PathItem) _buildPathFields(item),
              if (item is TextItem) _buildTextFields(item),
            ],
          ),

        // --- APPEARANCE & EXPORT VARIABLES ---
        if (item is! LogicGroupItem)
          PropertyAccordion(
            title: 'Appearance',
            initiallyExpanded: true,
            children: [
              _buildPaintSection(item),
            ],
          ),

        // --- 3D EXTRUSION ---
        if (item is! LogicGroupItem && item is! TextItem)
          PropertyAccordion(
            title: '3D Extrusion',
            initiallyExpanded: false,
            children: [
              _buildExtrusionSection(item),
            ],
          ),

        // --- LOGIC & TIMELINE ---
        PropertyAccordion(
          title: 'Timeline Visibility',
          initiallyExpanded: item.enabledIf != null,
          children: [
            _buildVisibilitySection(item),
          ],
        ),

        // --- QUICK ACTIONS ---
        PropertyAccordion(
          title: 'Actions',
          initiallyExpanded: true,
          children: [
            _buildQuickTransformSection(item),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.15),
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 40),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete Item'),
              onPressed: () {
                try {
                  final parentId = ref.read(workspaceProvider.notifier).getParentId(item.id);
                  ref.read(historyProvider.notifier).execute(
                    RemoveCommand(item, parentId, ref.read(workspaceProvider.notifier))
                  );
                } catch(e) {
                  print('DEBUG ERROR: Delete button failed: $e');
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  // --- PROGRESSIVE VISIBILITY UI ---
  Widget _buildVisibilitySection(CanvasItem item) {
    bool hasCondition = item.enabledIf != null && item.enabledIf!.trim().isNotEmpty;

    int minStage = 1;
    int maxStage = 10;
    
    if (hasCondition && !_showAdvancedLogic) {
      final exp = item.enabledIf!;
      if (exp.contains('stage >=')) {
        final match = RegExp(r'stage >= (\d+)').firstMatch(exp);
        if (match != null) minStage = int.tryParse(match.group(1)!) ?? 1;
      }
      if (exp.contains('stage <=')) {
        final match = RegExp(r'stage <= (\d+)').firstMatch(exp);
        if (match != null) maxStage = int.tryParse(match.group(1)!) ?? 10;
      }
    }

    void applyVisibility(String? newCondition) {
      final val = (newCondition == null || newCondition.trim().isEmpty) ? null : newCondition;
      if (item is RectItem) {
        _updateItem(RectItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: val, paint: item.paint, rect: item.rect), item);
      } else if (item is RRectItem) {
        _updateItem(RRectItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: val, paint: item.paint, rect: item.rect, radius: item.radius), item);
      } else if (item is OvalItem) {
        _updateItem(OvalItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: val, paint: item.paint, rect: item.rect), item);
      } else if (item is PathItem) {
        _updateItem(PathItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: val, paint: item.paint, nodes: item.nodes, isClosed: item.isClosed), item);
      } else if (item is TextItem) {
        _updateItem(TextItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: val, paint: item.paint, text: item.text, position: item.position, fontSize: item.fontSize, isBold: item.isBold), item);
      } else if (item is LogicGroupItem) {
        _updateItem(LogicGroupItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: val, paint: item.paint, condition: item.condition, children: item.children), item);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasCondition)
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => setState(() => _showAdvancedLogic = !_showAdvancedLogic),
              child: Text(_showAdvancedLogic ? 'Switch to Visual Builder' : 'Switch to Advanced Editor', style: const TextStyle(color: Colors.blueAccent, fontSize: 10)),
            ),
          ),
        const SizedBox(height: 8),
        
        if (!hasCondition) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
            child: Row(
              children: [
                const Icon(Icons.visibility, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                const Text('Always Visible', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withOpacity(0.2),
                    foregroundColor: Colors.blueAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(0, 28),
                  ),
                  onPressed: () => applyVisibility('stage >= 1 && stage <= 10'),
                  child: const Text('Add Rule', style: TextStyle(fontSize: 10)),
                )
              ],
            ),
          )
        ] else if (_showAdvancedLogic) ...[
          _buildStringRow('Expression', item.enabledIf ?? '', applyVisibility),
          const Padding(
            padding: EdgeInsets.only(left: 80.0, top: 4.0),
            child: Text('e.g., "stage >= 2 && color == 1"', style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => applyVisibility(null),
            child: const Text('Remove Logic', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
          )
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.05), 
              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(4)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Show on Timeline Stages:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('From', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(width: 8),
                    _buildMiniDropdown(minStage, 1, 10, (val) {
                      applyVisibility('stage >= $val && stage <= $maxStage');
                    }),
                    const SizedBox(width: 12),
                    const Text('To', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(width: 8),
                    _buildMiniDropdown(maxStage, 1, 10, (val) {
                      applyVisibility('stage >= $minStage && stage <= $val');
                    }),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14, color: Colors.white54),
                      onPressed: () => applyVisibility(null),
                      tooltip: 'Remove Condition',
                    )
                  ],
                ),
              ],
            ),
          )
        ]
      ],
    );
  }

  Widget _buildMiniDropdown(int currentValue, int min, int max, Function(int) onChanged) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
      child: DropdownButton<int>(
        value: currentValue.clamp(min, max),
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF2D2D30),
        style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold),
        items: List.generate((max - min) + 1, (i) => DropdownMenuItem(value: min + i, child: Text('${min + i}'))),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }

  Widget _buildQuickTransformSection(CanvasItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Scale', style: TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _scaleButton(item, '0.5x', 0.5),
            _scaleButton(item, '0.9x', 0.9),
            _scaleButton(item, '1.1x', 1.1),
            _scaleButton(item, '2.0x', 2.0),
          ],
        ),
      ],
    );
  }

  Widget _scaleButton(CanvasItem item, String label, double factor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent.withOpacity(0.1),
            foregroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(vertical: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: const BorderSide(color: Colors.blueAccent, width: 0.5),
            ),
          ),
          onPressed: () {
            try {
              final bounds = BoundingBoxUtils.getCombinedRect([item]);
              final origin = bounds != Rect.zero ? bounds.center : Offset.zero;
              final scaledItem = TransformUtils.scaleItem(item, factor, origin);
              _updateItem(scaledItem, item);
            } catch (e) {
              print('DEBUG ERROR: Quick scale failed: $e');
            }
          },
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildTextFields(TextItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStringRow('String', item.text, (val) => _updateItem(TextItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, position: item.position, text: val, fontSize: item.fontSize, isBold: item.isBold), item)),
        const SizedBox(height: 8),
        _buildNumberRow('X Pos', item.position.dx, (val) => _updateItem(TextItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, position: Offset(val, item.position.dy), text: item.text, fontSize: item.fontSize, isBold: item.isBold), item)),
        _buildNumberRow('Y Pos', item.position.dy, (val) => _updateItem(TextItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, position: Offset(item.position.dx, val), text: item.text, fontSize: item.fontSize, isBold: item.isBold), item)),
        _buildNumberRow('Font Size', item.fontSize, (val) => _updateItem(TextItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, position: item.position, text: item.text, fontSize: val, isBold: item.isBold), item)),
        Row(
          children: [
            const Text('Font Weight', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const Spacer(),
            const Text('Bold', style: TextStyle(color: Colors.white54, fontSize: 11)),
            Switch(
              value: item.isBold,
              activeColor: Colors.blueAccent,
              onChanged: (val) => _updateItem(TextItem(id: item.id, name: item.name, isVisible: item.isVisible, enabledIf: item.enabledIf, paint: item.paint, position: item.position, text: item.text, fontSize: item.fontSize, isBold: val), item),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRectFields(RectItem item) {
    return Column(
      children: [
        _buildNumberRow('X Pos', item.rect.left, (val) {
          _updateItem(RectItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, rect: Rect.fromLTWH(val, item.rect.top, item.rect.width, item.rect.height)), item);
        }),
        _buildNumberRow('Y Pos', item.rect.top, (val) {
          _updateItem(RectItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, rect: Rect.fromLTWH(item.rect.left, val, item.rect.width, item.rect.height)), item);
        }),
        _buildNumberRow('Width', item.rect.width, (val) {
          _updateItem(RectItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, rect: Rect.fromLTWH(item.rect.left, item.rect.top, val, item.rect.height)), item);
        }),
        _buildNumberRow('Height', item.rect.height, (val) {
          _updateItem(RectItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, rect: Rect.fromLTWH(item.rect.left, item.rect.top, item.rect.width, val)), item);
        }),
      ],
    );
  }

  Widget _buildRRectFields(RRectItem item) {
    return Column(
      children: [
        _buildNumberRow('X Pos', item.rect.left, (val) {
          _updateItem(RRectItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, rect: Rect.fromLTWH(val, item.rect.top, item.rect.width, item.rect.height), radius: item.radius), item);
        }),
        _buildNumberRow('Y Pos', item.rect.top, (val) {
          _updateItem(RRectItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, rect: Rect.fromLTWH(item.rect.left, val, item.rect.width, item.rect.height), radius: item.radius), item);
        }),
        _buildNumberRow('Width', item.rect.width, (val) {
          _updateItem(RRectItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, rect: Rect.fromLTWH(item.rect.left, item.rect.top, val, item.rect.height), radius: item.radius), item);
        }),
        _buildNumberRow('Height', item.rect.height, (val) {
          _updateItem(RRectItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, rect: Rect.fromLTWH(item.rect.left, item.rect.top, item.rect.width, val), radius: item.radius), item);
        }),
        const SizedBox(height: 8),
        InspectorSlider(
          label: 'Corner Radius',
          value: item.radius,
          min: 0,
          max: 100,
          onChanged: (val) {
             _updateItem(RRectItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, rect: item.rect, radius: val), item);
          },
        ),
      ],
    );
  }

  Widget _buildOvalFields(OvalItem item) {
    return Column(
      children: [
        _buildNumberRow('X Pos', item.rect.left, (val) {
          _updateItem(OvalItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, rect: Rect.fromLTWH(val, item.rect.top, item.rect.width, item.rect.height)), item);
        }),
        _buildNumberRow('Y Pos', item.rect.top, (val) {
          _updateItem(OvalItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, rect: Rect.fromLTWH(item.rect.left, val, item.rect.width, item.rect.height)), item);
        }),
        _buildNumberRow('Width', item.rect.width, (val) {
          _updateItem(OvalItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, rect: Rect.fromLTWH(item.rect.left, item.rect.top, val, item.rect.height)), item);
        }),
        _buildNumberRow('Height', item.rect.height, (val) {
          _updateItem(OvalItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, rect: Rect.fromLTWH(item.rect.left, item.rect.top, item.rect.width, val)), item);
        }),
      ],
    );
  }

  Widget _buildPathFields(PathItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Close Path', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const Spacer(),
            Switch(
              value: item.isClosed,
              activeColor: Colors.blueAccent,
              onChanged: (val) {
                try {
                  _updateItem(PathItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, nodes: item.nodes, isClosed: val), item);
                } catch (e) {
                  print('DEBUG ERROR: Toggle path closed failed: $e');
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${item.nodes.length} Vertices', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                    tooltip: 'Remove Last Node',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: item.nodes.length > 1 ? () {
                      try {
                        final newNodes = List<PathNode>.from(item.nodes)..removeLast();
                        _updateItem(PathItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, nodes: newNodes, isClosed: item.isClosed), item);
                      } catch (e) {
                        print('DEBUG ERROR: Remove node failed: $e');
                      }
                    } : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent, size: 18),
                    tooltip: 'Add Node',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () {
                      try {
                        final lastNode = item.nodes.last;
                        final newNodes = List<PathNode>.from(item.nodes)..add(
                          PathNode(
                            position: lastNode.position + const Offset(40, 0),
                            controlPoint1: lastNode.position + const Offset(20, -20),
                            controlPoint2: lastNode.position + const Offset(60, 20),
                          )
                        );
                        _updateItem(PathItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: item.paint, nodes: newNodes, isClosed: item.isClosed), item);
                      } catch (e) {
                        print('DEBUG ERROR: Add node failed: $e');
                      }
                    },
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaintSection(CanvasItem item) {
    final p = item.paint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildColorRow('Fill Color', p.fillColor, (c) => _applyPaint(item, p.copyWith(fillColor: c))),
        _buildColorRow('Stroke Color', p.strokeColor, (c) => _applyPaint(item, p.copyWith(strokeColor: c))),
        const SizedBox(height: 8),
        _buildNumberRow('Stroke Width', p.strokeWidth, (v) => _applyPaint(item, p.copyWith(strokeWidth: v))),
        _buildDropdownRow<StrokeCap>('Line Cap', p.strokeCap, StrokeCap.values, (v) => _applyPaint(item, p.copyWith(strokeCap: v))),
        _buildDropdownRow<BlendMode>('Blend Mode', p.blendMode, BlendMode.values, (v) => _applyPaint(item, p.copyWith(blendMode: v))),
        
        const Divider(color: Colors.white12, height: 24),
        
        // Code Export Variables
        const Text('Code Export Variables', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(height: 4),
        const Text('Override hex colors with Dart variables when exporting.', style: TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 8),
        _buildStringRow('Fill Var', p.fillColorParam ?? '', (v) => _applyPaint(item, p.copyWith(fillColorParam: v.isEmpty ? null : v)), hint: 'e.g. theme.primary'),
        _buildStringRow('Stroke Var', p.strokeColorParam ?? '', (v) => _applyPaint(item, p.copyWith(strokeColorParam: v.isEmpty ? null : v)), hint: 'e.g. theme.secondary'),
      ],
    );
  }

  Widget _buildExtrusionSection(CanvasItem item) {
    final p = item.paint;
    return Column(
      children: [
        const Text('Creates a faux-3D block shadow by repeatedly stacking the shape.', style: TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 12),
        _buildNumberRow('Depth (Layers)', p.extrusionSteps.toDouble(), (v) => _applyPaint(item, p.copyWith(extrusionSteps: v.toInt()))),
        _buildNumberRow('Y-Axis Drop', p.extrusionOffset.dy, (v) => _applyPaint(item, p.copyWith(extrusionOffset: Offset(p.extrusionOffset.dx, v)))),
      ],
    );
  }

  void _applyPaint(CanvasItem item, CanvasPaint newPaint) {
    if (item is RectItem) {
      _updateItem(RectItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: newPaint, rect: item.rect), item);
    } else if (item is RRectItem) {
      _updateItem(RRectItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: newPaint, rect: item.rect, radius: item.radius), item);
    } else if (item is OvalItem) {
      _updateItem(OvalItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: newPaint, rect: item.rect), item);
    } else if (item is PathItem) {
      _updateItem(PathItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: newPaint, nodes: item.nodes, isClosed: item.isClosed), item);
    } else if (item is TextItem) {
      _updateItem(TextItem(id: item.id, name: item.name, enabledIf: item.enabledIf, paint: newPaint, text: item.text, position: item.position, fontSize: item.fontSize, isBold: item.isBold), item);
    }
  }

  Widget _buildColorRow(String label, Color color, Function(Color) onSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          GestureDetector(
            onTap: () => _showColorPicker(label, color, onSelected),
            child: Container(
              width: 36, height: 24,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)),
            ),
          ),
          const SizedBox(width: 12),
          Text(_hexFromColor(color), style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildDropdownRow<T>(String label, T value, List<T> options, Function(T?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Expanded(
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white10)),
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: const Color(0xFF2D2D30),
                style: const TextStyle(fontSize: 12, color: Colors.white),
                items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt.toString().split('.').last))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStringRow(String label, String value, Function(String) onSubmitted, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Expanded(
            child: SizedBox(
              height: 30,
              child: TextFormField(
                key: ValueKey('${label}_$value'),
                initialValue: value,
                style: const TextStyle(fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.black26,
                ),
                onFieldSubmitted: onSubmitted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberRow(String label, double value, Function(double) onSubmitted) {
    return _buildStringRow(label, value.toStringAsFixed(1), (strVal) {
      final doubleVal = double.tryParse(strVal);
      if (doubleVal != null) onSubmitted(doubleVal);
    });
  }
}