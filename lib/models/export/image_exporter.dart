// File: lib/models/export/image_exporter.dart
// Description: Utility to render CanvasItems into a raw PNG byte array using Flutter's PictureRecorder.

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../canvas_item.dart';
import '../../screens/widgets/canvas_renderer.dart';

class ImageExporter {
  static Future<Uint8List?> exportToPng({
    required List<CanvasItem> items,
    required double width,
    required double height,
    Color? backgroundColor,
    Map<String, double> variables = const {},
    Offset cameraPan = Offset.zero,
    double cameraZoom = 1.0,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(width, height);

      // Draw background if not transparent
      if (backgroundColor != null && backgroundColor.alpha > 0) {
        canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
      }

      // Re-use our existing painter, but in "Export Mode" to hide UI elements
      final painter = EditorCanvasPainter(
        items: items,
        isExportMode: true,
        cameraPan: cameraPan, 
        cameraZoom: cameraZoom,
        variables: variables,
      );

      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('DEBUG ERROR: ImageExporter.exportToPng failed: $e');
      return null;
    }
  }
}