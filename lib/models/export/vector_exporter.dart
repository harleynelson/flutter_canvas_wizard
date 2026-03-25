// File: lib/models/export/vector_exporter.dart
// Description: Orchestrates the conversion of the entire project into a single Dart file string, supporting recursive group exports.

import 'code_template.dart';
import '../../utils/dart_emitter.dart';
import '../canvas_item.dart';

class VectorExporter {
  static String exportProject({
    required List<CanvasItem> items,
    required CodeTemplate template,
    bool isSimple = false,
  }) {
    try {
      final bodyBuffer = StringBuffer();

      for (var item in items) {
        // Only export top-level visible items; DartEmitter handles children recursively
        if (item.isVisible) {
          bodyBuffer.writeln(DartEmitter.emit(item));
        }
      }

      final String finalBody = bodyBuffer.toString();

      if (isSimple) {
        return finalBody;
      }

      return template.wrapInBoilerplate(finalBody);
    } catch (e) {
      print('DEBUG ERROR: VectorExporter.exportProject failed: $e');
      return "// Export failed: $e";
    }
  }
}