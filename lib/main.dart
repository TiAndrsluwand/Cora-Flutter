import 'package:flutter/material.dart';
import 'src/recorder/recorder_page_minimal.dart';
import 'src/theme/minimal_design_system.dart';

void main() {
  runApp(const CoraApp());
}

class CoraApp extends StatelessWidget {
  const CoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cora',
      theme: MinimalDesign.theme,
      home: const RecorderPage(),
    );
  }
}
