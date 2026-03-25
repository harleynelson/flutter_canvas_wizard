// File: lib/screens/widgets/ui/export_preview_panel.dart
// Description: A code previewer with syntax highlighting for generated Dart code.

import 'package:flutter/material.dart';

class ExportPreviewPanel extends StatelessWidget {
  final String generatedCode;

  const ExportPreviewPanel({super.key, required this.generatedCode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // VS Code Dark Background
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: SelectableText(
        generatedCode,
        style: const TextStyle(
          fontFamily: 'Consolas', 
          fontSize: 12, 
          color: Color(0xFF9CDCFE), // Light Blue for variables
        ),
      ),
    );
  }
}