import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/src/widgets/minimal_analyzing_animation.dart';

void main() {
  group('MinimalAnalyzingAnimation Tests', () {
    testWidgets('Animation widget displays all components', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MinimalAnalyzingAnimation(),
          ),
        ),
      );

      // Let initial layout complete
      await tester.pump();
      
      // Find the animated elements
      expect(find.textContaining('Analyzing melody'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets); // Wave animation and others
      
      // Verify animation elements are present after some time
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Analyzing melody'), findsOneWidget);
    });

    testWidgets('Animation persists through time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MinimalAnalyzingAnimation(),
          ),
        ),
      );

      await tester.pump();
      
      // Test animation persistence over time
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('Analyzing melody'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets); // Wave animation and others
      }
    });

    testWidgets('Animation can be created and disposed', (tester) async {
      // Create animation
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MinimalAnalyzingAnimation(),
          ),
        ),
      );

      await tester.pump();
      expect(find.textContaining('Analyzing melody'), findsOneWidget);

      // Replace with different widget to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Different Widget'),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Different Widget'), findsOneWidget);
      expect(find.textContaining('Analyzing melody'), findsNothing);
    });
  });
}