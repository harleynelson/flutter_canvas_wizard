// File: lib/state/commands/editor_command.dart
// Description: Abstract base for the Command pattern to support Undo/Redo.

abstract class EditorCommand {
  /// Execute the action
  void execute();
  
  /// Reverse the action exactly as it was
  void undo();
  
  /// Human-readable name for the Undo history (e.g., "Move Rectangle")
  String get label;
}

class CommandHistory {
  final List<EditorCommand> _undoStack = [];
  final List<EditorCommand> _redoStack = [];

  void execute(EditorCommand command) {
    try {
      command.execute();
      _undoStack.add(command);
      _redoStack.clear(); // Executing a new command clears the forward history
    } catch (e) {
      print('DEBUG ERROR: Command execution failed: $e');
    }
  }

  void undo() {
    if (_undoStack.isNotEmpty) {
      final cmd = _undoStack.removeLast();
      cmd.undo();
      _redoStack.add(cmd);
    }
  }
}