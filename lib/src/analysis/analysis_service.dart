import 'dart:io';
import '../audio/wav_decoder.dart';
import '../audio/pitch_detector.dart';
import '../audio/pitch_to_notes.dart';
import 'key_detection.dart';
import 'chord_engine.dart' as chord_engine;
import 'chord_progression_suggestion.dart';
import 'detected_chord.dart';

class AnalysisResult {
  final String detectedKey;
  final List<ChordProgressionSuggestion> suggestions;
  AnalysisResult({required this.detectedKey, required this.suggestions});
}

class AnalysisService {
  static Future<AnalysisResult> analyzeRecording(String filePath) async {
    try {
      // 1. Read and decode WAV file
      final bytes = await File(filePath).readAsBytes();
      final wav = WavDecoder.decode(bytes);
      
      if (wav == null || wav.samples.isEmpty) {
        throw Exception('Failed to decode audio file');
      }

      print('AnalysisService: Decoded WAV - ${wav.samples.length} samples, ${wav.sampleRate}Hz');

      // 2. Detect pitches from audio samples
      const detector = PitchDetector();
      final pitches = detector.analyze(wav.samples, wav.sampleRate.toDouble());
      
      if (pitches.isEmpty) {
        print('AnalysisService: No pitches detected, using fallback melody');
        return _getFallbackAnalysis();
      }

      print('AnalysisService: Detected ${pitches.length} pitches');

      // 3. Convert pitches to musical notes with timing
      final notes = PitchToNotes.consolidate(pitches);
      
      if (notes.isEmpty) {
        print('AnalysisService: No notes detected, using fallback melody');
        return _getFallbackAnalysis();
      }

      print('AnalysisService: Converted to ${notes.length} notes');

      // 4. Detect key signature
      final noteNames = notes.map((n) => n.note).toList();
      final keyResult = KeyDetector.detect(noteNames);
      final keyLabel = keyResult.key;
      final isMinor = keyResult.isMinor;

      print('AnalysisService: Detected key: $keyLabel ${isMinor ? 'minor' : 'major'}');

      // 5. Create DetectedNote objects for chord engine
      final melody = notes.map((n) => chord_engine.DetectedNote(
        note: n.note,
        startTime: n.startMs,
        duration: n.durationMs,
      )).toList();

      // 6. Generate chord progressions
      const engine = chord_engine.ChordSuggestionEngine();
      final progs = engine.suggest(melody, keyLabel, isMinor);

      print('AnalysisService: Generated ${progs.length} chord progressions');

      // 7. Convert to UI format
      final uiProgs = progs
          .take(3) // Show up to 3 progressions
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

    } catch (e) {
      print('AnalysisService: Error analyzing recording: $e');
      // Return fallback analysis on error
      return _getFallbackAnalysis();
    }
  }

  static AnalysisResult _getFallbackAnalysis() {
    // Fallback melody in C major for when real analysis fails
    final melody = <chord_engine.DetectedNote>[
      chord_engine.DetectedNote(note: 'C', startTime: 0, duration: 400),
      chord_engine.DetectedNote(note: 'E', startTime: 400, duration: 300),
      chord_engine.DetectedNote(note: 'G', startTime: 700, duration: 300),
      chord_engine.DetectedNote(note: 'A', startTime: 1000, duration: 400),
      chord_engine.DetectedNote(note: 'F', startTime: 1400, duration: 400),
      chord_engine.DetectedNote(note: 'G', startTime: 1800, duration: 400),
      chord_engine.DetectedNote(note: 'C', startTime: 2200, duration: 600),
    ];

    const keyLabel = 'C';
    const isMinor = false;

    const engine = chord_engine.ChordSuggestionEngine();
    final progs = engine.suggest(melody, keyLabel, isMinor);

    final uiProgs = progs
        .take(3)
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
