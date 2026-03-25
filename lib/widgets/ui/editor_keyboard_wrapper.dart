// File: lib/widgets/ui/editor_keyboard_wrapper.dart
// Description: A focus-trapping wrapper that feeds keyboard events to the HotkeyService.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/hotkey_service.dart';

class EditorKeyboardWrapper extends StatelessWidget {
  final Widget child;
  final HotkeyService hotkeyService;

  const EditorKeyboardWrapper({
    super.key,
    required this.child,
    required this.hotkeyService,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        final handled = hotkeyService.handleKeyEvent(event);
        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: child,
    );
  }
}