// File: lib/widgets/ui/data_inspector_table.dart
// Description: A tabular view for precision editing of multiple coordinates.

import 'package:flutter/material.dart';

class DataInspectorTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows; // e.g. [{"label": "Node 1", "x": 10.0, "y": -20.0}]

  const DataInspectorTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 12,
        headingRowHeight: 28,
        dataRowMaxHeight: 28,
        columns: const [
          DataColumn(label: Text('Label', style: TextStyle(fontSize: 10))),
          DataColumn(label: Text('X', style: TextStyle(fontSize: 10))),
          DataColumn(label: Text('Y', style: TextStyle(fontSize: 10))),
        ],
        rows: rows.map((row) => DataRow(cells: [
          DataCell(Text(row['label'], style: const TextStyle(fontSize: 10))),
          DataCell(Text(row['x'].toStringAsFixed(1), style: const TextStyle(fontSize: 10))),
          DataCell(Text(row['y'].toStringAsFixed(1), style: const TextStyle(fontSize: 10))),
        ])).toList(),
      ),
    );
  }
}