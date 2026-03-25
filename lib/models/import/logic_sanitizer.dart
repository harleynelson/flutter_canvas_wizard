// File: lib/models/import/logic_sanitizer.dart
// Description: Maps game-specific variables to hardcoded values for the editor.

import 'dart:ui';

class LogicSanitizer {
  static const Map<String, Color> variableFallback = {
    'stoneColor': Color(0xFF7A8B8B),
    'darkStone': Color(0xFF556262),
    'shrineRed': Color(0xFFC62828),
    'bronze': Color(0xFFCD7F32),
  };

  static Color resolve(String variableName) {
    return variableFallback[variableName] ?? const Color(0xFF9E9E9E); // Grey fallback
  }
}