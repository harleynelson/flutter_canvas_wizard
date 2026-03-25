// File: lib/models/canvas_item.dart
// Description: Core data models for serializing canvas shapes, paint properties, custom export parameters, and affine transformations.

import 'package:flutter/material.dart';

class ExportParameter {
  String type;
  String name;

  ExportParameter({required this.type, required this.name});

  Map<String, dynamic> toJson() {
    try {
      return {
        'type': type,
        'name': name,
      };
    } catch (e) {
      print('DEBUG ERROR: ExportParameter.toJson failed: $e');
      return {};
    }
  }

  factory ExportParameter.fromJson(Map<String, dynamic> json) {
    try {
      return ExportParameter(
        type: json['type'] ?? 'dynamic',
        name: json['name'] ?? 'param',
      );
    } catch (e) {
      print('DEBUG ERROR: ExportParameter.fromJson failed: $e');
      return ExportParameter(type: 'dynamic', name: 'errorParam');
    }
  }
}

class CanvasPaint {
  Color fillColor;
  Color strokeColor;
  double strokeWidth;
  String? fillColorParam;
  String? strokeColorParam;
  
  StrokeCap strokeCap;
  BlendMode blendMode;
  int extrusionSteps; 
  Offset extrusionOffset;

  CanvasPaint({
    this.fillColor = Colors.grey,
    this.strokeColor = Colors.transparent,
    this.strokeWidth = 0.0,
    this.fillColorParam,
    this.strokeColorParam,
    this.strokeCap = StrokeCap.butt,
    this.blendMode = BlendMode.srcOver,
    this.extrusionSteps = 0,
    this.extrusionOffset = const Offset(0, 1),
  });

  Map<String, dynamic> toJson() {
    try {
      return {
        'fillColor': fillColor.toARGB32(),
        'strokeColor': strokeColor.toARGB32(),
        'strokeWidth': strokeWidth,
        'fillColorParam': fillColorParam,
        'strokeColorParam': strokeColorParam,
        'strokeCap': strokeCap.index,
        'blendMode': blendMode.index,
        'extrusionSteps': extrusionSteps,
        'extrusionOffset': {'dx': extrusionOffset.dx, 'dy': extrusionOffset.dy},
      };
    } catch (e) {
      print('DEBUG ERROR: CanvasPaint.toJson failed: $e');
      return {};
    }
  }

  factory CanvasPaint.fromJson(Map<String, dynamic> json) {
    try {
      return CanvasPaint(
        fillColor: Color(json['fillColor'] ?? 0xFF9E9E9E),
        strokeColor: Color(json['strokeColor'] ?? 0x00000000),
        strokeWidth: (json['strokeWidth'] ?? 0.0).toDouble(),
        fillColorParam: json['fillColorParam'],
        strokeColorParam: json['strokeColorParam'],
        strokeCap: StrokeCap.values[json['strokeCap'] ?? 0],
        blendMode: BlendMode.values[json['blendMode'] ?? 3],
        extrusionSteps: json['extrusionSteps'] ?? 0,
        extrusionOffset: Offset(
          (json['extrusionOffset']?['dx'] ?? 0.0).toDouble(),
          (json['extrusionOffset']?['dy'] ?? 1.0).toDouble(),
        ),
      );
    } catch (e) {
      print('DEBUG ERROR: CanvasPaint.fromJson failed: $e');
      return CanvasPaint();
    }
  }

  CanvasPaint copyWith({
    Color? fillColor,
    Color? strokeColor,
    double? strokeWidth,
    String? fillColorParam,
    String? strokeColorParam,
    StrokeCap? strokeCap,
    BlendMode? blendMode,
    int? extrusionSteps,
    Offset? extrusionOffset,
  }) {
    return CanvasPaint(
      fillColor: fillColor ?? this.fillColor,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      fillColorParam: fillColorParam ?? this.fillColorParam,
      strokeColorParam: strokeColorParam ?? this.strokeColorParam,
      strokeCap: strokeCap ?? this.strokeCap,
      blendMode: blendMode ?? this.blendMode,
      extrusionSteps: extrusionSteps ?? this.extrusionSteps,
      extrusionOffset: extrusionOffset ?? this.extrusionOffset,
    );
  }
}

