// File: lib/models/library/library_item.dart
// Description: A model representing a reusable group of shapes saved in the Asset Library.

import '../canvas_item.dart';

class LibraryItem {
  final String id;
  final String name;
  final String category; // e.g., "Shrine", "Lighthouse", "Nature"
  final List<CanvasItem> components;
  final DateTime createdAt;

  LibraryItem({
    required this.id,
    required this.name,
    this.category = 'General',
    required this.components,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'components': components.map((c) => c.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    return LibraryItem(
      id: json['id'],
      name: json['name'],
      category: json['category'] ?? 'General',
      createdAt: DateTime.parse(json['createdAt']),
      components: (json['components'] as List)
          .map((c) => CanvasItem.fromJson(c))
          .toList(),
    );
  }
}