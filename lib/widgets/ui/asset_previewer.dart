// File: lib/widgets/ui/asset_previewer.dart
// Description: A specialized widget to preview the asset at different scales.

import 'package:flutter/material.dart';
import '../../models/canvas_item.dart';
import '../../models/editor/preview_context.dart';
import '../editor_canvas.dart';

class AssetPreviewer extends StatelessWidget {
  final List<CanvasItem> items;
  final PreviewContext context;

  const AssetPreviewer({
    super.key,
    required this.items,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(this.context.name, style: const TextStyle(fontSize: 10, color: Colors.white38)),
        const SizedBox(height: 8),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white10),
          ),
          child: ClipRect(
            child: CustomPaint(
              painter: EditorCanvasPainter(
                items: items, // Future: pass scale/strokeMultiplier to painter
                selectedItemId: null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}