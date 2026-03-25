// File: lib/utils/indentation_buffer.dart
// Description: A specialized buffer that maintains indentation levels.

class IndentationBuffer {
  final int step;
  int _level = 0;
  final StringBuffer _buffer = StringBuffer();

  IndentationBuffer({this.step = 2});

  void indent() => _level++;
  void outdent() => _level = _level > 0 ? _level - 1 : 0;

  void writeln(String line) {
    final spaces = ' ' * (_level * step);
    _buffer.writeln('$spaces$line');
  }

  @override
  String toString() => _buffer.toString();
}