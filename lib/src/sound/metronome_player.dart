import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

enum RecordingPhase {
  idle,
  countIn,
  recording,
}

class TimeSignature {
  final int numerator;
  final int denominator;
  
  const TimeSignature(this.numerator, this.denominator);
  
  @override
  String toString() => '$numerator/$denominator';
  
  static const common = [
    TimeSignature(4, 4),
    TimeSignature(3, 4),
    TimeSignature(2, 4),
    TimeSignature(6, 8),
    TimeSignature(2, 2),
  ];
}

class MetronomePlayer {
  static final AudioPlayer _strongBeatPlayer = AudioPlayer();
  static final AudioPlayer _weakBeatPlayer = AudioPlayer();
  static bool _initialized = false;
  static Timer? _metronomeTimer;
  static int _currentBeat = 0;
  static RecordingPhase _phase = RecordingPhase.idle;
  
  // Pre-generated audio files for metronome beats
  static String? _strongBeatPath;
  static String? _weakBeatPath;
  
  // Metronome settings
  static int _bpm = 120;
  static TimeSignature _timeSignature = const TimeSignature(4, 4);
  static bool _enabled = false;
  static bool _continueMetronomeDuringRecording = true;
  static double _volume = 0.8;
  
  // Beat callbacks
  static Function(int beat, int totalBeats, RecordingPhase phase)? _onBeatCallback;
  static Function()? _onCountInComplete;
  
  static Future<void> ensureLoaded(BuildContext context) async {
    if (_initialized) return;
    try {
      // Pre-generate metronome sound files and load into players
      await _generateAndLoadMetronomeSounds();
      
      _initialized = true;
      print('MetronomePlayer: Initialized successfully');
    } catch (e) {
      print('MetronomePlayer: Initialization failed: $e');
      _initialized = false;
    }
  }
  
  static Future<void> _generateAndLoadMetronomeSounds() async {
    try {
      final tempDir = await getTemporaryDirectory();
      
      // Generate strong beat sound (1200Hz)
      final strongBeatData = _synthesizeClickWav(1200.0, durationMs: 100);
      final strongBeatFile = File('${tempDir.path}/metronome_strong.wav');
      await strongBeatFile.writeAsBytes(strongBeatData);
      _strongBeatPath = strongBeatFile.path;
      
      // Generate weak beat sound (800Hz)
      final weakBeatData = _synthesizeClickWav(800.0, durationMs: 100);
      final weakBeatFile = File('${tempDir.path}/metronome_weak.wav');
      await weakBeatFile.writeAsBytes(weakBeatData);
      _weakBeatPath = weakBeatFile.path;
      
      // Load audio files into players ONCE (this creates ExoPlayerImpl instances)
      await _strongBeatPlayer.setFilePath(_strongBeatPath!);
      await _strongBeatPlayer.setVolume(_volume);
      await _weakBeatPlayer.setFilePath(_weakBeatPath!);
      await _weakBeatPlayer.setVolume(_volume);
      
      print('MetronomePlayer: Pre-generated and loaded metronome sounds');
    } catch (e) {
      print('MetronomePlayer: Error generating sounds: $e');
    }
  }

  // Getters for current settings
  static int get bpm => _bpm;
  static TimeSignature get timeSignature => _timeSignature;
  static bool get enabled => _enabled;
  static bool get continueMetronomeDuringRecording => _continueMetronomeDuringRecording;
  static double get volume => _volume;
  static RecordingPhase get currentPhase => _phase;
  static int get currentBeat => _currentBeat;
  
  // Setters for metronome settings
  static void setBpm(int newBpm) {
    _bpm = newBpm.clamp(60, 200);
  }
  
  static void setTimeSignature(TimeSignature newTimeSignature) {
    _timeSignature = newTimeSignature;
  }
  
