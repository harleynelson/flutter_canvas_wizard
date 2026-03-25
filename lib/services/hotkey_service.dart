// File: lib/services/hotkey_service.dart
// Description: Manages the registry of shortcuts and dispatches events to the active tool.

import 'package:flutter/services.dart';
import '../models/editor/shortcut_action.dart';

class HotkeyService {
  final List<ShortcutAction> _registry = [];

  void register(ShortcutAction action) {
    _registry.add(action);
  }

  void clear() => _registry.clear();

  /// Processes a keyboard event and returns true if a shortcut was handled.
  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    try {
      for (var action in _registry) {
        if (action.matches(event)) {
          action.onTrigger();
          return true; // Stop propagation
        }
      }
    } catch (e) {
      print('DEBUG ERROR: Hotkey dispatch failed: $e');
    }
    return false;
  }
}