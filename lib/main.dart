import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/recorder/recorder_page.dart';
import 'src/theme/theme_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const CoraApp(),
    ),
  );
}

class CoraApp extends StatelessWidget {
  const CoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Cora',
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const RecorderPage(),
        );
      },
    );
  }
}
