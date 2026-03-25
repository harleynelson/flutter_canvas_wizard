// File: lib/state/workspace_provider.dart
// Description: Riverpod immutable state management for the canvas editor workspace, updated for multi-selection capabilities.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/canvas_item.dart';

enum DropPosition { above, into, below }

class WorkspaceState {
  final List<CanvasItem> items;
  final List<ExportParameter> parameters;
  final Set<String> selectedItemIds; // NEW: Multi-selection set
  
  // Enterprise Editor Settings
  final bool snapToGrid;
  final double gridSnapSize;
  final bool isTransformMode;
  
  // Global Editor Variables for evaluating enabledIf conditions
  final Map<String, double> variables;

  WorkspaceState({
    this.items = const [],
    this.parameters = const [],
    this.selectedItemIds = const {},
    this.snapToGrid = true,
    this.gridSnapSize = 10.0,
    this.isTransformMode = false,
    this.variables = const {'stage': 1.0},
  });

  WorkspaceState copyWith({
    List<CanvasItem>? items,
    List<ExportParameter>? parameters,
    Set<String>? selectedItemIds,
    bool clearSelection = false,
    bool? snapToGrid,
    double? gridSnapSize,
    bool? isTransformMode,
    Map<String, double>? variables,
  }) {
    return WorkspaceState(
      items: items ?? this.items,
      parameters: parameters ?? this.parameters,
      selectedItemIds: clearSelection ? {} : (selectedItemIds ?? this.selectedItemIds),
      snapToGrid: snapToGrid ?? this.snapToGrid,
      gridSnapSize: gridSnapSize ?? this.gridSnapSize,
      isTransformMode: isTransformMode ?? this.isTransformMode,
      variables: variables ?? this.variables,
    );
  }
}

class WorkspaceNotifier extends Notifier<WorkspaceState> {
  @override
  WorkspaceState build() {
    return WorkspaceState();
  }

  // Helper to get the first selected item for legacy single-item commands
  CanvasItem? get selectedItem {
    if (state.selectedItemIds.isEmpty) return null;
    final firstId = state.selectedItemIds.first;
    
    CanvasItem? findRecursive(List<CanvasItem> list, String id) {
      for (var item in list) {
        if (item.id == id) return item;
        if (item is LogicGroupItem) {
          final found = findRecursive(item.children, id);
          if (found != null) return found;
        }
      }
      return null;
    }
    
    return findRecursive(state.items, firstId);
  }

  // Get all currently selected items
  List<CanvasItem> get selectedItems {
    if (state.selectedItemIds.isEmpty) return [];
    List<CanvasItem> found = [];
    
    void findRecursive(List<CanvasItem> list) {
      for (var item in list) {
        if (state.selectedItemIds.contains(item.id)) found.add(item);
        if (item is LogicGroupItem) findRecursive(item.children);
      }
    }
    
    findRecursive(state.items);
    return found;
  }

  void addItem(CanvasItem item) {
    try {
      state = state.copyWith(items: [...state.items, item]);
    } catch (e) {
      print('DEBUG ERROR: WorkspaceNotifier.addItem failed: $e');
    }
  }

  // Updated to support multi-select toggling via shift-click
  void selectItem(String? id, {bool multi = false}) {
    try {
      if (id == null) {
        state = state.copyWith(clearSelection: true);
        return;
      }

      if (multi) {
        final newSelection = Set<String>.from(state.selectedItemIds);
        if (newSelection.contains(id)) {
          newSelection.remove(id);
        } else {
          newSelection.add(id);
        }
        state = state.copyWith(selectedItemIds: newSelection);
      } else {
        state = state.copyWith(selectedItemIds: {id});
      }
    } catch (e) {
      print('DEBUG ERROR: WorkspaceNotifier.selectItem failed: $e');
    }
  }
  
  void selectItems(Set<String> ids) {
    state = state.copyWith(selectedItemIds: ids);
  }

  void updateItem(CanvasItem updatedItem) {
    try {
      List<CanvasItem> updateRecursive(List<CanvasItem> list) {
        return list.map((item) {
          if (item.id == updatedItem.id) return updatedItem;
          if (item is LogicGroupItem) {
            return LogicGroupItem(
              id: item.id,
              name: item.name,
              isVisible: item.isVisible,
              enabledIf: item.enabledIf, // Passed down
              paint: item.paint,
              condition: item.condition,
              children: updateRecursive(item.children),
            );
          }
          return item;
        }).toList();
      }

      state = state.copyWith(items: updateRecursive(state.items));
    } catch (e) {
      print('DEBUG ERROR: WorkspaceNotifier.updateItem failed: $e');
    }
  }

