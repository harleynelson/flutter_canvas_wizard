// File: lib/utils/editor_debounce.dart
// Description: Utility to ensure drag operations only create a single history entry.

import 'dart:async';

class EditorDebounce {
  Timer? _timer;

  void run(Duration duration, Function action) {
    _timer?.cancel();
    _timer = Timer(duration, () => action());
  }

  void dispose() => _timer?.cancel();
}