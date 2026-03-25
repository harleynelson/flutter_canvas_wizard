// File: lib/widgets/ui/import_modal.dart
// Description: A code-entry dialog for importing existing Dart canvas logic.

import 'package:flutter/material.dart';

class ImportModal extends StatefulWidget {
  final Function(String) onImport;

  const ImportModal({super.key, required this.onImport});

  @override
  State<ImportModal> createState() => _ImportModalState();
}

class _ImportModalState extends State<ImportModal> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2D2D30),
      title: const Text('Import Canvas Logic', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 600,
        height: 400,
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.greenAccent),
          decoration: const InputDecoration(
            hintText: "Paste your static void _render... logic here",
            hintStyle: TextStyle(color: Colors.white24),
            border: OutlineInputBorder(),
            fillColor: Colors.black26,
            filled: true,
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onImport(_controller.text);
            Navigator.pop(context);
          },
          child: const Text('Process & Strip Logic'),
        ),
      ],
    );
  }
}