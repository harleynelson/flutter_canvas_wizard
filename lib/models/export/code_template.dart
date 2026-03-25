// File: lib/models/export/code_template.dart
// Description: Defines the structure and parameters for the generated Dart method.

class CodeTemplate {
  final String methodName;
  final List<String> parameters; // e.g., ["Canvas canvas", "Offset pos", "int tier"]
  final String indent;

  CodeTemplate({
    this.methodName = "_renderCustomAsset",
    this.parameters = const ["Canvas canvas", "Offset pos", "double scale"],
    this.indent = "  ",
  });

  String get signature => "static void $methodName(${parameters.join(', ')}) {";

  String wrapInBoilerplate(String body) {
    return """
$signature
  try {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(scale);

${body.split('\n').map((line) => '$indent$indent$line').join('\n')}

    canvas.restore();
  } catch (e) {
    print('DEBUG ERROR: $methodName failed: \$e');
  }
}
""";
  }
}