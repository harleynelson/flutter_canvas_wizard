// File: lib/state/commands/workspace_commands.dart
// Description: Concrete command implementations for Workspace actions (Add, Remove, Update).

import '../../models/canvas_item.dart';
import '../workspace_provider.dart';
import 'editor_command.dart';

class AddCommand implements EditorCommand {
  final CanvasItem item;
  final String? parentId;
  final WorkspaceNotifier notifier;
  @override
  final String label = "Add Item";

  AddCommand(this.item, this.parentId, this.notifier);

  @override
  void execute() {
    try {
      notifier.addItem(item);
      if (parentId != null) {
        notifier.reparentItem(item.id, parentId);
      }
      notifier.selectItem(item.id);
    } catch(e) {
      print('DEBUG ERROR: AddCommand execute failed: $e');
    }
  }

  @override
  void undo() {
    try {
      notifier.removeItem(item.id);
    } catch(e) {
      print('DEBUG ERROR: AddCommand undo failed: $e');
    }
  }
}

class RemoveCommand implements EditorCommand {
  final CanvasItem item;
  final String? parentId;
  final WorkspaceNotifier notifier;
  @override
  final String label = "Remove Item";

  RemoveCommand(this.item, this.parentId, this.notifier);

  @override
  void execute() {
    try {
      notifier.removeItem(item.id);
    } catch(e) {
      print('DEBUG ERROR: RemoveCommand execute failed: $e');
    }
  }

  @override
  void undo() {
    try {
      notifier.addItem(item); // Note: addItem appends to root.
      if (parentId != null) {
        notifier.reparentItem(item.id, parentId);
      }
      notifier.selectItem(item.id);
    } catch(e) {
      print('DEBUG ERROR: RemoveCommand undo failed: $e');
    }
  }
}

class UpdateCommand implements EditorCommand {
  final CanvasItem oldItem;
  final CanvasItem newItem;
  final WorkspaceNotifier notifier;
  @override
  final String label = "Update Item";

  UpdateCommand(this.oldItem, this.newItem, this.notifier);

  @override
  void execute() {
    try {
      notifier.updateItem(newItem);
    } catch(e) {
      print('DEBUG ERROR: UpdateCommand execute failed: $e');
    }
  }

  @override
  void undo() {
    try {
      notifier.updateItem(oldItem);
      notifier.selectItem(oldItem.id);
    } catch(e) {
      print('DEBUG ERROR: UpdateCommand undo failed: $e');
    }
  }
}