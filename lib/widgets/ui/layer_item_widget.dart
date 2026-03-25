// File: lib/widgets/ui/layer_item_widget.dart
// Description: Reusable list item for the hierarchy panel.

import 'package:flutter/material.dart';

class LayerItemWidget extends StatelessWidget {
  final String name;
  final String type;
  final bool isSelected;
  final bool isVisible;
  final VoidCallback onTap;
  final VoidCallback onToggleVisibility;

  const LayerItemWidget({
    super.key,
    required this.name,
    required this.type,
    required this.isSelected,
    required this.isVisible,
    required this.onTap,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent,
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Icon(
          type == 'rect' ? Icons.check_box_outline_blank : Icons.gesture,
          size: 16,
          color: isSelected ? Colors.blueAccent : Colors.white38,
        ),
        title: Text(
          name,
          style: TextStyle(
            color: isVisible ? Colors.white : Colors.white24,
            fontSize: 13,
            decoration: isVisible ? null : TextDecoration.lineThrough,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            size: 16,
            color: Colors.white38,
          ),
          onPressed: onToggleVisibility,
        ),
      ),
    );
  }
}