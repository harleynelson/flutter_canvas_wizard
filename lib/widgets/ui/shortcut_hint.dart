// File: lib/widgets/ui/shortcut_hint.dart
// Description: A small, styled visual representation of a keyboard key.

import 'package:flutter/material.dart';

class ShortcutHint extends StatelessWidget {
  final String text;

  const ShortcutHint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF454545),
        borderRadius: BorderRadius.circular(3),
        border: const Border(
          bottom: BorderSide(color: Colors.black, width: 2),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}