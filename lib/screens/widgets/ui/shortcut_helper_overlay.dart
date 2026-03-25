// File: lib/screens/widgets/ui/shortcut_helper_overlay.dart
// Description: Reusable visual helper to display contextual keyboard shortcuts to the user based on selection state.

import 'package:flutter/material.dart';
import 'shortcut_hint.dart';

class ShortcutHelperOverlay extends StatelessWidget {
  final int selectedCount;
  final bool isTransformMode;

  const ShortcutHelperOverlay({
    super.key,
    required this.selectedCount,
    required this.isTransformMode,
  });

  @override
  Widget build(BuildContext context) {
    try {
      if (selectedCount == 0) return const SizedBox.shrink();

      return Positioned(
        bottom: 24,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Wrap(
              spacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (isTransformMode) ...[
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShortcutHint(text: 'Shift'),
                      SizedBox(width: 8),
                      Text('Scale proportionally', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
                if (selectedCount > 1) ...[
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShortcutHint(text: 'Shift'),
                      SizedBox(width: 4),
                      Text('+', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      SizedBox(width: 4),
                      ShortcutHint(text: 'G'),
                      SizedBox(width: 8),
                      Text('Group objects', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print('DEBUG ERROR: ShortcutHelperOverlay.build failed: $e');
      return const SizedBox.shrink();
    }
  }
}