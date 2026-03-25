// File: lib/widgets/ui/conflict_resolver_dialog.dart
// Description: A step-through UI for resolving unknown code variables.

import 'package:flutter/material.dart';
import '../../models/import/unresolved_symbol.dart';

class ConflictResolverDialog extends StatefulWidget {
  final List<UnresolvedSymbol> conflicts;
  final Function(Map<String, dynamic>) onComplete;

  const ConflictResolverDialog({
    super.key, 
    required this.conflicts, 
    required this.onComplete
  });

  @override
  State<ConflictResolverDialog> createState() => _ConflictResolverDialogState();
}

class _ConflictResolverDialogState extends State<ConflictResolverDialog> {
  final Map<String, dynamic> _results = {};
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final current = widget.conflicts[_currentIndex];

    return AlertDialog(
      title: Text('Resolve: ${current.name}', style: const TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Context: "... ${current.contextSnippet} ..."', 
               style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          if (current.type == SymbolType.color)
            const Text("This looks like a Color. Pick a fallback:"),
            // Integration: Drop your ColorPicker here
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            if (_currentIndex < widget.conflicts.length - 1) {
              setState(() => _currentIndex++);
            } else {
              widget.onComplete(_results);
              Navigator.pop(context);
            }
          },
          child: Text(_currentIndex == widget.conflicts.length - 1 ? 'Finish' : 'Next'),
        )
      ],
    );
  }
}