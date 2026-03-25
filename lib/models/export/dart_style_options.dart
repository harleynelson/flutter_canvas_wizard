// File: lib/models/export/dart_style_options.dart
// Description: Configuration for the code generator's visual style.

class DartStyleOptions {
  final int indentSize;
  final bool useCascades; // Use '..' instead of multiple 'paint.x = y'
  final bool preferConst; // Add 'const' where applicable
  final bool trailingCommas; // Standard Flutter style for better diffs

  const DartStyleOptions({
    this.indentSize = 2,
    this.useCascades = true,
    this.preferConst = true,
    this.trailingCommas = true,
  });
}