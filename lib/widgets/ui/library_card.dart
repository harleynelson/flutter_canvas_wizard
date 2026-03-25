// File: lib/widgets/ui/library_card.dart
// Description: A visual tile for the asset library drawer.

import 'package:flutter/material.dart';

import '../../models/library/library_item.dart';
import '../editor_canvas.dart';

class LibraryCard extends StatelessWidget {
  final LibraryItem item;
  final VoidCallback onImport;

  const LibraryCard({super.key, required this.item, required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF3E3E42),
      child: InkWell(
        onTap: onImport,
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black26,
                child: CustomPaint(
                  painter: EditorCanvasPainter(
                    items: item.components,
                    selectedItemId: null,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                item.name,
                style: const TextStyle(fontSize: 10, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}