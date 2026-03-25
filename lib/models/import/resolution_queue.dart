// File: lib/services/import/resolution_queue.dart
// Description: Manages the list of conflicts that need user intervention during import.

import 'unresolved_symbol.dart';

class ResolutionQueue {
  final List<UnresolvedSymbol> _conflicts = [];

  void addConflict(UnresolvedSymbol symbol) {
    // Avoid duplicates if the same variable is used multiple times
    if (!_conflicts.any((s) => s.name == symbol.name)) {
      _conflicts.add(symbol);
    }
  }

  bool get isEmpty => _conflicts.isEmpty;
  List<UnresolvedSymbol> get conflicts => _conflicts;

  void resolve(String name, dynamic value) {
    final symbol = _conflicts.firstWhere((s) => s.name == name);
    symbol.resolvedValue = value;
  }
}