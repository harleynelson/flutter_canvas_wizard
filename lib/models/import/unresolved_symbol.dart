// File: lib/models/import/unresolved_symbol.dart
// Description: Represents a variable or logic block the importer couldn't resolve automatically.

import 'package:flutter/material.dart';

enum SymbolType { color, number, offset }

class UnresolvedSymbol {
  final String name;
  final SymbolType type;
  final String contextSnippet; // The line of code it appeared in
  dynamic resolvedValue;

  UnresolvedSymbol({
    required this.name, 
    required this.type, 
    required this.contextSnippet,
    this.resolvedValue,
  });
}