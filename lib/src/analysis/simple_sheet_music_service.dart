import '../audio/pitch_to_notes.dart';
import '../utils/debug_logger.dart';

enum NoteDuration {
  whole(1.0, '𝅝'),
  half(0.5, '𝅗𝅥'),
  quarter(0.25, '♩'),
  eighth(0.125, '♪'),
  sixteenth(0.0625, '𝅘𝅥𝅯');

  const NoteDuration(this.durationRatio, this.symbol);
  final double durationRatio;
  final String symbol;
}

class SheetMusicNote {
  final String pitchName;
  final int octave;
  final NoteDuration duration;
  final double startBeat;

  SheetMusicNote({
    required this.pitchName,
    required this.octave,
    required this.duration,
    required this.startBeat,
  });

  @override
  String toString() => '$pitchName$octave ${duration.symbol}';

  String get displayNote => '$pitchName$octave';
}

class SheetMusicData {
  final String keySignature;
  final String timeSignature;
  final List<SheetMusicNote> notes;
  final int bpm;

  SheetMusicData({
    required this.keySignature,
    required this.timeSignature,
    required this.notes,
    required this.bpm,
  });

  String get melodyText => notes.map((n) => n.toString()).join(' ');
}

class SimpleSheetMusicService {
  static SheetMusicData convertMelodyToSheetMusic(
    List<DiscreteNote> melody,
    String detectedKey, {
    int bpm = 120,
    String timeSignature = '4/4',
  }) {
    DebugLogger.debug('SimpleSheetMusicService: Converting ${melody.length} notes to sheet music');

    if (melody.isEmpty) {
      DebugLogger.debug('SimpleSheetMusicService: No melody to convert, returning empty sheet');
      return SheetMusicData(
        keySignature: detectedKey,
        timeSignature: timeSignature,
        notes: [],
        bpm: bpm,
      );
    }

    final sheetNotes = <SheetMusicNote>[];
    final msPerBeat = (60000.0 / bpm);

    // Find shortest note to determine base duration unit
    final shortestDuration = melody.map((n) => n.durationMs).reduce((a, b) => a < b ? a : b);
    
    DebugLogger.debug('SimpleSheetMusicService: Shortest note: ${shortestDuration}ms');

    for (int i = 0; i < melody.length; i++) {
      final note = melody[i];
      final pitchData = _parsePitchName(note.note);
      final startBeat = note.startMs / msPerBeat;
      final duration = _quantizeDuration(note.durationMs, msPerBeat);

      final sheetNote = SheetMusicNote(
        pitchName: pitchData.pitchName,
        octave: pitchData.octave,
        duration: duration,
        startBeat: startBeat,
      );

      sheetNotes.add(sheetNote);
      
      DebugLogger.debug('SimpleSheetMusicService: Note ${i + 1}: ${note.note} → $sheetNote');
    }

    final result = SheetMusicData(
      keySignature: detectedKey,
      timeSignature: timeSignature,
      notes: sheetNotes,
      bpm: bpm,
    );

    DebugLogger.debug('SimpleSheetMusicService: Generated sheet music with ${result.notes.length} notes in $detectedKey');
    return result;
  }

  static NoteDuration _quantizeDuration(int durationMs, double msPerBeat) {
    final beatDuration = durationMs / msPerBeat;
    
    // Find closest standard note duration
    if (beatDuration >= 0.75) return NoteDuration.whole;
    if (beatDuration >= 0.375) return NoteDuration.half;
    if (beatDuration >= 0.1875) return NoteDuration.quarter;
    if (beatDuration >= 0.09375) return NoteDuration.eighth;
    return NoteDuration.sixteenth;
  }

  static ({String pitchName, int octave}) _parsePitchName(String note) {
    // Extract pitch class (note name) and determine octave
    final pitchName = note.replaceAll(RegExp(r'\d+'), '').trim();
    
    // Default octave if not specified (common for pitch detection output)
    int octave = 4;
    
    // Try to extract octave number if present
    final octaveMatch = RegExp(r'\d+').firstMatch(note);
    if (octaveMatch != null) {
      octave = int.tryParse(octaveMatch.group(0)!) ?? 4;
    } else {
      // Estimate octave based on pitch class for better display
      octave = _estimateOctave(pitchName);
    }

    return (pitchName: pitchName, octave: octave);
  }

  static int _estimateOctave(String pitchName) {
    // Common vocal range estimation (could be made smarter)
    final pitchOrder = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final pitchIndex = pitchOrder.indexOf(pitchName);
    
    if (pitchIndex == -1) return 4; // Default
    
    // Most human vocals are in octaves 3-5
    if (pitchIndex <= 2) return 4;  // C, C#, D → higher octave
    if (pitchIndex >= 9) return 3;  // A, A#, B → lower octave  
    return 4;                       // Middle range
  }
}