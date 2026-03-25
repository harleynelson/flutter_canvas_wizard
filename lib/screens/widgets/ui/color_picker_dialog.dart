// File: lib/screens/widgets/color_picker_dialog.dart
// Description: An enterprise-grade custom dark-themed color picker featuring a unified, responsive interface with compact 2D visual selection, sliders/hex input, and custom saved swatches.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Data model for user-saved colors
class SavedColor {
  final String name;
  final Color color;
  final String? info;

  SavedColor({required this.name, required this.color, this.info});

  Map<String, dynamic> toJson() => {
    'name': name,
    'color': color.value,
    'info': info,
  };

  factory SavedColor.fromJson(Map<String, dynamic> json) {
    return SavedColor(
      name: json['name'] ?? 'Untitled',
      color: Color(json['color'] as int),
      info: json['info'],
    );
  }
}

class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const ColorPickerDialog({super.key, required this.initialColor});

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late HSVColor _hsvColor;
  final TextEditingController _hexController = TextEditingController();

  // Mock data for session.
  List<Color> _recentColors = [
    const Color(0xFF4A90E2),
    const Color(0xFF50E3C2),
  ];
  List<SavedColor> _savedColors = [];

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
    _updateHexController();
    _loadPreferences();
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  // --- Persistence Logic ---

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Recent Colors
      final List<String>? recentHex = prefs.getStringList('canvas_wizard_recent');
      if (recentHex != null) {
        setState(() {
          _recentColors = recentHex.map((hex) => Color(int.parse(hex, radix: 16))).toList();
        });
      }

      // Load Saved Colors
      final List<String>? savedJson = prefs.getStringList('canvas_wizard_saved');
      if (savedJson != null) {
        setState(() {
          _savedColors = savedJson.map((s) => SavedColor.fromJson(jsonDecode(s))).toList();
        });
      }
      print('DEBUG: Preferences loaded successfully');
    } catch (e) {
      print('DEBUG Error loading preferences: $e');
    }
  }

  Future<void> _saveColorsToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Persist Recents - converting to string values
      final recentHex = _recentColors.map((c) => c.value.toRadixString(16)).toList();
      await prefs.setStringList('canvas_wizard_recent', recentHex);

      // Persist Custom Saved - converting objects to JSON strings
      final savedJson = _savedColors.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList('canvas_wizard_saved', savedJson);
      
      print('DEBUG: Colors persisted to disk. Count: ${_savedColors.length}');
    } catch (e) {
      print('DEBUG Error persisting colors: $e');
    }
  }

  // --- UI Logic ---

  void _updateHexController() {
    try {
      final color = _hsvColor.toColor();
      final hex = color.value.toRadixString(16).toUpperCase().padLeft(8, '0');
      _hexController.text = hex;
      print('DEBUG: Hex controller updated to $hex');
    } catch (e) {
      print('DEBUG Error updating hex controller: $e');
    }
  }

  void _onHexChanged(String value) {
    try {
      String hexString = value.replaceAll('#', '');
      if (hexString.length == 6) {
        hexString = 'FF$hexString';
      }
      if (hexString.length == 8) {
        final int? parsed = int.tryParse(hexString, radix: 16);
        if (parsed != null) {
          setState(() {
            _hsvColor = HSVColor.fromColor(Color(parsed));
          });
        }
      }
    } catch (e) {
      print('DEBUG Error parsing hex input: $e');
    }
  }

  void _updateHSV({double? h, double? s, double? v, double? a}) {
    setState(() {
      _hsvColor = _hsvColor.withHue(h ?? _hsvColor.hue)
                           .withSaturation(s ?? _hsvColor.saturation)
                           .withValue(v ?? _hsvColor.value)
                           .withAlpha(a ?? _hsvColor.alpha);
    });
    _updateHexController();
  }

  void _handleColorAreaGesture(Offset localPosition, Size size) {
    try {
      final double dx = localPosition.dx.clamp(0.0, size.width);
      final double dy = localPosition.dy.clamp(0.0, size.height);
      
      // Ensure we don't divide by zero if layout is squished
      final double saturation = size.width > 0 ? dx / size.width : 0.0;
      final double value = size.height > 0 ? 1.0 - (dy / size.height) : 0.0;
      
      _updateHSV(s: saturation, v: value);
      print('DEBUG: Color Area updated - Saturation: $saturation, Value: $value');
    } catch (e) {
      print('DEBUG Error in color area gesture: $e');
    }
  }

  void _handleHueRibbonGesture(Offset localPosition, Size size) {
    try {
      final double dx = localPosition.dx.clamp(0.0, size.width);
      final double hue = size.width > 0 ? (dx / size.width) * 360.0 : 0.0;
      
      _updateHSV(h: hue);
      print('DEBUG: Hue Ribbon updated - Hue: $hue');
    } catch (e) {
      print('DEBUG Error in hue ribbon gesture: $e');
    }
  }

  Future<void> _promptSaveColor() async {
    String tempName = '';
    String tempInfo = '';
    try {
      final bool? saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF3E3E42),
          title: const Text('Save Color', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white70)),
                onChanged: (val) => tempName = val,
              ),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Notes', labelStyle: TextStyle(color: Colors.white70)),
                onChanged: (val) => tempInfo = val,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      );

      if (saved == true && tempName.isNotEmpty) {
        setState(() {
          _savedColors.add(SavedColor(name: tempName, color: _hsvColor.toColor(), info: tempInfo));
        });
        await _saveColorsToDisk();
      }
    } catch (e) {
      print('DEBUG Error in save prompt: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _hsvColor.toColor();

    return AlertDialog(
      backgroundColor: const Color(0xFF2D2D30),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0), // Tightened padding
      title: const Text('Advanced Color Picker', style: TextStyle(color: Colors.white, fontSize: 18)),
      content: SizedBox(
        width: 400, // Max width for desktop scaling
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Persistent Color Preview Area (More compact)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: widget.initialColor,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                      ),
                      child: const Center(child: Text('Current', style: TextStyle(color: Colors.white70, fontSize: 12, shadows: [Shadow(color: Colors.black, blurRadius: 2)]))),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: currentColor,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                      ),
                      child: const Center(child: Text('New', style: TextStyle(color: Colors.white, fontSize: 12, shadows: [Shadow(color: Colors.black, blurRadius: 2)]))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 2. Interactive 2D Color Area (Reduced Height)
              LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onPanUpdate: (details) => _handleColorAreaGesture(details.localPosition, Size(constraints.maxWidth, 150)),
                    onTapDown: (details) => _handleColorAreaGesture(details.localPosition, Size(constraints.maxWidth, 150)),
                    child: SizedBox(
                      width: double.infinity,
                      height: 150,
                      child: CustomPaint(painter: _ColorAreaPainter(_hsvColor)),
                    ),
                  );
                }
              ),
              const SizedBox(height: 8),

              // 3. Hue Ribbon (Reduced Height)
              LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onPanUpdate: (details) => _handleHueRibbonGesture(details.localPosition, Size(constraints.maxWidth, 20)),
                    onTapDown: (details) => _handleHueRibbonGesture(details.localPosition, Size(constraints.maxWidth, 20)),
                    child: SizedBox(
                      width: double.infinity,
                      height: 20,
                      child: CustomPaint(painter: _HueRibbonPainter(_hsvColor.hue)),
                    ),
                  );
                }
              ),
              const SizedBox(height: 12),

              // 4. Compact Sliders & Hex
              _buildSliderRow('Sat', _hsvColor.saturation, 0, 1, (val) => _updateHSV(s: val)),
              _buildSliderRow('Val', _hsvColor.value, 0, 1, (val) => _updateHSV(v: val)),
              _buildSliderRow('Alpha', _hsvColor.alpha, 0, 1, (val) => _updateHSV(a: val)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Hex: #', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _hexController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          filled: true,
                          fillColor: Color(0xFF1E1E1E),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        ),
                        onChanged: _onHexChanged,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),

              // 5. Swatches (Saved, Recent, Presets)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Saved Colors', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _promptSaveColor,
                    tooltip: 'Save Current Color',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_savedColors.isEmpty)
                const Text('No saved colors yet.', style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _savedColors.length,
                  itemBuilder: (context, index) {
                    try {
                      final saved = _savedColors[index];
                      return InkWell(
                        onTap: () {
                          setState(() => _hsvColor = HSVColor.fromColor(saved.color));
                          _updateHexController();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Container(width: 20, height: 20, decoration: BoxDecoration(color: saved.color, borderRadius: BorderRadius.circular(4))),
                              const SizedBox(width: 8),
                              Text(saved.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                      );
                    } catch (e) {
                      print('DEBUG Error building saved color list item: $e');
                      return const SizedBox.shrink();
                    }
                  },
                ),
              
              const SizedBox(height: 12),
              const Text('Recent', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _buildColorGrid(_recentColors, currentColor),

              const SizedBox(height: 12),
              const Text('Presets', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _buildColorGrid([
                Colors.redAccent, Colors.orangeAccent, Colors.yellowAccent,
                Colors.greenAccent, Colors.blueAccent, Colors.purpleAccent,
                Colors.white, Colors.grey, Colors.black,
                const Color(0xFF7A8B8B), const Color(0xFFC62828), const Color(0xFFCD7F32),
              ], currentColor),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          onPressed: () async {
            try {
              // 1. Update Recents List
              if (!_recentColors.contains(currentColor)) {
                _recentColors.insert(0, currentColor);
                // Keep the list clean - enterprise tools shouldn't have infinite lists
                if (_recentColors.length > 12) {
                  _recentColors.removeLast();
                }
              }

              // 2. CRITICAL: Save to disk before closing the dialog
              await _saveColorsToDisk();

              // 3. Close dialog and return color
              if (context.mounted) {
                Navigator.pop(context, currentColor);
              }
            } catch (e) {
              print('DEBUG Error in selection process: $e');
              // Fallback pop so the UI doesn't hang
              Navigator.pop(context, currentColor);
            }
          },
          child: const Text('Select', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildSliderRow(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0), // Tighter padding
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3, 
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(value: value, min: min, max: max, activeColor: Colors.white, inactiveColor: Colors.white24, onChanged: onChanged),
            ),
          ),
          SizedBox(width: 35, child: Text('${(value * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 11), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildColorGrid(List<Color> colors, Color currentColor) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: colors.map((color) => GestureDetector(
        onTap: () {
          setState(() => _hsvColor = HSVColor.fromColor(color));
          _updateHexController();
        },
        child: Container(
          width: 30, // Scaled down from 36
          height: 30, // Scaled down from 36
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: currentColor.value == color.value ? Colors.white : Colors.transparent, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      )).toList(),
    );
  }
}

// --- Retained Custom Painters ---

class _ColorAreaPainter extends CustomPainter {
  final HSVColor currentHSV;
  _ColorAreaPainter(this.currentHSV);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Color baseHueColor = HSVColor.fromAHSV(1.0, currentHSV.hue, 1.0, 1.0).toColor();

    final Paint saturationPaint = Paint()
      ..shader = LinearGradient(colors: [Colors.white, baseHueColor], begin: Alignment.centerLeft, end: Alignment.centerRight).createShader(rect);
    canvas.drawRect(rect, saturationPaint);

    final Paint valuePaint = Paint()
      ..shader = LinearGradient(colors: [Colors.transparent, Colors.black], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(rect);
    canvas.drawRect(rect, valuePaint);

    final double thumbX = currentHSV.saturation * size.width;
    final double thumbY = (1.0 - currentHSV.value) * size.height;
    final Offset thumbOffset = Offset(thumbX, thumbY);

    canvas.drawCircle(thumbOffset, 6, Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 4.0);
    canvas.drawCircle(thumbOffset, 6, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0);
  }

  @override
  bool shouldRepaint(covariant _ColorAreaPainter oldDelegate) => oldDelegate.currentHSV != currentHSV;
}

class _HueRibbonPainter extends CustomPainter {
  final double currentHue;
  _HueRibbonPainter(this.currentHue);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint huePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00), Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000)],
        stops: [0.0, 0.166, 0.333, 0.5, 0.666, 0.833, 1.0],
      ).createShader(rect);
    
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), huePaint);

    final double thumbX = (currentHue / 360.0) * size.width;
    final Offset thumbCenter = Offset(thumbX, size.height / 2);

    canvas.drawCircle(thumbCenter, 7, Paint()..color = Colors.black54..style = PaintingStyle.stroke..strokeWidth = 2.0);
    canvas.drawCircle(thumbCenter, 7, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _HueRibbonPainter oldDelegate) => oldDelegate.currentHue != currentHue;
}