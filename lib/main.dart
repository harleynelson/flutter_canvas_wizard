// File: lib/main.dart
// Description: Entry point for the application, initializing Riverpod and the main app theme.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/editor_screen.dart';

void main() {
  try {
    runApp(
      const ProviderScope(
        child: CanvasWizardApp(),
      ),
    );
  } catch (e) {
    print('DEBUG ERROR: App initialization failed: $e');
  }
}

class CanvasWizardApp extends StatelessWidget {
  const CanvasWizardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Canvas Wizard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      ),
      home: const EditorScreen(),
    );
  }
}