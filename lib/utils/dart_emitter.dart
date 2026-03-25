// File: lib/utils/dart_emitter.dart
// Description: Converts high-level CanvasItems into raw Flutter drawing commands. Now accurately separates Fill and Stroke passes and supports blend modes and variable overrides.

import 'dart:ui';
import '../models/canvas_item.dart';

class DartEmitter {
  static String emit(CanvasItem item, {String indent = ""}) {
    final buffer = StringBuffer();
    
    try {
      String blockIndent = indent;
      bool hasCondition = item.enabledIf != null && item.enabledIf!.trim().isNotEmpty;
      
      if (hasCondition) {
        buffer.writeln("$indent// Item Condition: ${item.name}");
        buffer.writeln("${indent}if (${item.enabledIf}) {");
        blockIndent = "$indent  "; 
      }

      if (item is LogicGroupItem) {
        buffer.writeln("$blockIndent// Group: ${item.name}");
        for (var child in item.children) {
          if (child.isVisible) {
            buffer.write(emit(child, indent: blockIndent));
          }
        }
      } else {
        final p = item.paint;
        buffer.writeln("$blockIndent// ${item.name}");

        final bool hasFill = p.fillColor != const Color(0x00000000) || p.fillColorParam != null;
        final bool hasStroke = p.strokeWidth > 0;
        final String blendModeStr = p.blendMode != BlendMode.srcOver ? "..blendMode = BlendMode.${p.blendMode.name}" : "";

        // --- TEXT ITEM EXPORT LOGIC ---
        if (item is TextItem) {
          final fontWeightStr = item.isBold ? "FontWeight.bold" : "FontWeight.normal";
          final textVar = "${item.id.replaceAll(RegExp(r'[^a-zA-Z]'), '')}Painter";
          
          // Fill Text
          if (hasFill) {
            final colorStr = p.fillColorParam ?? "const Color(0x${p.fillColor.value.toRadixString(16).toUpperCase()})";
            buffer.writeln("${blockIndent}final ${textVar}Style = TextStyle(");
            buffer.writeln("$blockIndent  color: $colorStr,");
            buffer.writeln("$blockIndent  fontSize: ${item.fontSize},");
            buffer.writeln("$blockIndent  fontWeight: $fontWeightStr,");
            buffer.writeln("$blockIndent);");
            
            buffer.writeln("${blockIndent}final $textVar = TextPainter(");
            buffer.writeln("$blockIndent  text: TextSpan(text: '${item.text.replaceAll("'", "\\'")}', style: ${textVar}Style),");
            buffer.writeln("$blockIndent  textDirection: TextDirection.ltr,");
            buffer.writeln("$blockIndent);");
            buffer.writeln("${blockIndent}$textVar.layout();");
            buffer.writeln("${blockIndent}$textVar.paint(canvas, const Offset(${item.position.dx}, ${item.position.dy}));");
          }
          
          // Stroke Text
          if (hasStroke) {
            final strokeColorStr = p.strokeColorParam ?? "const Color(0x${p.strokeColor.value.toRadixString(16).toUpperCase()})";
            buffer.writeln("${blockIndent}final ${textVar}StrokeStyle = TextStyle(");
            buffer.writeln("$blockIndent  fontSize: ${item.fontSize},");
            buffer.writeln("$blockIndent  fontWeight: $fontWeightStr,");
            buffer.writeln("$blockIndent  foreground: Paint()");
            buffer.writeln("$blockIndent    ..style = PaintingStyle.stroke");
            buffer.writeln("$blockIndent    ..strokeWidth = ${p.strokeWidth}");
            if (blendModeStr.isNotEmpty) buffer.writeln("$blockIndent    $blendModeStr");
            buffer.writeln("$blockIndent    ..color = $strokeColorStr,");
            buffer.writeln("$blockIndent);");
            
            buffer.writeln("${blockIndent}final ${textVar}Stroke = TextPainter(");
            buffer.writeln("$blockIndent  text: TextSpan(text: '${item.text.replaceAll("'", "\\'")}', style: ${textVar}StrokeStyle),");
            buffer.writeln("$blockIndent  textDirection: TextDirection.ltr,");
            buffer.writeln("$blockIndent);");
            buffer.writeln("${blockIndent}${textVar}Stroke.layout();");
            buffer.writeln("${blockIndent}${textVar}Stroke.paint(canvas, const Offset(${item.position.dx}, ${item.position.dy}));");
          }
        } 
        // --- STANDARD SHAPE EXPORT LOGIC ---
        else {
          final baseVar = item.id.replaceAll(RegExp(r'[^a-zA-Z]'), '');
          
          // 1. Generate Fill Pass
          if (hasFill) {
            final fillPaintVar = "${baseVar}Fill";
            buffer.write("${blockIndent}final $fillPaintVar = Paint()..style = PaintingStyle.fill");
            if (p.fillColorParam != null) {
              buffer.write("..color = ${p.fillColorParam}");
            } else {
              buffer.write("..color = const Color(0x${p.fillColor.value.toRadixString(16).toUpperCase()})");
            }
            if (blendModeStr.isNotEmpty) buffer.write(blendModeStr);
            buffer.writeln(";");
            
            _emitDrawCall(buffer, item, fillPaintVar, blockIndent);
          }

          // 2. Generate Stroke Pass
          if (hasStroke) {
            final strokePaintVar = "${baseVar}Stroke";
            buffer.write("${blockIndent}final $strokePaintVar = Paint()..style = PaintingStyle.stroke..strokeWidth = ${p.strokeWidth}..strokeCap = StrokeCap.${p.strokeCap.name}");
            if (p.strokeColorParam != null) {
              buffer.write("..color = ${p.strokeColorParam}");
            } else {
              buffer.write("..color = const Color(0x${p.strokeColor.value.toRadixString(16).toUpperCase()})");
            }
            if (blendModeStr.isNotEmpty) buffer.write(blendModeStr);
            buffer.writeln(";");
            
            _emitDrawCall(buffer, item, strokePaintVar, blockIndent);
          }
        }
      }

      if (hasCondition) {
        buffer.writeln("$indent}");
      }
      
    } catch (e) {
      print('DEBUG ERROR: DartEmitter.emit failed for ${item.id}: $e');
    }
    
    return buffer.toString();
  }

