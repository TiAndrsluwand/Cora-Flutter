/// Stub for chord suggestion engine. Replace with real implementation.
class ChordSuggestionEngineStub {
  final int maxProgressions;
  final int minChordDurationMs;
  final bool extendedChords;
  final double jazziness;

  ChordSuggestionEngineStub({
    this.maxProgressions = 1,
    this.minChordDurationMs = 800,
    this.extendedChords = false,
    this.jazziness = 0.1,
  });

  List<Map<String, dynamic>> suggest(List<String> detectedNotes, Map<String, dynamic> melodyAnalysis) {
    // TODO: Port the TS engine to Dart
    return <Map<String, dynamic>>[];
  }
}
