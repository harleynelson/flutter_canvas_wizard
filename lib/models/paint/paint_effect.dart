// File: lib/models/paint/paint_effect.dart
// Description: A model for stacking post-processing effects like blurs and shadows.

import 'package:flutter/material.dart';

abstract class PaintEffect {
  void apply(Paint paint);
}

class BlurEffect extends PaintEffect {
  final double sigma;
  final BlurStyle style;

  BlurEffect({this.sigma = 5.0, this.style = BlurStyle.normal});

  @override
  void apply(Paint paint) {
    paint.maskFilter = MaskFilter.blur(style, sigma);
  }
}

class ShadowEffect extends PaintEffect {
  final Color color;
  final Offset offset;
  final double blurRadius;

  ShadowEffect({this.color = Colors.black, this.offset = const Offset(2, 2), this.blurRadius = 4.0});
  
  @override
  void apply(Paint paint) {
    // TODO: implement apply
  }

  // Note: Shadows usually require a separate canvas.drawShadow or Layer call
}