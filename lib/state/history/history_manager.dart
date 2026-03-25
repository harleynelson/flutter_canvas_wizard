// File: lib/state/history/history_manager.dart
// Description: Riverpod provider that manages undo/redo stacks and exposes UI state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../commands/editor_command.dart';

class HistoryState {
  final bool canUndo;
  final bool canRedo;
  HistoryState({this.canUndo = false, this.canRedo = false});
}

class HistoryManager extends Notifier<HistoryState> {
  final List<EditorCommand> _undoStack = [];
  final List<EditorCommand> _redoStack = [];
  final int maxHistory = 50;

  @override
  HistoryState build() {
    return HistoryState();
  }

  void execute(EditorCommand command) {
    try {
      command.execute();
      _undoStack.add(command);
      _redoStack.clear();
      
      // Prevent memory leaks by capping the history
      if (_undoStack.length > maxHistory) {
        _undoStack.removeAt(0);
      }
      _updateState();
    } catch (e) {
      print('DEBUG ERROR: Failed to execute command: $e');
    }
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    try {
      final cmd = _undoStack.removeLast();
      cmd.undo();
      _redoStack.add(cmd);
      _updateState();
    } catch (e) {
      print('DEBUG ERROR: Failed to undo: $e');
    }
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    try {
      final cmd = _redoStack.removeLast();
      cmd.execute();
      _undoStack.add(cmd);
      _updateState();
    } catch (e) {
      print('DEBUG ERROR: Failed to redo: $e');
    }
  }

  void _updateState() {
    state = HistoryState(
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
    );
  }
}

final historyProvider = NotifierProvider<HistoryManager, HistoryState>(() {
  return HistoryManager();
});