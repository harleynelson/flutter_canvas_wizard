// File: lib/state/history/change_command.dart
// Description: A command that records a state change for a specific CanvasItem.

import '../../models/canvas_item.dart';

abstract class EditorCommand {
  void execute();
  void undo();
  String get label;
}

class ItemChangeCommand implements EditorCommand {
  final String itemId;
  final CanvasItem oldState;
  final CanvasItem newState;
  final Function(CanvasItem) updateCallback;
  @override
  final String label;

  ItemChangeCommand({
    required this.itemId,
    required this.oldState,
    required this.newState,
    required this.updateCallback,
    required this.label,
  });

  @override
  void execute() => updateCallback(newState);

  @override
  void undo() => updateCallback(oldState);
}