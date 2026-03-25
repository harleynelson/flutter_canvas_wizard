// File: lib/utils/library_search_utils.dart
// Description: Utility for filtering library items based on search queries.

import '../models/library/library_item.dart';

class LibrarySearchUtils {
  static List<LibraryItem> filter(List<LibraryItem> items, String query) {
    if (query.isEmpty) return items;
    
    final lowerQuery = query.toLowerCase();
    return items.where((item) {
      return item.name.toLowerCase().contains(lowerQuery) || 
             item.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}