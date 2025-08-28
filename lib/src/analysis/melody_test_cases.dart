import '../audio/pitch_detector.dart';
import '../audio/pitch_to_notes.dart';
import 'key_detection.dart';
import 'chord_engine.dart' as CE;

class MelodyTestCase {
  final String name;
  final String expectedKey;
  final bool expectedMinor;
  final List<String> expectedChords;
  final List<PitchPoint> pitches;

  MelodyTestCase({
    required this.name,
    required this.expectedKey,
    required this.expectedMinor,
    required this.expectedChords,
    required this.pitches,
  });
}

class MelodyTestRunner {
  static List<MelodyTestCase> getTestCases() {
    return [
      // Simple C Major Scale
      MelodyTestCase(
        name: 'C Major Scale',
        expectedKey: 'C',
        expectedMinor: false,
        expectedChords: ['C', 'F', 'G'],
        pitches: [
          PitchPoint(
              timeSec: 0.0, frequencyHz: 261.63, note: 'C4', cents: 0), // C
          PitchPoint(
              timeSec: 0.5, frequencyHz: 293.66, note: 'D4', cents: 0), // D
          PitchPoint(
              timeSec: 1.0, frequencyHz: 329.63, note: 'E4', cents: 0), // E
          PitchPoint(
              timeSec: 1.5, frequencyHz: 349.23, note: 'F4', cents: 0), // F
          PitchPoint(
              timeSec: 2.0, frequencyHz: 392.00, note: 'G4', cents: 0), // G
          PitchPoint(
              timeSec: 2.5, frequencyHz: 440.00, note: 'A4', cents: 0), // A
          PitchPoint(
              timeSec: 3.0, frequencyHz: 493.88, note: 'B4', cents: 0), // B
          PitchPoint(
              timeSec: 3.5, frequencyHz: 523.25, note: 'C5', cents: 0), // C
        ],
      ),

      // Simple A Minor Scale
      MelodyTestCase(
        name: 'A Minor Scale',
        expectedKey: 'A',
        expectedMinor: true,
        expectedChords: ['Am', 'Dm', 'Em'],
        pitches: [
          PitchPoint(
              timeSec: 0.0, frequencyHz: 440.00, note: 'A4', cents: 0), // A
          PitchPoint(
              timeSec: 0.5, frequencyHz: 493.88, note: 'B4', cents: 0), // B
          PitchPoint(
              timeSec: 1.0, frequencyHz: 523.25, note: 'C5', cents: 0), // C
          PitchPoint(
              timeSec: 1.5, frequencyHz: 587.33, note: 'D5', cents: 0), // D
          PitchPoint(
              timeSec: 2.0, frequencyHz: 659.25, note: 'E5', cents: 0), // E
          PitchPoint(
              timeSec: 2.5, frequencyHz: 698.46, note: 'F5', cents: 0), // F
          PitchPoint(
              timeSec: 3.0, frequencyHz: 783.99, note: 'G5', cents: 0), // G
          PitchPoint(
              timeSec: 3.5, frequencyHz: 880.00, note: 'A5', cents: 0), // A
        ],
      ),

      // C Major Arpeggio (C-E-G-C)
      MelodyTestCase(
        name: 'C Major Arpeggio',
        expectedKey: 'C',
        expectedMinor: false,
        expectedChords: ['C'],
        pitches: [
          PitchPoint(
              timeSec: 0.0, frequencyHz: 261.63, note: 'C4', cents: 0), // C
          PitchPoint(
              timeSec: 0.5, frequencyHz: 329.63, note: 'E4', cents: 0), // E
          PitchPoint(
              timeSec: 1.0, frequencyHz: 392.00, note: 'G4', cents: 0), // G
          PitchPoint(
              timeSec: 1.5, frequencyHz: 523.25, note: 'C5', cents: 0), // C
        ],
      ),

      // Popular Progression: C - Am - F - G
      MelodyTestCase(
        name: 'Popular I-vi-IV-V Melody',
        expectedKey: 'C',
        expectedMinor: false,
        expectedChords: ['C', 'Am', 'F', 'G'],
        pitches: [
          // C chord tones
          PitchPoint(timeSec: 0.0, frequencyHz: 523.25, note: 'C5', cents: 0),
          PitchPoint(timeSec: 0.3, frequencyHz: 329.63, note: 'E4', cents: 0),
          PitchPoint(timeSec: 0.6, frequencyHz: 392.00, note: 'G4', cents: 0),

          // Am chord tones
          PitchPoint(timeSec: 1.0, frequencyHz: 440.00, note: 'A4', cents: 0),
          PitchPoint(timeSec: 1.3, frequencyHz: 523.25, note: 'C5', cents: 0),
          PitchPoint(timeSec: 1.6, frequencyHz: 659.25, note: 'E5', cents: 0),

          // F chord tones
          PitchPoint(timeSec: 2.0, frequencyHz: 698.46, note: 'F5', cents: 0),
          PitchPoint(timeSec: 2.3, frequencyHz: 440.00, note: 'A4', cents: 0),
          PitchPoint(timeSec: 2.6, frequencyHz: 523.25, note: 'C5', cents: 0),

          // G chord tones
          PitchPoint(timeSec: 3.0, frequencyHz: 783.99, note: 'G5', cents: 0),
          PitchPoint(timeSec: 3.3, frequencyHz: 493.88, note: 'B4', cents: 0),
          PitchPoint(timeSec: 3.6, frequencyHz: 587.33, note: 'D5', cents: 0),
        ],
      ),
    ];
  }

  static void runAllTests() {
    print('\n=== MELODY TEST RUNNER START ===');
    final testCases = getTestCases();
    int passed = 0;
    int total = testCases.length;

    for (final test in testCases) {
      print('\n--- Testing: ${test.name} ---');
      final result = runSingleTest(test);
      if (result) {
        passed++;
        print('✓ PASSED');
      } else {
        print('✗ FAILED');
      }
    }

    print('\n=== MELODY TEST RUNNER SUMMARY ===');
    print('Tests passed: $passed / $total');
    print('Success rate: ${((passed / total) * 100).toStringAsFixed(1)}%');
    print('=== END ===\n');
  }

  static bool runSingleTest(MelodyTestCase test) {
    try {
      // Step 1: Convert pitches to discrete notes
      final discrete = PitchToNotes.consolidate(test.pitches);

      // Step 2: Detect key
      final notes = discrete.map((d) => d.note).toList();
      final keyResult = KeyDetector.detect(notes);

      // Step 3: Generate chord suggestions
      final ceNotes = discrete
          .map((d) => CE.DetectedNote(
                note: d.note,
                startTime: d.startMs,
                duration: d.durationMs,
              ))
          .toList();

      const engine = CE.ChordSuggestionEngine();
      final suggestions =
          engine.suggest(ceNotes, keyResult.key, keyResult.isMinor);

      // Evaluate results
      bool keyCorrect = (keyResult.key == test.expectedKey &&
          keyResult.isMinor == test.expectedMinor);
      bool hasChords = suggestions.isNotEmpty;

      print(
          'Expected: ${test.expectedKey} ${test.expectedMinor ? 'minor' : 'major'}');
      print(
          'Detected: ${keyResult.key} ${keyResult.isMinor ? 'minor' : 'major'} (${keyCorrect ? '✓' : '✗'})');
      print(
          'Chord suggestions: ${hasChords ? suggestions.first.chords.map((c) => c.symbol).join(', ') : 'NONE'} (${hasChords ? '✓' : '✗'})');

      return keyCorrect && hasChords;
    } catch (e, stackTrace) {
      print('ERROR in test: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }
}
