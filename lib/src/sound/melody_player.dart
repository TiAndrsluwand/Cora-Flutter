import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_service.dart';
import '../audio/pitch_to_notes.dart';

class MelodyPlayer {
  static bool _initialized = false;

  static Future<void> ensureLoaded(BuildContext context) async {
    if (_initialized) return;
    try {
      // Initialize audio service if not already done
      await AudioService.instance.initialize();
      _initialized = true;
      print('MelodyPlayer: Initialized successfully with AudioService');
    } catch (e) {
      print('MelodyPlayer: Initialization failed: $e');
      _initialized = false;
    }
  }

  static Future<void> playMelody(List<DiscreteNote> melody) async {
    print('MelodyPlayer: Attempting to play melody with ${melody.length} notes');
    
    if (!_initialized) {
      print('MelodyPlayer: Not initialized!');
      return;
    }
    
    if (melody.isEmpty) {
      print('MelodyPlayer: No notes provided!');
      return;
    }

    try {
      print('MelodyPlayer: Synthesizing melody...');
      final data = _synthesizeMelodyWav(melody);
      
      if (data.isEmpty) {
        print('MelodyPlayer: No audio data generated!');
        return;
      }
      
      print('MelodyPlayer: Creating temporary WAV file...');
      // Write WAV data to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/melody_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(data);
      
      print('MelodyPlayer: Playing via AudioService...');
      // Use centralized audio service
      await AudioService.instance.playMelody(tempFile.path);
      
      print('MelodyPlayer: Playback started successfully');
      
      // Clean up temporary file after playback
      final totalDurationMs = _calculateTotalDuration(melody);
      final cleanupDelay = Duration(milliseconds: totalDurationMs + 2000); // Add 2s buffer
      
      Timer(cleanupDelay, () async {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
            print('MelodyPlayer: Cleaned up temporary file');
          }
        } catch (e) {
          print('MelodyPlayer: Error cleaning up temp file: $e');
        }
      });
      
    } catch (e) {
      print('MelodyPlayer: Error playing melody: $e');
      // Try a simple fallback
      _playTestMelody();
    }
  }
  
  static Future<void> _playTestMelody() async {
    try {
      print('MelodyPlayer: Playing PRECISION test melody C-D-E-F...');
      // Generate a PRECISION test melody for timing validation
      final testMelody = [
        DiscreteNote(note: 'C', startMs: 0, durationMs: 1000),     // 0-1 seconds
        DiscreteNote(note: 'D', startMs: 1000, durationMs: 1000), // 1-2 seconds  
        DiscreteNote(note: 'E', startMs: 2000, durationMs: 1000), // 2-3 seconds
        DiscreteNote(note: 'F', startMs: 3000, durationMs: 1000), // 3-4 seconds
      ];
      
      print('MelodyPlayer: Test melody timing validation:');
      for (int i = 0; i < testMelody.length; i++) {
        final note = testMelody[i];
        print('  Note $i: ${note.note} should play at ${note.startMs / 1000}s for ${note.durationMs / 1000}s');
      }
      
      final testData = _synthesizeMelodyWav(testMelody);
      if (testData.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/test_melody_timing.wav');
        await tempFile.writeAsBytes(testData);
        
        await AudioService.instance.playMelody(tempFile.path);
        print('MelodyPlayer: TIMING TEST - Listen carefully: C at 0s, D at 1s, E at 2s, F at 3s');
        
        // Clean up after test
        Timer(const Duration(seconds: 6), () async {
          try {
            if (await tempFile.exists()) await tempFile.delete();
          } catch (_) {}
        });
      }
    } catch (e) {
      print('MelodyPlayer: Test melody failed: $e');
    }
  }

  static int _calculateTotalDuration(List<DiscreteNote> melody) {
    if (melody.isEmpty) return 0;
    
    int maxEndTime = 0;
    for (final note in melody) {
      final endTime = note.startMs + note.durationMs;
      if (endTime > maxEndTime) {
        maxEndTime = endTime;
      }
    }
    return maxEndTime;
  }

  static double? _noteNameToFrequency(String noteName) {
    String cleanNote = noteName.trim();
    
    // First try to match note with octave: C4, F#5, Bb3, etc.
    final matchWithOctave = RegExp(r'^([A-Ga-g])(#|b)?(\d+)$').firstMatch(cleanNote);
    if (matchWithOctave != null) {
      final letter = matchWithOctave.group(1)!.toUpperCase();
      final accidental = matchWithOctave.group(2) ?? '';
      final octave = int.parse(matchWithOctave.group(3)!);

      final semitoneMap = {
        'C': 0, 'C#': 1, 'Db': 1,
        'D': 2, 'D#': 3, 'Eb': 3,
        'E': 4,
        'F': 5, 'F#': 6, 'Gb': 6,
        'G': 7, 'G#': 8, 'Ab': 8,
        'A': 9, 'A#': 10, 'Bb': 10,
        'B': 11,
      };
      
      final key = '$letter$accidental';
      final semitone = semitoneMap[key];
      if (semitone == null) return null;
      
      final midi = (octave + 1) * 12 + semitone;
      return 440 * math.pow(2, (midi - 69) / 12).toDouble();
    }
    
    // Fallback: try to match note without octave and default to octave 4
    final matchWithoutOctave = RegExp(r'^([A-Ga-g])(#|b)?$').firstMatch(cleanNote);
    if (matchWithoutOctave != null) {
      final letter = matchWithoutOctave.group(1)!.toUpperCase();
      final accidental = matchWithoutOctave.group(2) ?? '';
      final octave = 4; // Default to octave 4
      
      print('MelodyPlayer: Note $cleanNote parsed as ${letter}${accidental}$octave (default octave)');

      final semitoneMap = {
        'C': 0, 'C#': 1, 'Db': 1,
        'D': 2, 'D#': 3, 'Eb': 3,
        'E': 4,
        'F': 5, 'F#': 6, 'Gb': 6,
        'G': 7, 'G#': 8, 'Ab': 8,
        'A': 9, 'A#': 10, 'Bb': 10,
        'B': 11,
      };
      
      final key = '$letter$accidental';
      final semitone = semitoneMap[key];
      if (semitone == null) return null;
      
      final midi = (octave + 1) * 12 + semitone;
      return 440 * math.pow(2, (midi - 69) / 12).toDouble();
    }
    
    print('MelodyPlayer: Could not parse note: $cleanNote');
    return null;
  }

  static Uint8List _synthesizeMelodyWav(List<DiscreteNote> melody, {int sampleRate = 48000}) { // UPDATED: Match new ultra-smooth recording config (48kHz)
    print('MelodyPlayer: Synthesizing melody with ${melody.length} notes');
    
    if (melody.isEmpty) {
      print('MelodyPlayer: No notes provided!');
      return Uint8List(0);
    }

    // Calculate total duration and create buffer
    final totalDurationMs = _calculateTotalDuration(melody);
    final frameCount = ((totalDurationMs / 1000) * sampleRate).round();
    final pcm = Int16List(frameCount);
    
    print('MelodyPlayer: Total duration: ${totalDurationMs}ms, Frames: $frameCount, Sample rate: ${sampleRate}Hz');
    print('=== MELODY SYNTHESIS DEBUG ===');

    // Synthesize each note at its exact timing
    for (int noteIndex = 0; noteIndex < melody.length; noteIndex++) {
      final note = melody[noteIndex];
      final frequency = _noteNameToFrequency(note.note);
      if (frequency == null) {
        print('MelodyPlayer: Skipping unparseable note: ${note.note}');
        continue;
      }

      // CRITICAL FRAME CALCULATIONS
      final startFrame = ((note.startMs / 1000) * sampleRate).round();
      final durationFrames = ((note.durationMs / 1000) * sampleRate).round();
      final endFrame = (startFrame + durationFrames).clamp(0, frameCount);
      
      // Calculate timing in seconds for validation
      final startSeconds = note.startMs / 1000.0;
      final durationSeconds = note.durationMs / 1000.0;
      final endSeconds = startSeconds + durationSeconds;
      
      print('Note $noteIndex: ${note.note} (${frequency.toStringAsFixed(1)}Hz)');
      print('  Original timing: ${note.startMs}ms - ${note.startMs + note.durationMs}ms (${note.durationMs}ms duration)');
      print('  Frame calculation: ${startFrame} - ${endFrame} (${durationFrames} frames)');
      print('  Validated timing: ${startSeconds.toStringAsFixed(3)}s - ${endSeconds.toStringAsFixed(3)}s');
      
      // Check for frame positioning errors
      if (startFrame >= frameCount) {
        print('  WARNING: Start frame ${startFrame} exceeds buffer size ${frameCount}!');
        continue;
      }
      if (endFrame > frameCount) {
        print('  WARNING: End frame ${endFrame} exceeds buffer size ${frameCount}, clamping to ${frameCount}');
      }

      // Synthesize this note
      for (int i = startFrame; i < endFrame; i++) {
        if (i >= frameCount) break;
        
        final t = (i - startFrame) / sampleRate; // Time relative to note start
        final noteDurationSecs = note.durationMs / 1000.0;
        
        // Synthesize with harmonics for natural sound
        double noteSum = 0;
        
        // Fundamental frequency (clear and strong)
        noteSum += math.sin(2 * math.pi * frequency * t) * 1.0;
        
        // 2nd harmonic for richness
        noteSum += math.sin(2 * math.pi * frequency * 2 * t) * 0.3;
        
        // 3rd harmonic for warmth
        noteSum += math.sin(2 * math.pi * frequency * 3 * t) * 0.15;
        
        // Apply ADSR envelope for smooth transitions
        final envelope = _adsrEnvelope(t, noteDurationSecs);
        noteSum *= envelope;
        
        // Mix with existing audio (in case of overlapping notes)
        final existing = pcm[i] / 32767.0; // Normalize existing sample
        final mixed = (existing + noteSum * 0.8).clamp(-1.0, 1.0); // Softer volume for melody
        pcm[i] = (mixed * 32767).round();
      }
    }
    
    print('=== END MELODY SYNTHESIS DEBUG ===');
    print('MelodyPlayer: Synthesis complete, creating WAV file');
    print('MelodyPlayer: Final buffer size: ${pcm.length} samples (${(pcm.length / sampleRate).toStringAsFixed(3)}s duration)');
    
    return _wrapPcm16ToWav(pcm, sampleRate: sampleRate, numChannels: 1);
  }

  // ADSR envelope for natural note transitions
  static double _adsrEnvelope(double t, double totalDuration) {
    const double attackTime = 0.01;   // 10ms quick attack
    const double decayTime = 0.05;    // 50ms decay
    const double sustainLevel = 0.7;  // Sustain at 70% volume
    final double releaseStart = math.max(totalDuration * 0.8, totalDuration - 0.05); // Start release with 50ms minimum
    
    if (t < attackTime) {
      // Attack phase: 0 to 1
      return t / attackTime;
    } else if (t < attackTime + decayTime) {
      // Decay phase: 1 to sustainLevel
      final decayProgress = (t - attackTime) / decayTime;
      return 1.0 - (1.0 - sustainLevel) * decayProgress;
    } else if (t < releaseStart) {
      // Sustain phase: constant sustainLevel
      return sustainLevel;
    } else {
      // Release phase: sustainLevel to 0
      final releaseTime = totalDuration - releaseStart;
      if (releaseTime <= 0) return 0; // Prevent division by zero for very short notes
      final releaseProgress = (t - releaseStart) / releaseTime;
      return sustainLevel * (1.0 - releaseProgress).clamp(0.0, 1.0);
    }
  }

  static Uint8List _wrapPcm16ToWav(Int16List samples, {required int sampleRate, int numChannels = 1}) {
    final byteRate = sampleRate * numChannels * 2; // 16-bit
    final blockAlign = numChannels * 2;
    final dataSize = samples.length * 2;
    final fileSize = 44 - 8 + dataSize;

    final header = ByteData(44);
    // RIFF header
    header.setUint32(0, 0x46464952, Endian.little); // 'RIFF'
    header.setUint32(4, fileSize, Endian.little);
    header.setUint32(8, 0x45564157, Endian.little); // 'WAVE'
    // fmt chunk
    header.setUint32(12, 0x20746d66, Endian.little); // 'fmt '
    header.setUint32(16, 16, Endian.little); // PCM chunk size
    header.setUint16(20, 1, Endian.little); // audio format = PCM
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, 16, Endian.little); // bits per sample
    // data chunk
    header.setUint32(36, 0x61746164, Endian.little); // 'data'
    header.setUint32(40, dataSize, Endian.little);

    final bytes = Uint8List(44 + dataSize);
    bytes.setAll(0, header.buffer.asUint8List());
    bytes.setAll(44, samples.buffer.asUint8List());
    return bytes;
  }

  static Future<void> stopAnyPlayback() async {
    try {
      await AudioService.instance.stopAll();
      print('MelodyPlayer: Stopped any current playback');
    } catch (e) {
      print('MelodyPlayer: Error stopping playback: $e');
    }
  }

  static Future<void> dispose() async {
    try {
      _initialized = false;
      print('MelodyPlayer: Disposed successfully (managed by AudioService)');
    } catch (e) {
      print('MelodyPlayer: Disposal error: $e');
    }
  }
}