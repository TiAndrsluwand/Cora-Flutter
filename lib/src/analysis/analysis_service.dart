import 'chord_engine.dart' as CE;
import 'chord_progression_suggestion.dart';
import 'detected_chord.dart';

class AnalysisResult {
  final String detectedKey;
  final List<ChordProgressionSuggestion> suggestions;
  AnalysisResult({required this.detectedKey, required this.suggestions});
}

class AnalysisService {
  static Future<AnalysisResult> analyzeRecording(String filePath) async {
    // TODO: Decode file and detect notes; for now mock a melody in C
    final melody = <CE.DetectedNote>[
      CE.DetectedNote(note: 'C', startTime: 0, duration: 400),
      CE.DetectedNote(note: 'E', startTime: 400, duration: 300),
      CE.DetectedNote(note: 'G', startTime: 700, duration: 300),
      CE.DetectedNote(note: 'A', startTime: 1000, duration: 400),
      CE.DetectedNote(note: 'F', startTime: 1400, duration: 400),
      CE.DetectedNote(note: 'G', startTime: 1800, duration: 400),
      CE.DetectedNote(note: 'C', startTime: 2200, duration: 600),
    ];

    const keyLabel = 'C';
    const isMinor = false;

    const engine = CE.ChordSuggestionEngine();
    final progs = engine.suggest(melody, keyLabel, isMinor);

    final uiProgs = progs
        .take(1)
        .map((p) => ChordProgressionSuggestion(
              name: p.name,
              key: '${p.key} ${p.scale == 'NATURAL_MINOR' ? 'minor' : 'major'}',
              chords: p.chords
                  .map((c) => DetectedChord(
                      symbol: c.symbol, notes: _voiceChord(c.notes)))
                  .toList(),
            ))
        .toList();

    return AnalysisResult(
      detectedKey: '$keyLabel ${isMinor ? 'minor' : 'major'}',
      suggestions: uiProgs,
    );
  }

  static List<String> _voiceChord(List<String> triad) {
    // Map note names to specific octaves for nicer playback
    final octaveMap = {
      'C': 'C4',
      'C#': 'C#4',
      'D': 'D4',
      'D#': 'D#4',
      'E': 'E4',
      'F': 'F4',
      'F#': 'F#4',
      'G': 'G4',
      'G#': 'G#4',
      'A': 'A4',
      'A#': 'A#4',
      'B': 'B4'
    };
    return triad.map((n) => octaveMap[n] ?? n).toList();
  }
}