abstract class CanvasItem {
  String id;
  String name;
  bool isVisible;
  String? enabledIf; 
  CanvasPaint paint;
  String type;
  Matrix4 transform; // NEW: Global affine transformation matrix

  CanvasItem({
    required this.id,
    required this.name,
    this.isVisible = true,
    this.enabledIf,
    required this.paint,
    required this.type,
    Matrix4? transform,
  }) : transform = transform ?? Matrix4.identity();

  Map<String, dynamic> toJson() {
    try {
      return {
        'id': id,
        'name': name,
        'isVisible': isVisible,
        'enabledIf': enabledIf,
        'paint': paint.toJson(),
        'type': type,
        'transform': transform.storage.toList(), // Save matrix as flat List<double>
      };
    } catch (e) {
      print('DEBUG ERROR: CanvasItem.toJson base failed: $e');
      return {};
    }
  }

  factory CanvasItem.fromJson(Map<String, dynamic> json) {
    try {
      final type = json['type'] as String;
      if (type == 'rect') {
        return RectItem.fromJson(json);
      } else if (type == 'rrect') {
        return RRectItem.fromJson(json);
      } else if (type == 'oval') {
        return OvalItem.fromJson(json);
      } else if (type == 'path') {
        return PathItem.fromJson(json);
      } else if (type == 'logic_group') {
        return LogicGroupItem.fromJson(json);
      } else if (type == 'text') {
        return TextItem.fromJson(json);
      }
      throw Exception('Unknown item type: $type');
    } catch (e) {
      print('DEBUG ERROR: CanvasItem.fromJson routing failed: $e');
      return RectItem(
        id: 'error_node', 
        name: 'Corrupted Node', 
        rect: Rect.zero, 
        paint: CanvasPaint()
      ); 
    }
  }

  // Helper method to duplicate an item with a new transform matrix
  CanvasItem copyWithTransform(Matrix4 newTransform);
}

class RectItem extends CanvasItem {
  Rect rect;

  RectItem({
    required super.id,
    required super.name,
    super.isVisible = true,
    super.enabledIf,
    required super.paint,
    super.transform,
    required this.rect,
  }) : super(type: 'rect');

  @override
  CanvasItem copyWithTransform(Matrix4 newTransform) {
    return RectItem(id: id, name: name, isVisible: isVisible, enabledIf: enabledIf, paint: paint, rect: rect, transform: newTransform);
  }

  @override
  Map<String, dynamic> toJson() {
    try {
      final data = super.toJson();
      data['rect'] = {
        'left': rect.left,
        'top': rect.top,
        'right': rect.right,
        'bottom': rect.bottom,
      };
      return data;
    } catch (e) {
      print('DEBUG ERROR: RectItem.toJson failed: $e');
      return {};
    }
  }

  factory RectItem.fromJson(Map<String, dynamic> json) {
    try {
      final rectData = json['rect'] as Map<String, dynamic>;
      return RectItem(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Unnamed Rect',
        isVisible: json['isVisible'] ?? true,
        enabledIf: json['enabledIf'],
        paint: CanvasPaint.fromJson(json['paint'] ?? {}),
        transform: json['transform'] != null ? Matrix4.fromList(List<double>.from(json['transform'])) : Matrix4.identity(),
        rect: Rect.fromLTRB(
          (rectData['left'] ?? 0.0).toDouble(),
          (rectData['top'] ?? 0.0).toDouble(),
          (rectData['right'] ?? 0.0).toDouble(),
          (rectData['bottom'] ?? 0.0).toDouble(),
        ),
      );
    } catch (e) {
      return RectItem(id: 'err', name: 'Err', rect: Rect.zero, paint: CanvasPaint());
    }
  }
}

class PathNode {
  Offset position;
  Offset? controlPoint1; 
  Offset? controlPoint2;

  PathNode({required this.position, this.controlPoint1, this.controlPoint2});

  Map<String, dynamic> toJson() => {
    'x': position.dx, 'y': position.dy,
    if (controlPoint1 != null) 'cp1x': controlPoint1!.dx,
    if (controlPoint1 != null) 'cp1y': controlPoint1!.dy,
    if (controlPoint2 != null) 'cp2x': controlPoint2!.dx,
    if (controlPoint2 != null) 'cp2y': controlPoint2!.dy,
  };

