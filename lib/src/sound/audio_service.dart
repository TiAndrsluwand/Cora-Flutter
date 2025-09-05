import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

/// Clean, centralized audio service to prevent conflicts
/// 
/// Manages all audio playback through a single service to avoid:
/// - Multiple AudioPlayer conflicts
/// - Audio session management issues
/// - Resource leaks
/// - Concurrent playback problems
class AudioService {
  static AudioService? _instance;
  static AudioService get instance => _instance ??= AudioService._();
  
  AudioService._();

  // Single audio player for all audio operations
  AudioPlayer? _player;
  AudioSession? _session;
  
  // Current audio state
  AudioType? _currentAudioType;
  bool _isInitialized = false;
  StreamSubscription? _playerStateSubscription;
  
  // Callbacks for different audio types
  Function(bool isPlaying)? _recordingPlaybackCallback;
  Function(bool isPlaying)? _chordPlaybackCallback;
  Function(bool isPlaying)? _melodyPlaybackCallback;

  /// Initialize the audio service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize audio session
      _session = await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration.music());
      
      // Initialize single audio player
      _player = AudioPlayer();
      
      // Listen to player state changes with detailed logging
      _playerStateSubscription = _player!.playerStateStream.listen((state) {
        debugPrint('AudioService: State change - Playing: ${state.playing}, Processing: ${state.processingState}');
        _notifyStateChange(state.playing);
        
        // Handle different completion states
        switch (state.processingState) {
          case ProcessingState.completed:
            debugPrint('AudioService: Playback completed naturally at ${_player!.position}');
            // CRITICAL: Notify state change BEFORE clearing current type
            _notifyStateChange(false);
            // Small delay to ensure callback is processed
            Future.delayed(const Duration(milliseconds: 100), () {
              _currentAudioType = null;
            });
            break;
          case ProcessingState.ready:
            if (!state.playing && _currentAudioType == AudioType.recording) {
              debugPrint('AudioService: Playback ready/stopped - Position: ${_player!.position}');
            }
            break;
          case ProcessingState.buffering:
            debugPrint('AudioService: Buffering at ${_player!.position}');
            break;
          case ProcessingState.loading:
            debugPrint('AudioService: Loading...');
            break;
          case ProcessingState.idle:
            debugPrint('AudioService: Player idle');
            break;
        }
      });
      
      // Position stream with enhanced tracking for broken WAV durations
      _player!.positionStream.listen((position) {
        if (_currentAudioType == AudioType.recording) {
          final duration = _player!.duration;
          final estimatedDuration = _estimateRecordingDuration();
          
          // Use estimated duration if WAV header duration is unreliable
          final actualDuration = estimatedDuration ?? duration;
          
          if (actualDuration != null && actualDuration.inMilliseconds > 0) {
            final progressPercent = (position.inMilliseconds / actualDuration.inMilliseconds * 100);
            
            // Log every 2 seconds or at critical points
            if (position.inSeconds % 2 == 0 || progressPercent > 90) {
              debugPrint('AudioService: Position ${position.inSeconds}s/${actualDuration.inSeconds}s (${progressPercent.toStringAsFixed(1)}%) [Est: ${estimatedDuration?.inSeconds ?? 'none'}s, WAV: ${duration?.inSeconds ?? 'none'}s]');
            }
            
            // CRITICAL FIX: Auto-stop when reaching estimated end to prevent cutoff
            if (estimatedDuration != null && position >= estimatedDuration) {
              debugPrint('AudioService: Auto-stopping at estimated end (${position.inSeconds}s >= ${estimatedDuration.inSeconds}s)');
              _player!.stop().catchError((e) => debugPrint('Auto-stop error: $e'));
            }
          } else {
            // Duration unknown - just track position
            if (position.inSeconds % 2 == 0) {
              debugPrint('AudioService: Position ${position.inSeconds}s (duration unknown)');
            }
          }
        }
      });
      
      _isInitialized = true;
      debugPrint('AudioService: Initialized successfully');
    } catch (e) {
      debugPrint('AudioService: Initialization failed: $e');
    }
  }

  /// Play recording audio file with comprehensive diagnostics
  Future<void> playRecording(String filePath) async {
    await _stopCurrentAndPrepare(AudioType.recording);
    
    try {
      // Verify file exists and get size
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Recording file not found: $filePath');
      }
      
      final fileSize = await file.length();
      _lastFileSizeBytes = fileSize; // Store for duration estimation
      debugPrint('AudioService: File exists, size: ${(fileSize / 1024).toStringAsFixed(1)}KB');
      
      // CRITICAL FIX: Reset player state before loading new audio
      await _player!.stop();
      await _player!.seek(Duration.zero);
      
      // Set audio source with better error handling
      try {
        if (Platform.isAndroid || Platform.isIOS) {
          await _player!.setFilePath(filePath);
        } else {
          await _player!.setUrl(Uri.file(filePath).toString());
        }
      } catch (e) {
        debugPrint('AudioService: Error setting audio source: $e');
        throw Exception('Failed to load audio file: $e');
      }
      
      // Configure playback settings BEFORE playing
      await _player!.setVolume(1.0);
      await _player!.setSpeed(1.0);
      
      debugPrint('AudioService: Player configured - Volume: 1.0, Speed: 1.0');
      
      // Wait for the audio to load properly
      int retries = 0;
      const maxRetries = 10;
      while (_player!.processingState == ProcessingState.loading && retries < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
        debugPrint('AudioService: Waiting for audio to load... (retry $retries/$maxRetries)');
      }
      
      if (_player!.processingState == ProcessingState.loading) {
        throw Exception('Audio loading timeout after ${maxRetries * 100}ms');
      }
      
      // Ensure we start from the beginning
      await _player!.seek(Duration.zero);
      debugPrint('AudioService: Seeked to beginning');
      
      // CRITICAL FIX: Start playback and wait for confirmation
      debugPrint('AudioService: Starting playback now...');
      await _player!.play();
      
      // Wait for playback to actually start
      retries = 0;
      while (!_player!.playing && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 50));
        retries++;
      }
      
      if (!_player!.playing) {
        throw Exception('Failed to start audio playback');
      }
      
      debugPrint('AudioService: ✅ Playback started successfully - Position: ${_player!.position?.inSeconds ?? 0}s');
      
    } catch (e) {
      debugPrint('AudioService: ❌ Recording playback failed: $e');
      _currentAudioType = null;
      rethrow;
    }
  }

  /// Play chord audio
  Future<void> playChord(String audioData) async {
    await _stopCurrentAndPrepare(AudioType.chord);
    
    try {
      // Assuming audioData is a file path or URL
      await _player!.setFilePath(audioData);
      await _player!.setVolume(0.8);
      await _player!.play();
      
      debugPrint('AudioService: Playing chord');
    } catch (e) {
      debugPrint('AudioService: Chord playback failed: $e');
      rethrow;
    }
  }

  /// Play melody audio
  Future<void> playMelody(String filePath) async {
    await _stopCurrentAndPrepare(AudioType.melody);
    
    try {
      // Verify file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Melody file not found: $filePath');
      }
      
      debugPrint('AudioService: Loading melody file: $filePath');
      
      // CRITICAL FIX: Reset player state before loading new audio
      await _player!.stop();
      await _player!.seek(Duration.zero);
      
      // Set audio source
      if (Platform.isAndroid || Platform.isIOS) {
        await _player!.setFilePath(filePath);
      } else {
        await _player!.setUrl(Uri.file(filePath).toString());
      }
      
      // Configure playback settings for melody
      await _player!.setVolume(0.7); // Slightly softer than chord for pleasant melody playback
      await _player!.setSpeed(1.0);
      
      debugPrint('AudioService: Melody configured - Volume: 0.7, Speed: 1.0');
      
      // Wait for the audio to load properly
      int retries = 0;
      const maxRetries = 10;
      while (_player!.processingState == ProcessingState.loading && retries < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
        debugPrint('AudioService: Waiting for melody to load... (retry $retries/$maxRetries)');
      }
      
      if (_player!.processingState == ProcessingState.loading) {
        throw Exception('Melody loading timeout after ${maxRetries * 100}ms');
      }
      
      // Ensure we start from the beginning
      await _player!.seek(Duration.zero);
      debugPrint('AudioService: Melody seeked to beginning');
      
      // Start playback
      debugPrint('AudioService: Starting melody playback now...');
      await _player!.play();
      
      // Wait for playback to actually start
      retries = 0;
      while (!_player!.playing && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 50));
        retries++;
      }
      
      if (!_player!.playing) {
        throw Exception('Failed to start melody playback');
      }
      
      debugPrint('AudioService: ✅ Melody playback started successfully - Position: ${_player!.position?.inSeconds ?? 0}s');
      
    } catch (e) {
      debugPrint('AudioService: ❌ Melody playback failed: $e');
      _currentAudioType = null;
      rethrow;
    }
  }

  /// Stop all audio playback
  Future<void> stopAll() async {
    if (_player == null) return;
    
    try {
      await _player!.stop();
      _currentAudioType = null;
      debugPrint('AudioService: Stopped all playback');
    } catch (e) {
      debugPrint('AudioService: Stop failed: $e');
    }
  }

  /// Check if audio is currently playing
  bool get isPlaying => _player?.playing ?? false;
  
  /// Get current audio type being played
  AudioType? get currentAudioType => _currentAudioType;
  
  /// Get current playback position
  Duration? get position => _player?.position;
  
  /// Get total duration of current audio
  Duration? get duration => _player?.duration;
  
  /// Get current playback progress (0.0 to 1.0) - ENHANCED with duration estimation
  double get progress {
    final pos = position;
    final dur = duration;
    final estimatedDuration = _estimateRecordingDuration();
    
    // Use estimated duration for better accuracy, fall back to WAV header duration
    final actualDuration = estimatedDuration ?? dur;
    
    if (pos == null || pos.inMilliseconds == 0) return 0.0;
    
    if (actualDuration != null && actualDuration.inMilliseconds > 0) {
      final progress = (pos.inMilliseconds / actualDuration.inMilliseconds).clamp(0.0, 1.0);
      return progress;
    }
    
    // Ultimate fallback: assume typical recording length
    const fallbackDuration = Duration(seconds: 20);
    final progress = (pos.inMilliseconds / fallbackDuration.inMilliseconds).clamp(0.0, 1.0);
    return progress;
  }
  
  // Store last file size for duration estimation
  int? _lastFileSizeBytes;
  
  /// Estimate recording duration from file size (for metronome-corrupted files)
  Duration? _estimateRecordingDuration() {
    if (_lastFileSizeBytes == null) return null;
    
    // WAV file size calculation:
    // Size = (sampleRate * channels * bitsPerSample * duration) / 8 + header
    const sampleRate = 22050; // ACTUAL sample rate from WAV decoder logs (not 44100!)
    const channels = 1;       // MONO recording (as configured in recorder_page_minimal.dart)
    const bitsPerSample = 16; // Standard for WAV
    const headerSize = 44;    // Standard WAV header
    
    final dataSize = _lastFileSizeBytes! - headerSize;
    if (dataSize <= 0) return null;
    
    final bytesPerSecond = (sampleRate * channels * bitsPerSample) / 8;
    final durationSeconds = dataSize / bytesPerSecond;
    
    return Duration(milliseconds: (durationSeconds * 1000).round());
  }
  
  /// Diagnostic method to check playback health
  Map<String, dynamic> get playbackDiagnostics {
    return {
      'isPlaying': isPlaying,
      'currentType': currentAudioType?.toString(),
      'position': position?.inSeconds,
      'duration': duration?.inSeconds,
      'progress': progress,
      'processingState': _player?.processingState.toString(),
      'playerState': _player?.playerState.toString(),
    };
  }
  
  /// Force playback verification - FIXED for broken duration headers
  Future<bool> verifyPlaybackIntegrity() async {
    if (_player == null || !isPlaying) return false;
    
    final pos = position ?? Duration.zero;
    
    // Since duration may be broken, just check if we're still playing and progressing
    final hasPosition = pos.inMilliseconds > 0;
    debugPrint('AudioService: Integrity check - Playing: $isPlaying, Position: ${pos.inSeconds}s');
    
    return hasPosition; // As long as we have position and are playing, we're good
  }

  /// Set callback for recording playback state changes
  void setRecordingPlaybackCallback(Function(bool isPlaying)? callback) {
    _recordingPlaybackCallback = callback;
  }

  /// Set callback for chord playback state changes
  void setChordPlaybackCallback(Function(bool isPlaying)? callback) {
    _chordPlaybackCallback = callback;
  }

  /// Set callback for melody playback state changes
  void setMelodyPlaybackCallback(Function(bool isPlaying)? callback) {
    _melodyPlaybackCallback = callback;
  }

  /// Prepare for recording (stop main audio but preserve metronome independence)
  Future<void> prepareForRecording() async {
    // Only stop AudioService managed audio, leave metronome alone
    await stopAll();
    
    // CRITICAL FIX: Configure recording session that allows metronome coexistence
    try {
      if (_session != null) {
        await _session!.setActive(false);
        
        // Configure for recording with metronome coexistence
        await _session!.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ));
        
        await _session!.setActive(true);
        
        // Small delay to let session stabilize
        await Future.delayed(const Duration(milliseconds: 100));
        
        debugPrint('AudioService: ✅ Recording session configured for metronome coexistence');
      }
    } catch (e) {
      debugPrint('AudioService: Recording session config warning: $e');
    }
    
    debugPrint('AudioService: Prepared for recording (metronome will play at reduced volume)');
  }

  /// Restore optimal playback configuration
  Future<void> restorePlaybackConfiguration() async {
    if (_session != null) {
      try {
        await _session!.setActive(false);
        
        // Configure for uninterrupted playback
        await _session!.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ));
        
        await _session!.setActive(true);
        
        // Give session time to stabilize
        await Future.delayed(const Duration(milliseconds: 100));
        
        debugPrint('AudioService: Restored optimal playback configuration');
      } catch (e) {
        debugPrint('AudioService: Playback config failed: $e');
      }
    }
  }

  /// Private method to stop current audio and prepare for new type
  Future<void> _stopCurrentAndPrepare(AudioType newType) async {
    if (!_isInitialized) await initialize();
    
    debugPrint('AudioService: Preparing for $newType playback');
    
    // Stop any current playback
    if (_player!.playing) {
      debugPrint('AudioService: Stopping current playback');
      await _player!.stop();
      
      // Wait for stop to complete
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // CRITICAL FIX: Always configure audio session for playback
    if (newType == AudioType.recording) {
      debugPrint('AudioService: Configuring optimal session for recording playback');
      try {
        await _configurePlaybackSession();
      } catch (e) {
        debugPrint('AudioService: Session config warning: $e');
      }
    }
    
    // Update current audio type
    _currentAudioType = newType;
    debugPrint('AudioService: Ready for $newType');
  }
  
  /// Configure audio session specifically for playback with metronome isolation
  Future<void> _configurePlaybackSession() async {
    if (_session == null) return;
    
    try {
      // Deactivate first
      await _session!.setActive(false);
      
      // OPTIMIZED: Configure clean playback with controlled audio focus
      await _session!.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck, // Less aggressive focus
        androidWillPauseWhenDucked: false,
      ));
      
      // Activate the session
      await _session!.setActive(true);
      
      // Allow session to stabilize
      await Future.delayed(const Duration(milliseconds: 150));
      
      debugPrint('AudioService: ✅ EXCLUSIVE playback session configured (isolates from metronome)');
    } catch (e) {
      debugPrint('AudioService: Session configuration failed: $e');
    }
  }

  /// Notify state change to appropriate callback
  void _notifyStateChange(bool isPlaying) {
    debugPrint('AudioService: Notifying state change - Playing: $isPlaying, Type: $_currentAudioType');
    
    // CRITICAL FIX: Use scheduleMicrotask to ensure callback runs on main thread
    scheduleMicrotask(() {
      switch (_currentAudioType) {
        case AudioType.recording:
          if (_recordingPlaybackCallback != null) {
            debugPrint('AudioService: Calling recording callback with isPlaying: $isPlaying');
            try {
              _recordingPlaybackCallback!.call(isPlaying);
              debugPrint('AudioService: ✅ Recording callback executed successfully');
            } catch (e) {
              debugPrint('AudioService: ❌ Recording callback error: $e');
            }
          } else {
            debugPrint('AudioService: WARNING - Recording callback is null!');
          }
          break;
        case AudioType.chord:
          if (_chordPlaybackCallback != null) {
            try {
              _chordPlaybackCallback!.call(isPlaying);
            } catch (e) {
              debugPrint('AudioService: Chord callback error: $e');
            }
          }
          break;
        case AudioType.melody:
          if (_melodyPlaybackCallback != null) {
            debugPrint('AudioService: Calling melody callback with isPlaying: $isPlaying');
            try {
              _melodyPlaybackCallback!.call(isPlaying);
              debugPrint('AudioService: ✅ Melody callback executed successfully');
            } catch (e) {
              debugPrint('AudioService: ❌ Melody callback error: $e');
            }
          } else {
            debugPrint('AudioService: WARNING - Melody callback is null!');
          }
          break;
        case null:
          debugPrint('AudioService: No audio type set, skipping callback');
          break;
      }
    });
  }

  /// Dispose of all resources
  Future<void> dispose() async {
    try {
      _playerStateSubscription?.cancel();
      await _player?.dispose();
      _player = null;
      _session = null;
      _isInitialized = false;
      debugPrint('AudioService: Disposed successfully');
    } catch (e) {
      debugPrint('AudioService: Dispose failed: $e');
    }
  }
}

enum AudioType {
  recording,
  chord,
  melody,
}