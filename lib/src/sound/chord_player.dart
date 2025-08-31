import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_service.dart';

class ChordPlayer {
  static bool _initialized = false;

  static Future<void> ensureLoaded(BuildContext context) async {
    if (_initialized) return;
    try {
      // Initialize audio service if not already done
      await AudioService.instance.initialize();
      _initialized = true;
      print('ChordPlayer: Initialized successfully with AudioService');
    } catch (e) {
      print('ChordPlayer: Initialization failed: $e');
      _initialized = false;
    }
  }

  static Future<void> playChord(List<String> notes) async {
    print('ChordPlayer: Attempting to play chord with notes: $notes');
    
    if (!_initialized) {
      print('ChordPlayer: Not initialized!');
      return;
    }
    
    if (notes.isEmpty) {
      print('ChordPlayer: No notes provided!');
      return;
    }

    try {
      print('ChordPlayer: Synthesizing chord...');
      final data = _synthesizePianoChordWav(notes, durationMs: 1500);
      
      if (data.isEmpty) {
        print('ChordPlayer: No audio data generated!');
        return;
      }
      
      print('ChordPlayer: Creating temporary WAV file...');
      // Write WAV data to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/chord_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(data);
      
      print('ChordPlayer: Playing via AudioService...');
      // Use centralized audio service
      await AudioService.instance.playChord(tempFile.path);
      
      print('ChordPlayer: Playback started successfully');
      
      // Clean up temporary file after playback
      Timer(const Duration(seconds: 3), () async {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
            print('ChordPlayer: Cleaned up temporary file');
          }
        } catch (e) {
          print('ChordPlayer: Error cleaning up temp file: $e');
        }
      });
      
    } catch (e) {
      print('ChordPlayer: Error playing chord: $e');
      // Try a simple fallback
      _playTestTone();
    }
  }
  
  static Future<void> _playTestTone() async {
    try {
      print('ChordPlayer: Playing test tone A4...');
      // Generate a simple 440Hz tone for testing
      final testData = _synthesizePianoChordWav(['A4'], durationMs: 1000);
      if (testData.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/test_tone.wav');
        await tempFile.writeAsBytes(testData);
        
        await AudioService.instance.playChord(tempFile.path);
        print('ChordPlayer: Test tone played');
        
        // Clean up after test
        Timer(const Duration(seconds: 2), () async {
          try {
            if (await tempFile.exists()) await tempFile.delete();
          } catch (_) {}
        });
      }
    } catch (e) {
      print('ChordPlayer: Test tone failed: $e');
    }
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
      
      print('ChordPlayer: Note $cleanNote parsed as ${letter}${accidental}$octave (default octave)');

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
    
    print('ChordPlayer: Could not parse note: $cleanNote');
    return null;
  }

  static Uint8List _synthesizePianoChordWav(List<String> noteNames, {int durationMs = 1200, int sampleRate = 44100}) {
    print('Synthesizing chord with notes: $noteNames');
    
    // Convert note names to frequencies; ignore any that fail to parse
    final frequencies = <double>[];
    for (final n in noteNames) {
      final f = _noteNameToFrequency(n);
      if (f != null) {
        frequencies.add(f);
        print('Note $n -> ${f.toStringAsFixed(1)} Hz');
      } else {
        print('Failed to parse note: $n');
      }
    }
    
    if (frequencies.isEmpty) {
      print('No valid frequencies found!');
      return Uint8List(0);
    }
    
    print('Using frequencies: ${frequencies.map((f) => f.toStringAsFixed(1)).join(', ')} Hz');

    final frameCount = ((durationMs / 1000) * sampleRate).round();
    final pcm = Int16List(frameCount);

    // Synthesize clear, audible piano sound
    for (int i = 0; i < frameCount; i++) {
      final t = i / sampleRate;
      double sum = 0;
      
      for (final f in frequencies) {
        // Simpler but more reliable synthesis
        double noteSum = 0;
        
        // Fundamental frequency (clear and strong)
        noteSum += math.sin(2 * math.pi * f * t) * 1.0;
        
        // 2nd harmonic for richness
        noteSum += math.sin(2 * math.pi * f * 2 * t) * 0.3;
        
        // 3rd harmonic for piano character
        noteSum += math.sin(2 * math.pi * f * 3 * t) * 0.15;
        
        // Apply simple but effective envelope
        final envelope = _simpleEnvelope(t, durationMs / 1000.0);
        noteSum *= envelope;
        
        sum += noteSum;
      }
      
      // Higher volume and simpler processing for audibility
      final mixed = (sum / frequencies.length) * 0.9;
      final s = (mixed * 32767).clamp(-32768.0, 32767.0).round();
      pcm[i] = s;
    }

    return _wrapPcm16ToWav(pcm, sampleRate: sampleRate, numChannels: 1);
  }
  
  // Simple envelope for clear audible sound
  static double _simpleEnvelope(double t, double totalDuration) {
    const double attackTime = 0.05;  // 50ms attack
    final double releaseStart = totalDuration * 0.8; // Start release at 80%
    
    if (t < attackTime) {
      // Quick attack
      return t / attackTime;
    } else if (t < releaseStart) {
      // Sustain at full volume
      return 1.0;
    } else {
      // Linear release
      final releaseTime = totalDuration - releaseStart;
      final releaseProgress = (t - releaseStart) / releaseTime;
      return 1.0 - releaseProgress;
    }
  }
  
  // Piano-like envelope: quick attack, slow decay, gentle release
  static double _pianoEnvelope(double t, double totalDuration) {
    const double attackTime = 0.01;  // Very quick attack (10ms)
    const double decayTime = 0.3;    // Decay over 300ms
    const double sustainLevel = 0.3; // Sustain at 30% volume
    final double releaseStart = totalDuration * 0.7; // Start release at 70% through
    
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
      final releaseProgress = (t - releaseStart) / releaseTime;
      return sustainLevel * (1.0 - releaseProgress);
    }
  }
  
  // Soft compression for more natural sound
  static double _softCompression(double input) {
    const double threshold = 0.8;
    const double ratio = 4.0;
    
    final absInput = input.abs();
    if (absInput <= threshold) {
      return input;
    } else {
      final excess = absInput - threshold;
      final compressedExcess = excess / ratio;
      final compressedAbs = threshold + compressedExcess;
      return input.sign * compressedAbs;
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
      print('ChordPlayer: Stopped any current playback');
    } catch (e) {
      print('ChordPlayer: Error stopping playback: $e');
    }
  }

  static Future<void> dispose() async {
    try {
      _initialized = false;
      print('ChordPlayer: Disposed successfully (managed by AudioService)');
    } catch (e) {
      print('ChordPlayer: Disposal error: $e');
    }
  }
}