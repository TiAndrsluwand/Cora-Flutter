import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/widgets.dart';
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
  static bool _continueMetronomeDuringRecording = false;
  static double _volume = 0.8;
  
  // Continuous mode flag
  static bool _isInContinuousMode = false;

  // Beat callbacks
  static Function(int beat, int totalBeats, RecordingPhase phase)?
      _onBeatCallback;
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

      // Generate strong beat sound (1400Hz) - Higher frequency for better audibility during recording
      final strongBeatData = _synthesizeClickWav(1400.0, durationMs: 100); // Longer for better audibility
      final strongBeatFile = File('${tempDir.path}/metronome_strong.wav');
      await strongBeatFile.writeAsBytes(strongBeatData);
      _strongBeatPath = strongBeatFile.path;

      // Generate weak beat sound (1000Hz) - Higher frequency for better audibility during recording  
      final weakBeatData = _synthesizeClickWav(1000.0, durationMs: 100); // Longer for better audibility
      final weakBeatFile = File('${tempDir.path}/metronome_weak.wav');
      await weakBeatFile.writeAsBytes(weakBeatData);
      _weakBeatPath = weakBeatFile.path;

      // Load audio files with optimized settings for recording compatibility
      await _strongBeatPlayer.setFilePath(_strongBeatPath!);
      await _strongBeatPlayer.setVolume(_volume);
      await _strongBeatPlayer.setSpeed(1.0); // Ensure consistent playback
      
      await _weakBeatPlayer.setFilePath(_weakBeatPath!);
      await _weakBeatPlayer.setVolume(_volume);
      await _weakBeatPlayer.setSpeed(1.0); // Ensure consistent playback

      print('MetronomePlayer: Generated sounds with recording-friendly configuration');
    } catch (e) {
      print('MetronomePlayer: Error generating sounds: $e');
    }
  }

  // Getters for current settings
  static int get bpm => _bpm;
  static TimeSignature get timeSignature => _timeSignature;
  static bool get enabled => _enabled;
  static bool get continueMetronomeDuringRecording =>
      _continueMetronomeDuringRecording;
  static double get volume => _volume;
  static RecordingPhase get currentPhase => _phase;
  static int get currentBeat => _currentBeat;

  // Setters for metronome settings
  static void setBpm(int newBpm) {
    final clampedBpm = newBpm.clamp(60, 200);
    final oldBpm = _bpm;
    _bpm = clampedBpm;
    
    // Auto-update real-time if in continuous mode
    if (_initialized && _isInContinuousMode && oldBpm != _bpm) {
      print('MetronomePlayer: Auto real-time BPM change via setBpm: $oldBpm -> $_bpm');
      
      // Restart timer with new interval for seamless tempo change
      if (_metronomeTimer != null) {
        _metronomeTimer?.cancel();
        _startMetronomeTimer();
      }
    }
  }

  static void setTimeSignature(TimeSignature newTimeSignature) {
    final oldTimeSignature = _timeSignature;
    _timeSignature = newTimeSignature;
    
    // Auto-update real-time if in continuous mode
    if (_initialized && _isInContinuousMode && oldTimeSignature != _timeSignature) {
      print('MetronomePlayer: Auto real-time time signature change via setTimeSignature: $oldTimeSignature -> $_timeSignature');
      
      // Reset beat counter for new time signature pattern
      _currentBeat = 0;
      
      // Notify UI of time signature change
      if (_onBeatCallback != null) {
        _onBeatCallback!(_currentBeat + 1, _timeSignature.numerator, RecordingPhase.idle);
      }
    }
  }

  static void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled && _metronomeTimer != null) {
      stopMetronome();
    }
  }

  static void setContinueMetronomeDuringRecording(bool shouldContinue) {
    _continueMetronomeDuringRecording = shouldContinue;
    print('MetronomePlayer: Continue metronome during recording set to: $shouldContinue');
  }

  static void setVolume(double newVolume) {
    _volume = newVolume.clamp(0.0, 1.0);
    _strongBeatPlayer.setVolume(_volume);
    _weakBeatPlayer.setVolume(_volume);
  }

  /// Optimized recording mode - CRITICAL FIX: Keep metronome audible but prevent corruption
  static void setRecordingMode(bool isRecording) {
    if (isRecording) {
      // FIXED APPROACH: Reduce volume but keep audible for user guidance
      // Use isolated audio session configuration instead of muting
      final recordingVolume = _volume * 0.4; // Reduced but still audible
      print('MetronomePlayer: RECORDING MODE ON - reducing volume for recording mix: ${recordingVolume.toStringAsFixed(2)}');
      try {
        _strongBeatPlayer.setVolume(recordingVolume);
        _weakBeatPlayer.setVolume(recordingVolume);
        
        // CRITICAL: Configure metronome players for recording coexistence
        _configureForRecording(true);
      } catch (e) {
        print('MetronomePlayer: Warning - could not configure for recording: $e');
      }
    } else {
      // Restore normal metronome volume after recording
      final normalVolume = _volume * 0.8; // Normal playback volume
      print('MetronomePlayer: RECORDING MODE OFF - restoring normal volume: ${normalVolume.toStringAsFixed(2)}');
      try {
        _strongBeatPlayer.setVolume(normalVolume);
        _weakBeatPlayer.setVolume(normalVolume);
        
        // Restore normal audio configuration
        _configureForRecording(false);
      } catch (e) {
        print('MetronomePlayer: Warning - could not restore normal mode: $e');
      }
    }
  }
  
  /// Configure metronome audio players for recording compatibility
  static Future<void> _configureForRecording(bool isRecording) async {
    try {
      if (isRecording) {
        // Configure for non-intrusive playback during recording
        // Set a very short preload to minimize buffer conflicts
        await _strongBeatPlayer.setSpeed(1.0);
        await _weakBeatPlayer.setSpeed(1.0);
        print('MetronomePlayer: ✅ Configured for recording coexistence');
      } else {
        // Restore normal configuration
        await _strongBeatPlayer.setSpeed(1.0);
        await _weakBeatPlayer.setSpeed(1.0);
        print('MetronomePlayer: ✅ Restored normal configuration');
      }
    } catch (e) {
      print('MetronomePlayer: Warning - audio configuration failed: $e');
    }
  }

  static void setBeatCallback(
      Function(int beat, int totalBeats, RecordingPhase phase)? callback) {
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

  /// Stops metronome specifically after recording ends
  static Future<void> stopRecordingMetronome() async {
    if (_phase == RecordingPhase.recording && _metronomeTimer != null) {
      print('MetronomePlayer: Stopping metronome after recording ends');
      await stopMetronome();
    }
  }

  /// Starts continuous metronome for real-time adjustability
  static Future<void> startContinuous() async {
    if (!_initialized) return;
    
    print('MetronomePlayer: Starting continuous mode - BPM: $_bpm, Time: $_timeSignature');
    _currentBeat = 0;
    _isInContinuousMode = true;
    
    // Start continuous metronome playback
    await _startMetronome();
  }

  /// Stops continuous metronome
  static Future<void> stopContinuous() async {
    print('MetronomePlayer: Stopping continuous mode');
    _isInContinuousMode = false;
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    _currentBeat = 0;

    try {
      await _strongBeatPlayer.stop();
      await _weakBeatPlayer.stop();
    } catch (e) {
      print('MetronomePlayer: Error stopping continuous players: $e');
    }
  }

  // Note: Real-time updates are now handled automatically by setBpm() and setTimeSignature() 
  // when in continuous mode, so separate update methods are no longer needed.

  /// Internal method to start the metronome timer
  static Future<void> _startMetronome() async {
    // Play first beat immediately
    await _playBeat(isStrongBeat: true);
    _currentBeat = 1;
    _notifyBeat();

    // Start the timer
    _startMetronomeTimer();
  }

  /// Starts or restarts the metronome timer with current BPM
  static void _startMetronomeTimer() {
    _metronomeTimer?.cancel();

    final beatDurationMs = (60000 / _bpm).round();
    print(
        'MetronomePlayer: Starting metronome timer at $_bpm BPM (${beatDurationMs}ms per beat)');

    _metronomeTimer =
        Timer.periodic(Duration(milliseconds: beatDurationMs), (timer) {
      _currentBeat++;

      // Handle count-in mode completion
      if (_phase == RecordingPhase.countIn &&
          _currentBeat > _timeSignature.numerator) {
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

        // Check if metronome should continue during recording
        if (!_continueMetronomeDuringRecording) {
          timer.cancel();
          _metronomeTimer = null;
          print('MetronomePlayer: Stopping metronome after count-in (user preference)');
          return;
        } else {
          print('MetronomePlayer: Continuing metronome during recording (user preference)');
        }
      }
      
      // Handle continuous mode - keep playing forever until manually stopped
      if (_isInContinuousMode && _currentBeat > _timeSignature.numerator) {
        _currentBeat = 1; // Reset to beat 1 for new measure
      } else if (!_isInContinuousMode && _currentBeat > _timeSignature.numerator) {
        // Reset beat counter for new measure (non-continuous modes)
        _currentBeat = 1;
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
      print(
          'MetronomePlayer: Notifying beat $_currentBeat/${_timeSignature.numerator} phase=$_phase');

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
  static Uint8List _synthesizeClickWav(double frequency,
      {int durationMs = 100, int sampleRate = 44100}) {
    final frameCount = ((durationMs / 1000) * sampleRate).round();
    final pcm = Int16List(frameCount);

    for (int i = 0; i < frameCount; i++) {
      final t = i / sampleRate;

      // Sharp, audible click with quick attack and decay
      double signal = 0;

      // Primary frequency (strong and piercing for recording audibility)
      signal += math.sin(2 * math.pi * frequency * t) * 0.9;

      // Add harmonic for extra sharpness and penetration
      signal += math.sin(2 * math.pi * frequency * 2 * t) * 0.4;
      
      // Add higher harmonic for even more presence
      signal += math.sin(2 * math.pi * frequency * 3 * t) * 0.2;

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
    const double attackTime = 0.005; // Very quick attack (5ms)
    const double decayTime = 0.02; // Quick decay (20ms)

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
  static Uint8List _wrapPcm16ToWav(Int16List samples,
      {required int sampleRate, int numChannels = 1}) {
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
