// File: lib/services/import/import_scanner.dart
// Description: Scans Dart source code to extract drawing commands for Rect, RRect, Oval, Path, and Text items.

import 'dart:ui';
import '../../models/canvas_item.dart';
import '../../utils/path_reconstructor.dart';

class ImportScanner {
  /// Extracts RectItems, RRectItems, OvalItems, PathItems, and TextItems from a raw Dart string.
  static List<CanvasItem> extractItems(String source) {
    final List<CanvasItem> extracted = [];
    final defaultPaint = CanvasPaint(fillColor: const Color(0xFF7A8B8B)); // Default stone
    
    try {
      // 1. Extract RRect.fromRectAndRadius (Highest priority as it contains a Rect)
      final rrectPattern = RegExp(
        r"RRect\.fromRectAndRadius\(\s*Rect\.fromLTRB\(([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)\),\s*(?:const\s*)?Radius\.circular\(([-\d.]+)\)\s*\)",
      );
      for (final m in rrectPattern.allMatches(source)) {
        extracted.add(RRectItem(
          id: 'imp_rrect_${DateTime.now().microsecondsSinceEpoch}_${extracted.length}',
          name: 'Imported Rounded Rect',
          rect: Rect.fromLTRB(
            double.parse(m.group(1)!), double.parse(m.group(2)!),
            double.parse(m.group(3)!), double.parse(m.group(4)!)
          ),
          radius: double.parse(m.group(5)!),
          paint: defaultPaint,
        ));
      }

      // 2. Extract canvas.drawOval(Rect.fromLTRB(...))
      final ovalPattern = RegExp(
        r"canvas\.drawOval\(\s*Rect\.fromLTRB\(([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)\)",
      );
      for (final m in ovalPattern.allMatches(source)) {
        extracted.add(OvalItem(
          id: 'imp_oval_${DateTime.now().microsecondsSinceEpoch}_${extracted.length}',
          name: 'Imported Oval',
          rect: Rect.fromLTRB(
            double.parse(m.group(1)!), double.parse(m.group(2)!),
            double.parse(m.group(3)!), double.parse(m.group(4)!)
          ),
          paint: defaultPaint,
        ));
      }

      // 3. Extract Rect.fromCenter
      final rectCenterPattern = RegExp(
        r"Rect\.fromCenter\(center:\s*(?:const\s*)?Offset\(([-\d.]+),\s*([-\d.]+)\),\s*width:\s*([-\d.]+),\s*height:\s*([-\d.]+)\)",
      );
      for (final m in rectCenterPattern.allMatches(source)) {
        // Simple check to ensure we aren't re-importing a rect that was part of an RRect
        if (!source.contains(m.group(0)!)) continue; 

        extracted.add(RectItem(
          id: 'imp_rect_c_${DateTime.now().microsecondsSinceEpoch}_${extracted.length}',
          name: 'Imported Rect (Center)',
          rect: Rect.fromCenter(
            center: Offset(double.parse(m.group(1)!), double.parse(m.group(2)!)), 
            width: double.parse(m.group(3)!), 
            height: double.parse(m.group(4)!)
          ),
          paint: defaultPaint,
        ));
      }

      // 4. Extract Rect.fromLTRB
      final rectLTRBPattern = RegExp(
        r"Rect\.fromLTRB\(([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)\)",
      );
      for (final m in rectLTRBPattern.allMatches(source)) {
        // Prevent double-counting if the LTRB is nested inside a DrawOval or RRect call
        final fullMatch = m.group(0)!;
        bool isNested = extracted.any((item) {
          if (item is RRectItem) return item.rect.toString().contains(fullMatch);
          if (item is OvalItem) return item.rect.toString().contains(fullMatch);
          return false;
        });

        if (!isNested) {
          extracted.add(RectItem(
            id: 'imp_rect_l_${DateTime.now().microsecondsSinceEpoch}_${extracted.length}',
            name: 'Imported Rect (LTRB)',
            rect: Rect.fromLTRB(
              double.parse(m.group(1)!), double.parse(m.group(2)!),
              double.parse(m.group(3)!), double.parse(m.group(4)!)
            ),
            paint: defaultPaint,
          ));
        }
      }

      // 5. Extract Paths
      final pathPattern = RegExp(r"Path\(\)\s*((?:\.\.[a-zA-Z]+\([^\)]+\)\s*)+)");
      for (final m in pathPattern.allMatches(source)) {
        final pathBody = m.group(1)!;
        final nodes = PathReconstructor.parsePathBody(pathBody);
        if (nodes.isNotEmpty) {
          extracted.add(PathItem(
            id: 'imp_path_${DateTime.now().microsecondsSinceEpoch}_${extracted.length}',
            name: 'Imported Path',
            nodes: nodes,
            isClosed: pathBody.contains('..close()'),
            paint: defaultPaint,
          ));
        }
      }

      // 6. Extract TextItems
      final textPattern = RegExp(
        r"TextSpan\(\s*text:\s*'((?:\\'|[^'])+)'[\s\S]*?\.paint\(\s*canvas,\s*(?:const\s*)?Offset\(\s*([-\d.]+),\s*([-\d.]+)\s*\)\s*\);",
      );
      for (final m in textPattern.allMatches(source)) {
        // Unescape quotes for the imported text
        final rawText = m.group(1)!.replaceAll(r"\'", "'");
        final dx = double.parse(m.group(2)!);
        final dy = double.parse(m.group(3)!);

        // Prevent duplicating text if the exporter generated both a fill and stroke painter for the same item
        bool isDuplicate = extracted.any((item) => 
          item is TextItem && 
          item.text == rawText && 
          (item.position.dx - dx).abs() < 0.1 && 
          (item.position.dy - dy).abs() < 0.1
        );
        
        if (isDuplicate) continue;

        // Look backwards slightly to find fontSize or bold properties from the TextStyle
        double fontSize = 24.0;
        bool isBold = false;
        
        final matchStart = m.start;
        final lookbackStart = matchStart > 300 ? matchStart - 300 : 0;
        final lookbackText = source.substring(lookbackStart, matchStart);
        
        final fontMatch = RegExp(r"fontSize:\s*([-\d.]+)").firstMatch(lookbackText);
        if (fontMatch != null) {
          fontSize = double.tryParse(fontMatch.group(1)!) ?? 24.0;
        }
        
        if (lookbackText.contains("FontWeight.bold")) {
          isBold = true;
        }

        extracted.add(TextItem(
          id: 'imp_text_${DateTime.now().microsecondsSinceEpoch}_${extracted.length}',
          name: 'Imported Text',
          text: rawText,
          position: Offset(dx, dy),
          fontSize: fontSize,
          isBold: isBold,
          paint: CanvasPaint(fillColor: const Color(0xFFFFFFFF)), // default white text for imports
        ));
      }

    } catch (e) {
      print('DEBUG ERROR: ImportScanner extraction failed: $e');
    }

    return extracted;
  }
}