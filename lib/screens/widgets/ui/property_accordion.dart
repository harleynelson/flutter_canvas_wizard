// File: lib/screens/widgets/ui/property_accordion.dart
// Description: A collapsible section for the Inspector panel to group properties.

import 'package:flutter/material.dart';

class PropertyAccordion extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  const PropertyAccordion({
    super.key,
    required this.title,
    required this.children,
    this.initiallyExpanded = true,
  });

  @override
  State<PropertyAccordion> createState() => _PropertyAccordionState();
}

class _PropertyAccordionState extends State<PropertyAccordion> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.black12,
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  size: 16,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(children: widget.children),
          ),
        const Divider(height: 1, color: Colors.white10),
      ],
    );
  }
}