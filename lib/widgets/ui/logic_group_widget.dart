// File: lib/widgets/ui/logic_group_widget.dart
// Description: A UI wrapper that represents a conditional code block (like an IF statement).

import 'package:flutter/material.dart';

class LogicGroupWidget extends StatelessWidget {
  final String condition; // e.g., "tier >= 2"
  final List<Widget> children;
  final VoidCallback onRemove;

  const LogicGroupWidget({
    super.key,
    required this.condition,
    required this.children,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
        color: Colors.orangeAccent.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.orangeAccent.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.code, size: 14, color: Colors.orangeAccent),
                const SizedBox(width: 8),
                Text("if ($condition)", style: const TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(onTap: onRemove, child: const Icon(Icons.close, size: 12, color: Colors.white24)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}