  void moveItemRelative(String itemId, String targetId, DropPosition pos) {
    try {
      if (itemId == targetId) return;

      CanvasItem? itemToMove;

      // First, extract the item
      List<CanvasItem> extractRecursive(List<CanvasItem> list) {
        List<CanvasItem> result = [];
        for (var item in list) {
          if (item.id == itemId) {
            itemToMove = item;
          } else if (item is LogicGroupItem) {
            result.add(LogicGroupItem(
              id: item.id, name: item.name, isVisible: item.isVisible,
              enabledIf: item.enabledIf, paint: item.paint,
              condition: item.condition, children: extractRecursive(item.children),
            ));
          } else {
            result.add(item);
          }
        }
        return result;
      }

      var newItems = extractRecursive(state.items);
      if (itemToMove == null) return;

      bool inserted = false;

      // Second, inject it at the correct relative location
      List<CanvasItem> insertRecursive(List<CanvasItem> list) {
        List<CanvasItem> result = [];
        for (var item in list) {
          if (item.id == targetId) {
            if (pos == DropPosition.above) {
              result.add(itemToMove!);
              result.add(item);
              inserted = true;
            } else if (pos == DropPosition.below) {
              result.add(item);
              result.add(itemToMove!);
              inserted = true;
            } else if (pos == DropPosition.into) {
              if (item is LogicGroupItem) {
                result.add(LogicGroupItem(
                  id: item.id, name: item.name, isVisible: item.isVisible,
                  enabledIf: item.enabledIf, paint: item.paint,
                  condition: item.condition, children: [...item.children, itemToMove!],
                ));
              } else {
                // Combine into a new logic group automatically
                result.add(LogicGroupItem(
                  id: 'group_${DateTime.now().millisecondsSinceEpoch}',
                  name: 'New Group',
                  isVisible: true,
                  paint: CanvasPaint(),
                  condition: 'true',
                  children: [item, itemToMove!],
                ));
              }
              inserted = true;
            }
          } else if (item is LogicGroupItem) {
            result.add(LogicGroupItem(
              id: item.id, name: item.name, isVisible: item.isVisible,
              enabledIf: item.enabledIf, paint: item.paint,
              condition: item.condition, children: insertRecursive(item.children),
            ));
          } else {
            result.add(item);
          }
        }
        return result;
      }

      newItems = insertRecursive(newItems);
      
      // Fallback if target lost
      if (!inserted) {
        newItems.add(itemToMove!);
      }

      state = state.copyWith(items: newItems);
    } catch (e) {
      print('DEBUG ERROR: WorkspaceNotifier.moveItemRelative failed: $e');
    }
  }

  void reparentItem(String itemId, String? targetGroupId) {
    try {
      CanvasItem? itemToMove;

      List<CanvasItem> extractRecursive(List<CanvasItem> list) {
        List<CanvasItem> result = [];
        for (var item in list) {
          if (item.id == itemId) {
            itemToMove = item;
          } else if (item is LogicGroupItem) {
            result.add(LogicGroupItem(
              id: item.id, name: item.name, isVisible: item.isVisible,
              enabledIf: item.enabledIf, paint: item.paint, condition: item.condition, 
              children: extractRecursive(item.children),
            ));
          } else {
            result.add(item);
          }
        }
        return result;
      }

      var newItems = extractRecursive(state.items);
      if (itemToMove == null) return;

      if (targetGroupId == null) {
        newItems.add(itemToMove!);
      } else {
        List<CanvasItem> insertRecursive(List<CanvasItem> list) {
          return list.map((item) {
            if (item.id == targetGroupId && item is LogicGroupItem) {
              return LogicGroupItem(
                id: item.id, name: item.name, isVisible: item.isVisible,
                enabledIf: item.enabledIf, paint: item.paint, condition: item.condition, 
                children: [...item.children, itemToMove!],
              );
            } else if (item is LogicGroupItem) {
              return LogicGroupItem(
                id: item.id, name: item.name, isVisible: item.isVisible,
                enabledIf: item.enabledIf, paint: item.paint, condition: item.condition, 
                children: insertRecursive(item.children),
              );
            }
            return item;
          }).toList();
        }
        newItems = insertRecursive(newItems);
      }

      state = state.copyWith(items: newItems);
    } catch (e) {
      print('DEBUG ERROR: WorkspaceNotifier.reparentItem failed: $e');
    }
  }

  String? getParentId(String itemId) {
    try {
      String? findParent(List<CanvasItem> list, String? currentParentId) {
        for (var item in list) {
          if (item.id == itemId) return currentParentId;
          if (item is LogicGroupItem) {
            final found = findParent(item.children, item.id);
            if (found != null) return found;
          }
        }
        return null;
      }
      return findParent(state.items, null);
    } catch (e) {
      print('DEBUG ERROR: WorkspaceNotifier.getParentId failed: $e');
      return null;
    }
  }

  void removeItem(String id) {
    try {
      List<CanvasItem> removeRecursive(List<CanvasItem> list) {
        List<CanvasItem> result = [];
        for (var item in list) {
          if (item.id == id) continue;
          if (item is LogicGroupItem) {
            result.add(LogicGroupItem(
              id: item.id, name: item.name, isVisible: item.isVisible,
              enabledIf: item.enabledIf, paint: item.paint, condition: item.condition, 
              children: removeRecursive(item.children),
            ));
          } else {
            result.add(item);
          }
        }
        return result;
      }

      final newItems = removeRecursive(state.items);
      final newSelection = Set<String>.from(state.selectedItemIds)..remove(id);
      
      state = state.copyWith(
        items: newItems,
        selectedItemIds: newSelection,
      );
    } catch (e) {
      print('DEBUG ERROR: WorkspaceNotifier.removeItem failed: $e');
    }
  }

  void toggleGridSnap() => state = state.copyWith(snapToGrid: !state.snapToGrid);

  void setGridSnapSize(double size) => state = state.copyWith(gridSnapSize: size);

  void toggleTransformMode() => state = state.copyWith(isTransformMode: !state.isTransformMode);

  void setVariable(String name, double value) {
    try {
      final newVars = Map<String, double>.from(state.variables);
      newVars[name] = value;
      state = state.copyWith(variables: newVars);
    } catch (e) {
      print('DEBUG ERROR: WorkspaceNotifier.setVariable failed: $e');
    }
  }
}

final workspaceProvider = NotifierProvider<WorkspaceNotifier, WorkspaceState>(() {
  return WorkspaceNotifier();
});