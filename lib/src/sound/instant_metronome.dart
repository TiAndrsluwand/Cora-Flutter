import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';

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

/// Ultra-low latency metronome usando síntesis directa de audio
/// Sin archivos, sin just_audio, sin latencia
class InstantMetronome {
  static const MethodChannel _channel = MethodChannel('instant_metronome');
  static bool _initialized = false;
  static Timer? _timer;
  
  // Settings
  static int _bpm = 120;
  static TimeSignature _timeSignature = const TimeSignature(4, 4);
  static bool _enabled = false;
  static double _volume = 0.8;
  
  // State
  static int _currentBeat = 0;
  static RecordingPhase _phase = RecordingPhase.idle;
  static bool _isPlaying = false;
  
  // Callbacks
  static Function(int beat, int totalBeats, RecordingPhase phase)? _onBeat;
  static Function()? _onCountInComplete;

  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Inicializar el metronomo nativo de ultra-baja latencia
      await _channel.invokeMethod('initialize', {
        'strongFreq': 1200.0,
        'weakFreq': 800.0,
        'volume': _volume,
      });
      
      _initialized = true;
      print('InstantMetronome: Initialized with native audio synthesis');
    } catch (e) {
      print('InstantMetronome: Native initialization failed, using fallback: $e');
      _initialized = true; // Use fallback
    }
  }

  // Clean API
  static void setBpm(int bpm) => _bpm = bpm.clamp(60, 200);
  static void setTimeSignature(TimeSignature ts) => _timeSignature = ts;
  static void setEnabled(bool enabled) => _enabled = enabled;
  static void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    if (_initialized) {
      _channel.invokeMethod('setVolume', {'volume': _volume});
    }
  }
  
  static void setBeatCallback(Function(int, int, RecordingPhase)? callback) {
    _onBeat = callback;
  }
  
  static void setCountInCompleteCallback(Function()? callback) {
    _onCountInComplete = callback;
  }

  static Future<void> startRecordingWithCountIn() async {
    if (!_initialized || !_enabled) {
      print('InstantMetronome: Not enabled, skipping count-in');
      _onCountInComplete?.call();
      return;
    }
    
    print('InstantMetronome: Starting count-in phase');
    _phase = RecordingPhase.countIn;
    _currentBeat = 0;
    await _start();
  }

  static Future<void> startContinuous() async {
    if (!_initialized || !_enabled) {
      print('InstantMetronome: Not enabled, cannot start continuous');
      return;
    }
    
    print('InstantMetronome: Starting continuous metronome');
    _phase = RecordingPhase.idle;
    _currentBeat = 0;
    await _start();
  }

  static Future<void> _start() async {
    if (_isPlaying) return;
    _isPlaying = true;
    
    // Reproducir primer beat inmediatamente
    _playBeat(true);
    _currentBeat = 1;
    _notifyBeat();
    
    // Timer de ultra-alta precisión
    final intervalMicros = (60000000 / _bpm).round();
    print('InstantMetronome: Starting with ${intervalMicros}μs interval');
    
    _timer = Timer.periodic(Duration(microseconds: intervalMicros), _onTick);
  }

  static void _onTick(Timer timer) {
    _currentBeat++;
    
    // Reproducir beat INMEDIATAMENTE - sin delays
    _playBeat(_currentBeat == 1);
    _notifyBeat();
    
    // Manejar finalización de count-in
    if (_phase == RecordingPhase.countIn && _currentBeat >= _timeSignature.numerator) {
      print('InstantMetronome: Count-in complete on beat $_currentBeat, transitioning to recording');
      _phase = RecordingPhase.recording;
      _currentBeat = 0; // Reset para que el próximo beat sea 1
      
      // Notificar INMEDIATAMENTE para iniciar grabación sin perder el tempo
      _onCountInComplete?.call();
      return;
    }
    
    // Reset para nueva medida en modo continuo
    if (_currentBeat >= _timeSignature.numerator && _phase != RecordingPhase.countIn) {
      _currentBeat = 0; // Reset para que el próximo beat sea 1
    }
  }

  static void _playBeat(bool isStrong) {
    try {
      if (_initialized) {
        // Usar síntesis nativa ultra-rápida
        _channel.invokeMethod('playBeat', {
          'isStrong': isStrong,
          'frequency': isStrong ? 1200.0 : 800.0,
        });
      } else {
        // Fallback: generar click usando System beep
        _playSystemBeep(isStrong);
      }
    } catch (e) {
      print('InstantMetronome: Beat playback error: $e');
      _playSystemBeep(isStrong);
    }
  }

  static void _playSystemBeep(bool isStrong) {
    // Fallback usando vibración para feedback táctil instantáneo
    HapticFeedback.heavyImpact();
  }

  static void _notifyBeat() {
    _onBeat?.call(_currentBeat, _timeSignature.numerator, _phase);
  }

  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isPlaying = false;
    _phase = RecordingPhase.idle;
    _currentBeat = 0;
    
    if (_initialized) {
      try {
        await _channel.invokeMethod('stop');
      } catch (e) {
        print('InstantMetronome: Stop error: $e');
      }
    }
  }

  static Future<void> dispose() async {
    await stop();
    if (_initialized) {
      try {
        await _channel.invokeMethod('dispose');
      } catch (e) {
        print('InstantMetronome: Dispose error: $e');
      }
    }
    _initialized = false;
  }

  // Getters
  static int get bpm => _bpm;
  static TimeSignature get timeSignature => _timeSignature;
  static bool get enabled => _enabled;
  static RecordingPhase get currentPhase => _phase;
  static int get currentBeat => _currentBeat;
}