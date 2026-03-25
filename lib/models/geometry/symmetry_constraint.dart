// File: lib/models/geometry/symmetry_constraint.dart
// Description: Tracks linked items or nodes that must remain symmetrical.

import 'package:flutter/material.dart';
import '../../utils/symmetry_utils.dart';

class SymmetryConstraint {
  final String sourceId;
  final String targetId;
  final SymmetryAxis axis;
  final Offset center;

  SymmetryConstraint({
    required this.sourceId,
    required this.targetId,
    this.axis = SymmetryAxis.vertical,
    this.center = Offset.zero,
  });

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'targetId': targetId,
    'axis': axis.name,
    'centerX': center.dx,
    'centerY': center.dy,
  };
}