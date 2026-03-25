// File: lib/widgets/ui/export_dialog.dart
// Description: A dialog allowing users to choose between Dart, PNG, and SVG exports, featuring a live auto-fit preview and native file pickers.

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart'; // REQUIRED DEPENDENCY

import '../../models/canvas_item.dart';
import '../../models/export/vector_exporter.dart';
import '../../models/export/code_template.dart';
import '../../models/export/image_exporter.dart';
import '../../models/export/svg_exporter.dart';
import '../../utils/bounding_box_utils.dart';
import '../editor_canvas.dart';
import 'export_preview_panel.dart';

enum DartExportType { simple, fullMethod }

class ExportDialog extends StatefulWidget {
  final List<CanvasItem> items;

  const ExportDialog({super.key, required this.items});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Dart State
  DartExportType _dartSelectedType = DartExportType.fullMethod;
  String _generatedCode = "";

  // Visual Export State
  final TextEditingController _widthController = TextEditingController(text: "800");
  final TextEditingController _heightController = TextEditingController(text: "600");
  final TextEditingController _paddingController = TextEditingController(text: "20");
  
  bool _transparentBackground = false;
  final Color _backgroundColor = const Color(0xFF1E1E1E);
  bool _autoFit = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _generateDart();
    
    // Listen to changes to redraw the live preview automatically
    _widthController.addListener(() => setState((){}));
    _heightController.addListener(() => setState((){}));
    _paddingController.addListener(() => setState((){}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _paddingController.dispose();
    super.dispose();
  }

  void _generateDart() {
    try {
      setState(() {
        _generatedCode = VectorExporter.exportProject(
          items: widget.items,
          template: CodeTemplate(),
          isSimple: _dartSelectedType == DartExportType.simple,
        );
      });
    } catch (e) {
      print('DEBUG ERROR: Dart Export generation failed: $e');
    }
  }

  /// Calculates the Pan and Zoom required to center and fit the canvas items 
  /// inside the specified export dimensions with padding.
  (Offset, double) _calculateTransform(double w, double h) {
    if (!_autoFit) return (Offset.zero, 1.0);
    
    try {
      Rect bounds = BoundingBoxUtils.getCombinedRect(widget.items);
      if (bounds == Rect.zero) return (Offset.zero, 1.0);

      double pad = double.tryParse(_paddingController.text) ?? 0.0;
      double availableW = math.max(1.0, w - pad * 2);
      double availableH = math.max(1.0, h - pad * 2);

      double scaleX = availableW / bounds.width;
      double scaleY = availableH / bounds.height;
      double zoom = math.min(scaleX, scaleY);

      if (zoom.isInfinite || zoom.isNaN) zoom = 1.0;

      Offset pan = -bounds.center * zoom;
      return (pan, zoom);
    } catch (e) {
      print('DEBUG ERROR: _calculateTransform failed: $e');
      return (Offset.zero, 1.0);
    }
  }

  Future<void> _exportFile(String extension) async {
    try {
      final double width = double.tryParse(_widthController.text) ?? 800;
      final double height = double.tryParse(_heightController.text) ?? 600;
      final Color? bg = _transparentBackground ? null : _backgroundColor;
      
      final transform = _calculateTransform(width, height);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save $extension Export',
        fileName: 'canvas_export$extension',
        type: FileType.custom,
        allowedExtensions: [extension.replaceAll('.', '')], // e.g. 'png'
      );

      if (outputFile == null) {
        return; // User canceled
      }

      if (!outputFile.toLowerCase().endsWith(extension)) {
        outputFile += extension;
      }

      final file = File(outputFile);

      if (extension == '.svg') {
        final svgString = SvgExporter.exportProject(
          items: widget.items, 
          width: width, 
          height: height, 
          backgroundColor: bg,
          cameraPan: transform.$1,
          cameraZoom: transform.$2,
        );
        await file.writeAsString(svgString);
      } else if (extension == '.png') {
        final bytes = await ImageExporter.exportToPng(
          items: widget.items, 
          width: width, 
          height: height, 
          backgroundColor: bg,
          cameraPan: transform.$1,
          cameraZoom: transform.$2,
        );
        if (bytes != null) {
          await file.writeAsBytes(bytes);
        } else {
          throw Exception("ImageExporter returned null bytes.");
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully exported to $outputFile'), backgroundColor: Colors.green));
      }
    } catch (e) {
      print('DEBUG ERROR: File export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export Failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2D2D30),
      title: const Text('Export Workspace', style: TextStyle(color: Colors.white)),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 800,
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.blueAccent,
              tabs: const [
                Tab(text: "Visual Export (PNG/SVG)"),
                Tab(text: "Dart Code"),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildVisualTab(),
                  _buildDartTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  // --- DART TAB ---

  Widget _buildDartTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _dartTypeButton('Simple Tiered', DartExportType.simple),
            const SizedBox(width: 12),
            _dartTypeButton('Full Method Wrapper', DartExportType.fullMethod),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white10),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8.0),
              child: ExportPreviewPanel(generatedCode: _generatedCode),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _generatedCode));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied to clipboard!')));
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy to Clipboard'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _dartTypeButton(String label, DartExportType type) {
    final bool isSelected = _dartSelectedType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _dartSelectedType = type);
          _generateDart();
        }
      },
      selectedColor: Colors.blueAccent.withOpacity(0.3),
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white60),
    );
  }

  // --- VISUAL EXPORT TAB ---

  Widget _buildVisualTab() {
    final double width = double.tryParse(_widthController.text) ?? 800;
    final double height = double.tryParse(_heightController.text) ?? 600;
    final transform = _calculateTransform(width, height);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Settings
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Canvas Dimensions:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _widthController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Width (px)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _heightController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Height (px)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Layout & Framing:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                SwitchListTile(
                  title: const Text('Auto-Fit Content', style: TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: const Text('Centers and scales artwork to fit bounds.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.blueAccent,
                  value: _autoFit,
                  onChanged: (val) => setState(() => _autoFit = val),
                ),
                if (_autoFit)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                    child: TextField(
                      controller: _paddingController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Edge Padding (px)', border: OutlineInputBorder(), isDense: true),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                const SizedBox(height: 24),
                const Text('Environment:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                CheckboxListTile(
                  title: const Text('Transparent Background', style: TextStyle(color: Colors.white, fontSize: 13)),
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.blueAccent,
                  value: _transparentBackground,
                  onChanged: (val) => setState(() => _transparentBackground = val ?? false),
                ),
                const SizedBox(height: 32),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                      onPressed: () => _exportFile('.svg'),
                      icon: const Icon(Icons.polyline, color: Colors.white),
                      label: const Text('Save SVG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                      onPressed: () => _exportFile('.png'),
                      icon: const Icon(Icons.image, color: Colors.white),
                      label: const Text('Save PNG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Right Column: Live Preview
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Live Preview', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _transparentBackground ? Colors.black : _backgroundColor,
                    border: Border.all(color: Colors.white24, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRect(
                    // FittedBox ensures the preview scales visually inside the dialog 
                    // without changing the actual layout logic of the EditorCanvasPainter
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: Stack(
                          children: [
                            // Checkerboard background for transparency visualization
                            if (_transparentBackground)
                              Positioned.fill(
                                child: CustomPaint(painter: _CheckerboardPainter()),
                              ),
                            CustomPaint(
                              painter: EditorCanvasPainter(
                                items: widget.items,
                                isExportMode: true,
                                cameraPan: transform.$1,
                                cameraZoom: transform.$2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Rendering at ${width.toInt()} x ${height.toInt()}', 
                  style: const TextStyle(color: Colors.white38, fontSize: 11)
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}

// Helper to draw a checkerboard for transparency preview
class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = Colors.grey[800]!;
    final paint2 = Paint()..color = Colors.grey[700]!;
    final double squareSize = 20.0;

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isEven = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(Rect.fromLTWH(x, y, squareSize, squareSize), isEven ? paint1 : paint2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}