  factory PathNode.fromJson(Map<String, dynamic> json) => PathNode(
    position: Offset(json['x'], json['y']),
    controlPoint1: json['cp1x'] != null ? Offset(json['cp1x'], json['cp1y']) : null,
    controlPoint2: json['cp2x'] != null ? Offset(json['cp2x'], json['cp2y']) : null,
  );
}

class PathItem extends CanvasItem {
  List<PathNode> nodes;
  bool isClosed;

  PathItem({
    required super.id,
    required super.name,
    super.isVisible,
    super.enabledIf,
    required super.paint,
    super.transform,
    required this.nodes,
    this.isClosed = true,
  }) : super(type: 'path');

  @override
  CanvasItem copyWithTransform(Matrix4 newTransform) {
    return PathItem(id: id, name: name, isVisible: isVisible, enabledIf: enabledIf, paint: paint, nodes: nodes, isClosed: isClosed, transform: newTransform);
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['nodes'] = nodes.map((n) => n.toJson()).toList();
    data['isClosed'] = isClosed;
    return data;
  }

  factory PathItem.fromJson(Map<String, dynamic> json) {
    return PathItem(
      id: json['id'],
      name: json['name'],
      isVisible: json['isVisible'] ?? true,
      enabledIf: json['enabledIf'],
      paint: CanvasPaint.fromJson(json['paint']),
      transform: json['transform'] != null ? Matrix4.fromList(List<double>.from(json['transform'])) : Matrix4.identity(),
      isClosed: json['isClosed'] ?? true,
      nodes: (json['nodes'] as List).map((n) => PathNode.fromJson(n)).toList(),
    );
  }
}

class LogicGroupItem extends CanvasItem {
  String condition;
  List<CanvasItem> children;

  LogicGroupItem({
    required super.id,
    required super.name,
    super.isVisible,
    super.enabledIf,
    required super.paint, 
    super.transform,
    required this.condition,
    this.children = const [],
  }) : super(type: 'logic_group');

  @override
  CanvasItem copyWithTransform(Matrix4 newTransform) {
    return LogicGroupItem(id: id, name: name, isVisible: isVisible, enabledIf: enabledIf, paint: paint, condition: condition, children: children, transform: newTransform);
  }

  @override
  Map<String, dynamic> toJson() {
    try {
      final data = super.toJson();
      data['condition'] = condition;
      data['children'] = children.map((c) => c.toJson()).toList();
      return data;
    } catch (e) {
      print('DEBUG ERROR: LogicGroupItem.toJson failed: $e');
      return {};
    }
  }

  factory LogicGroupItem.fromJson(Map<String, dynamic> json) {
    try {
      return LogicGroupItem(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Logic Group',
        isVisible: json['isVisible'] ?? true,
        enabledIf: json['enabledIf'],
        paint: CanvasPaint.fromJson(json['paint'] ?? {}),
        transform: json['transform'] != null ? Matrix4.fromList(List<double>.from(json['transform'])) : Matrix4.identity(),
        condition: json['condition'] ?? 'true',
        children: (json['children'] as List?)?.map((c) => CanvasItem.fromJson(c)).toList() ?? [],
      );
    } catch (e) {
      return LogicGroupItem(id: 'err', name: 'Err', condition: 'true', paint: CanvasPaint());
    }
  }
}

class RRectItem extends CanvasItem {
  Rect rect;
  double radius;

  RRectItem({
    required super.id,
    required super.name,
    super.isVisible = true,
    super.enabledIf,
    required super.paint,
    super.transform,
    required this.rect,
    this.radius = 8.0,
  }) : super(type: 'rrect');

  @override
  CanvasItem copyWithTransform(Matrix4 newTransform) {
    return RRectItem(id: id, name: name, isVisible: isVisible, enabledIf: enabledIf, paint: paint, rect: rect, radius: radius, transform: newTransform);
  }

  @override
  Map<String, dynamic> toJson() {
    try {
      final data = super.toJson();
      data['rect'] = {'left': rect.left, 'top': rect.top, 'right': rect.right, 'bottom': rect.bottom};
      data['radius'] = radius;
      return data;
    } catch (e) {
      return {};
    }
  }

