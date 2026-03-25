// File: lib/models/editor/shortcut_action.dart
// Description: Defines a keyboard shortcut and its associated editor action.

import 'package:flutter/services.dart';

class ShortcutAction {
  final LogicalKeyboardKey key;
  final bool ctrl;
  final bool shift;
  final bool alt;
  final String label;
  final VoidCallback onTrigger;

  ShortcutAction({
    required this.key,
    required this.onTrigger,
    required this.label,
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
  });

  /// Checks if the current raw keyboard event matches this shortcut.
  bool matches(KeyEvent event) {
    final bool keyMatch = event.logicalKey == key;
    final bool ctrlMatch = HardwareKeyboard.instance.isControlPressed == ctrl;
    final bool shiftMatch = HardwareKeyboard.instance.isShiftPressed == shift;
    final bool altMatch = HardwareKeyboard.instance.isAltPressed == alt;

    return keyMatch && ctrlMatch && shiftMatch && altMatch;
  }
}