// File: lib/services/library_storage_service.dart
// Description: Handles saving and loading LibraryItems to the local file system.

import 'dart:convert';
import 'dart:io';
import '../models/library/library_item.dart';

class LibraryStorageService {
  final String libraryPath;

  LibraryStorageService({required this.libraryPath});

  Future<void> saveItem(LibraryItem item) async {
    try {
      final directory = Directory(libraryPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = File('$libraryPath/${item.id}.json');
      await file.writeAsString(jsonEncode(item.toJson()));
    } catch (e) {
      print('DEBUG ERROR: Failed to save library item: $e');
    }
  }

  Future<List<LibraryItem>> loadAllItems() async {
    final List<LibraryItem> items = [];
    try {
      final directory = Directory(libraryPath);
      if (await directory.exists()) {
        final List<FileSystemEntity> files = directory.listSync();
        for (var file in files) {
          if (file is File && file.path.endsWith('.json')) {
            final content = await file.readAsString();
            items.add(LibraryItem.fromJson(jsonDecode(content)));
          }
        }
      }
    } catch (e) {
      print('DEBUG ERROR: Failed to load library: $e');
    }
    return items;
  }
}