  factory RRectItem.fromJson(Map<String, dynamic> json) {
    try {
      final rectData = json['rect'] as Map<String, dynamic>;
      return RRectItem(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Unnamed RRect',
        isVisible: json['isVisible'] ?? true,
        enabledIf: json['enabledIf'],
        paint: CanvasPaint.fromJson(json['paint'] ?? {}),
        transform: json['transform'] != null ? Matrix4.fromList(List<double>.from(json['transform'])) : Matrix4.identity(),
        rect: Rect.fromLTRB(
          (rectData['left'] ?? 0.0).toDouble(), (rectData['top'] ?? 0.0).toDouble(),
          (rectData['right'] ?? 0.0).toDouble(), (rectData['bottom'] ?? 0.0).toDouble(),
        ),
        radius: (json['radius'] ?? 8.0).toDouble(),
      );
    } catch (e) {
      return RRectItem(id: 'err', name: 'Err', rect: Rect.zero, paint: CanvasPaint());
    }
  }
}

class OvalItem extends CanvasItem {
  Rect rect; 

  OvalItem({
    required super.id,
    required super.name,
    super.isVisible = true,
    super.enabledIf,
    required super.paint,
    super.transform,
    required this.rect,
  }) : super(type: 'oval');

  @override
  CanvasItem copyWithTransform(Matrix4 newTransform) {
    return OvalItem(id: id, name: name, isVisible: isVisible, enabledIf: enabledIf, paint: paint, rect: rect, transform: newTransform);
  }

  @override
  Map<String, dynamic> toJson() {
    try {
      final data = super.toJson();
      data['rect'] = {'left': rect.left, 'top': rect.top, 'right': rect.right, 'bottom': rect.bottom};
      return data;
    } catch (e) {
      return {};
    }
  }

  factory OvalItem.fromJson(Map<String, dynamic> json) {
    try {
      final rectData = json['rect'] as Map<String, dynamic>;
      return OvalItem(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Unnamed Oval',
        isVisible: json['isVisible'] ?? true,
        enabledIf: json['enabledIf'],
        paint: CanvasPaint.fromJson(json['paint'] ?? {}),
        transform: json['transform'] != null ? Matrix4.fromList(List<double>.from(json['transform'])) : Matrix4.identity(),
        rect: Rect.fromLTRB(
          (rectData['left'] ?? 0.0).toDouble(), (rectData['top'] ?? 0.0).toDouble(),
          (rectData['right'] ?? 0.0).toDouble(), (rectData['bottom'] ?? 0.0).toDouble(),
        ),
      );
    } catch (e) {
      return OvalItem(id: 'err', name: 'Err', rect: Rect.zero, paint: CanvasPaint());
    }
  }
}

class TextItem extends CanvasItem {
  String text;
  Offset position;
  double fontSize;
  bool isBold;

  TextItem({
    required super.id,
    required super.name,
    super.isVisible = true,
    super.enabledIf,
    required super.paint,
    super.transform,
    required this.text,
    required this.position,
    this.fontSize = 24.0,
    this.isBold = false,
  }) : super(type: 'text');

  @override
  CanvasItem copyWithTransform(Matrix4 newTransform) {
    return TextItem(id: id, name: name, isVisible: isVisible, enabledIf: enabledIf, paint: paint, text: text, position: position, fontSize: fontSize, isBold: isBold, transform: newTransform);
  }

  @override
  Map<String, dynamic> toJson() {
    try {
      final data = super.toJson();
      data['text'] = text;
      data['position'] = {'dx': position.dx, 'dy': position.dy};
      data['fontSize'] = fontSize;
      data['isBold'] = isBold;
      return data;
    } catch (e) {
      return {};
    }
  }

  factory TextItem.fromJson(Map<String, dynamic> json) {
    try {
      return TextItem(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Unnamed Text',
        isVisible: json['isVisible'] ?? true,
        enabledIf: json['enabledIf'],
        paint: CanvasPaint.fromJson(json['paint'] ?? {}),
        transform: json['transform'] != null ? Matrix4.fromList(List<double>.from(json['transform'])) : Matrix4.identity(),
        text: json['text'] ?? 'New Text',
        position: Offset(
          (json['position']?['dx'] ?? 0.0).toDouble(),
          (json['position']?['dy'] ?? 0.0).toDouble(),
        ),
        fontSize: (json['fontSize'] ?? 24.0).toDouble(),
        isBold: json['isBold'] ?? false,
      );
    } catch (e) {
      return TextItem(id: 'err', name: 'Err', text: 'Error', position: Offset.zero, paint: CanvasPaint());
    }
  }
}