  static void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled && _metronomeTimer != null) {
      stopMetronome();
    }
  }
  
  static void setContinueMetronomeDuringRecording(bool shouldContinue) {
    _continueMetronomeDuringRecording = shouldContinue;
  }
  
  static void setVolume(double newVolume) {
    _volume = newVolume.clamp(0.0, 1.0);
    _strongBeatPlayer.setVolume(_volume);
    _weakBeatPlayer.setVolume(_volume);
  }
  
  static void setBeatCallback(Function(int beat, int totalBeats, RecordingPhase phase)? callback) {
    _onBeatCallback = callback;
  }
  
  static void setCountInCompleteCallback(Function()? callback) {
    _onCountInComplete = callback;
  }

  /// Starts count-in phase followed by recording
  static Future<void> startRecordingWithCountIn() async {
    if (!_initialized || !_enabled) {
      // If metronome is disabled, call count-in complete immediately
      if (_onCountInComplete != null) {
        _onCountInComplete!();
      }
      return;
    }
    
    print('MetronomePlayer: Starting recording with count-in');
    _phase = RecordingPhase.countIn;
    _currentBeat = 0;
    
    // Start metronome for count-in measure
    await _startMetronome();
  }
  
  /// Stops metronome completely
  static Future<void> stopMetronome() async {
    print('MetronomePlayer: Stopping metronome');
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    _phase = RecordingPhase.idle;
    _currentBeat = 0;
    
    try {
      await _strongBeatPlayer.stop();
      await _weakBeatPlayer.stop();
    } catch (e) {
      print('MetronomePlayer: Error stopping players: $e');
    }
  }
  
  /// Internal method to start the metronome timer
  static Future<void> _startMetronome() async {
    _metronomeTimer?.cancel();
    
    final beatDurationMs = (60000 / _bpm).round();
    print('MetronomePlayer: Starting metronome at ${_bpm} BPM (${beatDurationMs}ms per beat)');
    
    // Play first beat immediately
    await _playBeat(isStrongBeat: true);
    _currentBeat = 1;
    _notifyBeat();
    
    _metronomeTimer = Timer.periodic(Duration(milliseconds: beatDurationMs), (timer) {
      _currentBeat++;
      
      // Check if we completed count-in measure
      if (_phase == RecordingPhase.countIn && _currentBeat > _timeSignature.numerator) {
        print('MetronomePlayer: Count-in complete, transitioning to recording');
        _phase = RecordingPhase.recording;
        _currentBeat = 1;
        
        // Notify that count-in is complete (run on main thread)
        if (_onCountInComplete != null) {
          // Use scheduleMicrotask for more reliable UI thread callback
          scheduleMicrotask(() {
            if (_onCountInComplete != null) {
              _onCountInComplete!();
            }
          });
        }
        
        // ALWAYS stop metronome after count-in to avoid memory leaks
        timer.cancel();
        _metronomeTimer = null;
        print('MetronomePlayer: Stopping metronome after count-in');
        return;
      } else {
        // Reset beat counter for new measure (only if NOT in count-in completion)
        if (_currentBeat > _timeSignature.numerator) {
          _currentBeat = 1;
        }
      }
      
      final isStrongBeat = _currentBeat == 1;
      // Play beat asynchronously to avoid blocking timer
      _playBeat(isStrongBeat: isStrongBeat);
      _notifyBeat();
    });
  }
  
  static void _notifyBeat() {
    if (_onBeatCallback != null) {
      // ALWAYS notify beat updates during count-in (no throttling)
      print('MetronomePlayer: Notifying beat $_currentBeat/${_timeSignature.numerator} phase=$_phase');
      
      // Use scheduleMicrotask for more reliable UI thread callback
      scheduleMicrotask(() {
        if (_onBeatCallback != null) {
          _onBeatCallback!(_currentBeat, _timeSignature.numerator, _phase);
        }
      });
    }
  }
  
  /// Plays a single metronome beat using pre-loaded players
  static Future<void> _playBeat({required bool isStrongBeat}) async {
    try {
      print('MetronomePlayer: Beat ${isStrongBeat ? 'STRONG' : 'weak'}');
      
      // Re-enabled audio now that threading is fixed
      final player = isStrongBeat ? _strongBeatPlayer : _weakBeatPlayer;
      await player.seek(Duration.zero);
      await player.play();
      
    } catch (e) {
      print('MetronomePlayer: Error playing beat: $e');
    }
  }
  
  /// Synthesizes a sharp metronome click sound
  static Uint8List _synthesizeClickWav(double frequency, {int durationMs = 100, int sampleRate = 44100}) {
    final frameCount = ((durationMs / 1000) * sampleRate).round();
    final pcm = Int16List(frameCount);
    
    for (int i = 0; i < frameCount; i++) {
      final t = i / sampleRate;
      
      // Sharp, audible click with quick attack and decay
      double signal = 0;
      
      // Primary frequency (clear and strong)
      signal += math.sin(2 * math.pi * frequency * t) * 0.8;
      
      // Add harmonic for sharpness
      signal += math.sin(2 * math.pi * frequency * 2 * t) * 0.3;
      
      // Apply sharp envelope for click character
      final envelope = _clickEnvelope(t, durationMs / 1000.0);
      signal *= envelope;
      
      // Convert to 16-bit PCM
      final sample = (signal * 32767 * 0.7).clamp(-32768.0, 32767.0).round();
      pcm[i] = sample;
    }
    
    return _wrapPcm16ToWav(pcm, sampleRate: sampleRate, numChannels: 1);
  }
  
  /// Sharp envelope for metronome click
  static double _clickEnvelope(double t, double totalDuration) {
    const double attackTime = 0.005;  // Very quick attack (5ms)
    const double decayTime = 0.02;    // Quick decay (20ms) 
    
    if (t < attackTime) {
      // Sharp attack
      return t / attackTime;
    } else if (t < attackTime + decayTime) {
      // Exponential decay
      final decayProgress = (t - attackTime) / decayTime;
      return math.exp(-decayProgress * 8); // Fast exponential decay
    } else {
      // Silence for rest of duration
      return 0.0;
    }
  }
  
  /// Wraps PCM data in WAV format
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
  
  static Future<void> dispose() async {
    try {
      _metronomeTimer?.cancel();
      _metronomeTimer = null;
      await _strongBeatPlayer.stop();
      await _weakBeatPlayer.stop();
      await _strongBeatPlayer.dispose();
      await _weakBeatPlayer.dispose();
      
      // Clean up pre-generated sound files
      try {
        if (_strongBeatPath != null) {
          final strongFile = File(_strongBeatPath!);
          if (await strongFile.exists()) {
            await strongFile.delete();
          }
        }
        if (_weakBeatPath != null) {
          final weakFile = File(_weakBeatPath!);
          if (await weakFile.exists()) {
            await weakFile.delete();
          }
        }
        _strongBeatPath = null;
        _weakBeatPath = null;
      } catch (e) {
        print('MetronomePlayer: Error cleaning up sound files: $e');
      }
      
      _initialized = false;
      _phase = RecordingPhase.idle;
      print('MetronomePlayer: Disposed successfully');
    } catch (e) {
      print('MetronomePlayer: Disposal error: $e');
    }
  }
}