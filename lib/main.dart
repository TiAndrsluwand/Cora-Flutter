import 'package:flutter/material.dart';
import 'src/recorder/recorder_page_minimal.dart';
import 'src/theme/minimal_design_system.dart';

void main() {
  runApp(const CoraApp());
}

class CoraApp extends StatefulWidget {
  const CoraApp({super.key});

  @override
  State<CoraApp> createState() => _CoraAppState();
}

class _CoraAppState extends State<CoraApp> {
  
  void _toggleTheme() {
    setState(() {
      MinimalDesign.setDarkMode(!MinimalDesign.isDarkMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cora',
      theme: MinimalDesign.theme,
      home: RecorderPage(onThemeToggle: _toggleTheme),
    );
  }
}
