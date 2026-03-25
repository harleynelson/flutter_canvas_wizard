// File: lib/widgets/ui/canvas_tool_button.dart
// Description: A reusable, styled icon button for editor toolbars.

import 'package:flutter/material.dart';

class CanvasToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const CanvasToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
              border: Border.all(
                color: isActive ? Colors.blueAccent : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isActive ? Colors.blueAccent : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}