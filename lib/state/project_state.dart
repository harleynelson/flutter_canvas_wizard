// File: lib/state/project_state.dart
// Description: State management for the current project workspace, handling items, parameters, and serialization.

import 'package:flutter/material.dart';
import '../models/canvas_item.dart';

class ProjectState extends ChangeNotifier {
  List<CanvasItem> items = [];
  List<ExportParameter> parameters = [];
  String? selectedItemId;

  // --- Getters ---
  
  CanvasItem? get selectedItem {
    try {
      return items.firstWhere((item) => item.id == selectedItemId);
    } catch (e) {
      return null; // firstWhere throws if no element is found
    }
  }

  // --- Actions ---

  void addItem(CanvasItem item) {
    items.add(item);
    notifyListeners();
  }

  void removeItem(String id) {
    items.removeWhere((item) => item.id == id);
    if (selectedItemId == id) {
      selectedItemId = null;
    }
    notifyListeners();
  }

  void updateItem() {
    // Call this after mutating a property on an existing item 
    // (e.g., changing a color or dragging a node) to trigger a UI repaint.
    notifyListeners();
  }

  void selectItem(String? id) {
    selectedItemId = id;
    notifyListeners();
  }

  void addParameter(ExportParameter param) {
    parameters.add(param);
    notifyListeners();
  }

  void removeParameter(String name) {
    parameters.removeWhere((p) => p.name == name);
    // Future enhancement: if a parameter is removed, check if any CanvasPaint 
    // objects are using it and reset them to a static color.
    notifyListeners();
  }

  // --- Serialization ---

  Map<String, dynamic> toJson() {
    try {
      return {
        'parameters': parameters.map((p) => p.toJson()).toList(),
        'items': items.map((i) => i.toJson()).toList(),
      };
    } catch (e) {
      print('DEBUG ERROR: ProjectState.toJson failed: $e');
      return {};
    }
  }

  void loadFromJson(Map<String, dynamic> json) {
    try {
      // Clear current workspace
      items.clear();
      parameters.clear();
      selectedItemId = null;

      // Load Parameters
      if (json['parameters'] != null) {
        final paramsList = json['parameters'] as List;
        for (var p in paramsList) {
          parameters.add(ExportParameter.fromJson(p as Map<String, dynamic>));
        }
      }

      // Load Items
      if (json['items'] != null) {
        final itemsList = json['items'] as List;
        for (var i in itemsList) {
          items.add(CanvasItem.fromJson(i as Map<String, dynamic>));
        }
      }

      notifyListeners();
    } catch (e) {
      print('DEBUG ERROR: ProjectState.loadFromJson failed: $e');
    }
  }
}