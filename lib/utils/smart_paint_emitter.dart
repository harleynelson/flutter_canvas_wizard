// File: lib/utils/smart_paint_emitter.dart
// Description: Formats Paint declarations using Dart's method cascades, now supporting advanced stroke and blend properties.

import 'dart:ui';
import '../models/canvas_item.dart';
import '../models/export/dart_style_options.dart';

class SmartPaintEmitter {
  static String format(CanvasPaint p, DartStyleOptions options) {
    try {
      if (!options.useCascades) return "// Fallback non-cascade logic here";

      final List<String> lines = [];
      
      // Base Color / Parameter override
      if (p.fillColorParam != null) {
        lines.add("..color = ${p.fillColorParam}");
      } else {
        final colorHex = "0x${p.fillColor.value.toRadixString(16).toUpperCase()}";
        lines.add("..color = ${options.preferConst ? 'const ' : ''}Color($colorHex)");
      }

      // Stroke Logic
      if (p.strokeWidth > 0) {
        lines.add("..style = PaintingStyle.stroke");
        lines.add("..strokeWidth = ${p.strokeWidth}");
        lines.add("..strokeCap = StrokeCap.${p.strokeCap.name}");
      }

      // Blend Mode
      if (p.blendMode != BlendMode.srcOver) {
        lines.add("..blendMode = BlendMode.${p.blendMode.name}");
      }

      return "Paint()${lines.join('\n  ')};";
    } catch (e) {
      print('DEBUG ERROR: SmartPaintEmitter failed: $e');
      return "Paint(); // Export Error";
    }
  }
}