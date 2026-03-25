// File: lib/widgets/ui/smart_text_field.dart
// Description: An enterprise-ready input field that handles focus and explicit commit logic.

import 'package:flutter/material.dart';

class SmartTextField extends StatefulWidget {
  final String initialValue;
  final String label;
  final ValueChanged<String> onCommit;

  const SmartTextField({
    super.key,
    required this.initialValue,
    required this.label,
    required this.onCommit,
  });

  @override
  State<SmartTextField> createState() => _SmartTextFieldState();
}

class _SmartTextFieldState extends State<SmartTextField> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(SmartTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isEditing = hasFocus);
        if (!hasFocus) widget.onCommit(_controller.text);
      },
      child: TextField(
        controller: _controller,
        style: const TextStyle(fontSize: 12, color: Colors.white),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 10),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (val) {
          widget.onCommit(val);
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}