import 'package:flutter/material.dart';
import 'src/recorder/recorder_page.dart';

void main() {
  runApp(const CoraApp());
}

class CoraApp extends StatelessWidget {
  const CoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cora',
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      home: const RecorderPage(),
    );
  }
}
