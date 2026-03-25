// File: lib/widgets/ui/history_toolbar.dart
// Description: Undo and Redo buttons with shortcut hint tooltips.

import 'package:flutter/material.dart';

class HistoryToolbar extends StatelessWidget {
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const HistoryToolbar({
    super.key,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.undo, size: 18),
          tooltip: 'Undo (Ctrl+Z)',
          onPressed: canUndo ? onUndo : null,
          color: canUndo ? Colors.white70 : Colors.white10,
        ),
        IconButton(
          icon: const Icon(Icons.redo, size: 18),
          tooltip: 'Redo (Ctrl+Y)',
          onPressed: canRedo ? onRedo : null,
          color: canRedo ? Colors.white70 : Colors.white10,
        ),
      ],
    );
  }
}