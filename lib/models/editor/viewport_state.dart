// File: lib/models/editor/viewport_state.dart
// Description: Model to persist the camera position, zoom level, and grid visibility.

import 'package:flutter/material.dart';

class ViewportState {
  final Offset panOffset;
  final double zoomLevel;
  final bool showGrid;
  final bool showRulers;

  ViewportState({
    this.panOffset = Offset.zero,
    this.zoomLevel = 1.0,
    this.showGrid = true,
    this.showRulers = true,
  });

  /// Converts the stored state into a transformation matrix for InteractiveViewer
  Matrix4 get transformMatrix {
    return Matrix4.identity()
      ..translate(panOffset.dx, panOffset.dy)
      ..scale(zoomLevel);
  }

  ViewportState copyWith({
    Offset? panOffset,
    double? zoomLevel,
    bool? showGrid,
    bool? showRulers,
  }) {
    return ViewportState(
      panOffset: panOffset ?? this.panOffset,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      showGrid: showGrid ?? this.showGrid,
      showRulers: showRulers ?? this.showRulers,
    );
  }
}