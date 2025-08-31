import 'dart:isolate';
import 'dart:io';
import '../audio/wav_decoder.dart';
import '../audio/pitch_detector.dart';
import '../audio/pitch_to_notes.dart';
import 'key_detection.dart';
import 'chord_engine.dart' as chord_engine;
import 'chord_progression_suggestion.dart';
import 'detected_chord.dart';
import 'analysis_service.dart';

/// Message sent to isolate with analysis parameters
class AnalysisRequest {
  final String filePath;
  final SendPort responsePort;
  
  AnalysisRequest({
    required this.filePath, 
    required this.responsePort
  });
}

/// Response from isolate with analysis results
class AnalysisResponse {
  final bool success;
  final String? error;
  final AnalysisResult? result;
  
  AnalysisResponse.success(this.result) : success = true, error = null;
  AnalysisResponse.error(this.error) : success = false, result = null;
}

/// Isolate-based analysis service that runs heavy operations in background
class AnalysisIsolate {
  static Future<AnalysisResult> analyzeRecording(String filePath) async {
    // Create a ReceivePort to get the result back from the isolate
    final receivePort = ReceivePort();
    
    try {
      // Spawn an isolate to perform the analysis
      await Isolate.spawn(
        _analyzeInIsolate,
        AnalysisRequest(
          filePath: filePath,
          responsePort: receivePort.sendPort,
        ),
      );
      
      // Wait for the result from the isolate
      final response = await receivePort.first as AnalysisResponse;
      
      if (response.success) {
        return response.result!;
      } else {
        throw Exception(response.error);
      }
    } finally {
      receivePort.close();
    }
  }
  
  /// Entry point for the isolate - performs heavy analysis operations
  static void _analyzeInIsolate(AnalysisRequest request) async {
    try {
      // Perform the same analysis as AnalysisService but in isolate
      final result = await _performAnalysis(request.filePath);
      
      // Send success response back
      request.responsePort.send(AnalysisResponse.success(result));
    } catch (e) {
      // Send error response back
      request.responsePort.send(AnalysisResponse.error(e.toString()));
    }
  }
  
  /// Core analysis logic - same as AnalysisService but isolated
  static Future<AnalysisResult> _performAnalysis(String filePath) async {
    // 1. Read and decode WAV file
    final bytes = await File(filePath).readAsBytes();
    final wav = WavDecoder.decode(bytes);
    
    if (wav == null || wav.samples.isEmpty) {
      throw Exception('Failed to decode audio file');
    }

    // 2. Detect pitches from audio samples
    const detector = PitchDetector();
    final pitches = detector.analyze(wav.samples, wav.sampleRate.toDouble());
    
    if (pitches.isEmpty) {
      return _getFallbackAnalysis();
    }

    // 3. Convert pitches to musical notes with timing
    final notes = PitchToNotes.consolidate(pitches);
    
    if (notes.isEmpty) {
      return _getFallbackAnalysis();
    }

    // 4. Detect key signature
    final noteNames = notes.map((n) => n.note).toList();
    final keyResult = KeyDetector.detect(noteNames);
    final keyLabel = keyResult.key;
    final isMinor = keyResult.isMinor;

    // 5. Create DetectedNote objects for chord engine
    final melody = notes.map((n) => chord_engine.DetectedNote(
      note: n.note,
      startTime: n.startMs,
      duration: n.durationMs,
    )).toList();

    // 6. Generate chord progressions
    const engine = chord_engine.ChordSuggestionEngine();
    final progs = engine.suggest(melody, keyLabel, isMinor);

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

    // If no progressions generated but we have notes, create simple fallback
    if (uiProgs.isEmpty && noteNames.isNotEmpty) {
      return _createSimpleFallback(keyLabel, isMinor);
    }

    return AnalysisResult(
      detectedKey: '$keyLabel ${isMinor ? 'minor' : 'major'}',
      suggestions: uiProgs,
    );
  }

  static AnalysisResult _getFallbackAnalysis() {
    return AnalysisResult(
      detectedKey: 'C major', 
      suggestions: const [],
    );
  }

  static AnalysisResult _createSimpleFallback(String keyLabel, bool isMinor) {
    // Create basic chord progression based on detected key
    final List<DetectedChord> chords;
    final String progressionName;
    
    if (isMinor) {
      // Simple minor progression: i - iv - V - i
      progressionName = "Basic Minor Progression";
      chords = [
        DetectedChord(symbol: '${keyLabel}m', notes: _voiceChord([keyLabel, _getNoteAtInterval(keyLabel, 3), _getNoteAtInterval(keyLabel, 7)])),
        DetectedChord(symbol: '${_getNoteAtInterval(keyLabel, 5)}m', notes: _voiceChord([_getNoteAtInterval(keyLabel, 5), _getNoteAtInterval(keyLabel, 8), _getNoteAtInterval(keyLabel, 12)])),
        DetectedChord(symbol: _getNoteAtInterval(keyLabel, 7), notes: _voiceChord([_getNoteAtInterval(keyLabel, 7), _getNoteAtInterval(keyLabel, 11), _getNoteAtInterval(keyLabel, 14)])),
        DetectedChord(symbol: '${keyLabel}m', notes: _voiceChord([keyLabel, _getNoteAtInterval(keyLabel, 3), _getNoteAtInterval(keyLabel, 7)])),
      ];
    } else {
      // Simple major progression: I - IV - V - I
      progressionName = "Basic Major Progression";
      chords = [
        DetectedChord(symbol: keyLabel, notes: _voiceChord([keyLabel, _getNoteAtInterval(keyLabel, 4), _getNoteAtInterval(keyLabel, 7)])),
        DetectedChord(symbol: _getNoteAtInterval(keyLabel, 5), notes: _voiceChord([_getNoteAtInterval(keyLabel, 5), _getNoteAtInterval(keyLabel, 9), _getNoteAtInterval(keyLabel, 12)])),
        DetectedChord(symbol: _getNoteAtInterval(keyLabel, 7), notes: _voiceChord([_getNoteAtInterval(keyLabel, 7), _getNoteAtInterval(keyLabel, 11), _getNoteAtInterval(keyLabel, 14)])),
        DetectedChord(symbol: keyLabel, notes: _voiceChord([keyLabel, _getNoteAtInterval(keyLabel, 4), _getNoteAtInterval(keyLabel, 7)])),
      ];
    }
    
    final suggestion = ChordProgressionSuggestion(
      name: progressionName,
      key: '$keyLabel ${isMinor ? 'minor' : 'major'}',
      chords: chords,
    );
    
    return AnalysisResult(
      detectedKey: '$keyLabel ${isMinor ? 'minor' : 'major'}',
      suggestions: [suggestion],
    );
  }

  static String _getNoteAtInterval(String rootNote, int semitones) {
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final rootIndex = notes.indexOf(rootNote);
    if (rootIndex == -1) return rootNote;
    final targetIndex = (rootIndex + semitones) % 12;
    return notes[targetIndex];
  }

  static List<String> _voiceChord(List<String> triad) {
    // Map note names to specific octaves for nicer playback
    final octaveMap = {
      'C': 'C4', 'C#': 'C#4', 'Db': 'Db4',
      'D': 'D4', 'D#': 'D#4', 'Eb': 'Eb4',
      'E': 'E4',
      'F': 'F4', 'F#': 'F#4', 'Gb': 'Gb4',
      'G': 'G4', 'G#': 'G#4', 'Ab': 'Ab4',
      'A': 'A4', 'A#': 'A#4', 'Bb': 'Bb4',
      'B': 'B4',
    };

    return triad.map((note) => octaveMap[note] ?? '${note}4').toList();
  }
}