  /// Helper method to write the actual canvas.drawX command based on shape type
  static void _emitDrawCall(StringBuffer buffer, CanvasItem item, String paintVar, String blockIndent) {
    if (item is RectItem) {
      buffer.writeln("${blockIndent}canvas.drawRect(");
      buffer.writeln("$blockIndent  Rect.fromLTRB(${item.rect.left}, ${item.rect.top}, ${item.rect.right}, ${item.rect.bottom}),");
      buffer.writeln("$blockIndent  $paintVar,");
      buffer.writeln("$blockIndent);");
    } 
    else if (item is RRectItem) {
      buffer.writeln("${blockIndent}canvas.drawRRect(");
      buffer.writeln("$blockIndent  RRect.fromRectAndRadius(Rect.fromLTRB(${item.rect.left}, ${item.rect.top}, ${item.rect.right}, ${item.rect.bottom}), const Radius.circular(${item.radius})),");
      buffer.writeln("$blockIndent  $paintVar,");
      buffer.writeln("$blockIndent);");
    }
    else if (item is OvalItem) {
      buffer.writeln("${blockIndent}canvas.drawOval(");
      buffer.writeln("$blockIndent  Rect.fromLTRB(${item.rect.left}, ${item.rect.top}, ${item.rect.right}, ${item.rect.bottom}),");
      buffer.writeln("$blockIndent  $paintVar,");
      buffer.writeln("$blockIndent);");
    }
    else if (item is PathItem) {
      // Create the path object if it's the first time we're drawing it
      final pathVar = "${item.id.replaceAll(RegExp(r'[^a-zA-Z]'), '')}Path";
      
      if (!buffer.toString().contains("final $pathVar = Path()")) {
        buffer.writeln("${blockIndent}final $pathVar = Path()");
        
        if (item.nodes.isNotEmpty) {
          final start = item.nodes[0];
          buffer.writeln("$blockIndent  ..moveTo(${start.position.dx}, ${start.position.dy})");
          
          for (int i = 0; i < item.nodes.length; i++) {
            final current = item.nodes[i];
            final nextIndex = i + 1;
            
            if (nextIndex >= item.nodes.length) {
              if (item.isClosed) {
                final next = item.nodes[0];
                if (current.controlPoint2 != null && next.controlPoint1 != null) {
                  buffer.writeln("$blockIndent  ..cubicTo(${current.controlPoint2!.dx}, ${current.controlPoint2!.dy}, ${next.controlPoint1!.dx}, ${next.controlPoint1!.dy}, ${next.position.dx}, ${next.position.dy})");
                } else if (current.controlPoint2 != null || next.controlPoint1 != null) {
                  final cp = current.controlPoint2 ?? next.controlPoint1!;
                  buffer.writeln("$blockIndent  ..quadraticBezierTo(${cp.dx}, ${cp.dy}, ${next.position.dx}, ${next.position.dy})");
                } else {
                  buffer.writeln("$blockIndent  ..lineTo(${next.position.dx}, ${next.position.dy})");
                }
                buffer.write("$blockIndent  ..close()");
              }
              break;
            }
            
            final next = item.nodes[nextIndex];
            
            if (current.controlPoint2 != null && next.controlPoint1 != null) {
              buffer.writeln("$blockIndent  ..cubicTo(${current.controlPoint2!.dx}, ${current.controlPoint2!.dy}, ${next.controlPoint1!.dx}, ${next.controlPoint1!.dy}, ${next.position.dx}, ${next.position.dy})");
            } else if (current.controlPoint2 != null || next.controlPoint1 != null) {
              final cp = current.controlPoint2 ?? next.controlPoint1!;
              buffer.writeln("$blockIndent  ..quadraticBezierTo(${cp.dx}, ${cp.dy}, ${next.position.dx}, ${next.position.dy})");
            } else {
              buffer.writeln("$blockIndent  ..lineTo(${next.position.dx}, ${next.position.dy})");
            }
          }
        }
        buffer.writeln("$blockIndent;");
      }
      buffer.writeln("${blockIndent}canvas.drawPath($pathVar, $paintVar);");
    }
  }
}