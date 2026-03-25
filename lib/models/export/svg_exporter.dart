// File: lib/models/export/svg_exporter.dart
// Description: Translates CanvasItems into a raw SVG XML string.

import 'package:flutter/material.dart';
import '../canvas_item.dart';
import '../../utils/expression_evaluator.dart';

class SvgExporter {
  static String exportProject({
    required List<CanvasItem> items,
    required double width,
    required double height,
    Color? backgroundColor,
    Map<String, double> variables = const {},
    Offset cameraPan = Offset.zero,
    double cameraZoom = 1.0,
  }) {
    try {
      final buffer = StringBuffer();
      buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>');
      buffer.writeln('<svg width="$width" height="$height" viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">');

      if (backgroundColor != null && backgroundColor.alpha > 0) {
        buffer.writeln('  <rect width="100%" height="100%" fill="${_colorToHex(backgroundColor)}" fill-opacity="${backgroundColor.opacity}" />');
      }

      // The center of the SVG should match the center of our Flutter canvas (0,0 is center)
      final centerX = width / 2;
      final centerY = height / 2;
      
      // Apply the camera pan and zoom exactly as the Flutter Canvas does
      buffer.writeln('  <g transform="translate($centerX, $centerY) translate(${cameraPan.dx}, ${cameraPan.dy}) scale($cameraZoom)">');

      for (var item in items) {
        _exportItem(buffer, item, variables, inheritedGhost: false, indent: "    ");
      }

      buffer.writeln('  </g>');
      buffer.writeln('</svg>');
      return buffer.toString();
    } catch (e) {
      print('DEBUG ERROR: SvgExporter.exportProject failed: $e');
      return "";
    }
  }

  static void _exportItem(StringBuffer buffer, CanvasItem item, Map<String, double> variables, {bool inheritedGhost = false, String indent = ""}) {
    if (!item.isVisible) return;

    bool isGhost = inheritedGhost || !ExpressionEvaluator.evaluate(item.enabledIf, variables);
    if (isGhost) return; // For SVG, we typically just exclude hidden/ghosted timeline items

    try {
      if (item is LogicGroupItem) {
        buffer.writeln('$indent<g id="${item.name}">');
        for (var child in item.children) {
          _exportItem(buffer, child, variables, inheritedGhost: isGhost, indent: "$indent  ");
        }
        buffer.writeln('$indent</g>');
        return;
      }

      final p = item.paint;
      final fillHex = _colorToHex(p.fillColor);
      final fillOp = p.fillColor.opacity;
      final strokeHex = _colorToHex(p.strokeColor);
      final strokeOp = p.strokeColor.opacity;
      
      final styleStr = 'fill="$fillHex" fill-opacity="$fillOp" stroke="$strokeHex" stroke-opacity="$strokeOp" stroke-width="${p.strokeWidth}" stroke-linecap="${p.strokeCap.name}"';

      if (item is RectItem) {
        buffer.writeln('$indent<rect x="${item.rect.left}" y="${item.rect.top}" width="${item.rect.width}" height="${item.rect.height}" $styleStr />');
      } 
      else if (item is RRectItem) {
        buffer.writeln('$indent<rect x="${item.rect.left}" y="${item.rect.top}" width="${item.rect.width}" height="${item.rect.height}" rx="${item.radius}" ry="${item.radius}" $styleStr />');
      } 
      else if (item is OvalItem) {
        final cx = item.rect.center.dx;
        final cy = item.rect.center.dy;
        final rx = item.rect.width / 2;
        final ry = item.rect.height / 2;
        buffer.writeln('$indent<ellipse cx="$cx" cy="$cy" rx="$rx" ry="$ry" $styleStr />');
      } 
      else if (item is TextItem) {
        final fontWeight = item.isBold ? "bold" : "normal";
        // SVG text position is roughly baseline, but Flutter is top-left usually, adjusting slightly for estimation
        buffer.writeln('$indent<text x="${item.position.dx}" y="${item.position.dy + item.fontSize}" font-size="${item.fontSize}" font-weight="$fontWeight" $styleStr>${_escapeXml(item.text)}</text>');
      } 
      else if (item is PathItem) {
        final dString = _buildPathString(item);
        if (dString.isNotEmpty) {
          buffer.writeln('$indent<path d="$dString" $styleStr />');
        }
      }
    } catch (e) {
      print('DEBUG ERROR: _exportItem failed for ${item.id}: $e');
    }
  }

  static String _buildPathString(PathItem item) {
    if (item.nodes.isEmpty) return "";
    final sb = StringBuffer();

    final start = item.nodes[0];
    sb.write('M ${start.position.dx} ${start.position.dy} ');

    for (int i = 0; i < item.nodes.length; i++) {
      final current = item.nodes[i];
      final nextIndex = i + 1;

      if (nextIndex >= item.nodes.length) {
        if (item.isClosed) {
          final next = item.nodes[0];
          if (current.controlPoint2 != null && next.controlPoint1 != null) {
            sb.write('C ${current.controlPoint2!.dx} ${current.controlPoint2!.dy}, ${next.controlPoint1!.dx} ${next.controlPoint1!.dy}, ${next.position.dx} ${next.position.dy} ');
          } else if (current.controlPoint2 != null || next.controlPoint1 != null) {
            final cp = current.controlPoint2 ?? next.controlPoint1!;
            sb.write('Q ${cp.dx} ${cp.dy}, ${next.position.dx} ${next.position.dy} ');
          } else {
            sb.write('L ${next.position.dx} ${next.position.dy} ');
          }
          sb.write('Z');
        }
        break;
      }

      final next = item.nodes[nextIndex];

      if (current.controlPoint2 != null && next.controlPoint1 != null) {
        sb.write('C ${current.controlPoint2!.dx} ${current.controlPoint2!.dy}, ${next.controlPoint1!.dx} ${next.controlPoint1!.dy}, ${next.position.dx} ${next.position.dy} ');
      } else if (current.controlPoint2 != null || next.controlPoint1 != null) {
        final cp = current.controlPoint2 ?? next.controlPoint1!;
        sb.write('Q ${cp.dx} ${cp.dy}, ${next.position.dx} ${next.position.dy} ');
      } else {
        sb.write('L ${next.position.dx} ${next.position.dy} ');
      }
    }
    return sb.toString();
  }

  static String _colorToHex(Color c) {
    return '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  static String _escapeXml(String text) {
    return text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
  }
}