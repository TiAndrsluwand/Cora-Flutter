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

  /// Initialize the audio service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize audio session
      _session = await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration.music());
      
      // Initialize single audio player
      _player = AudioPlayer();
      
      // Listen to player state changes
      _playerStateSubscription = _player!.playerStateStream.listen((state) {
        _notifyStateChange(state.playing);
      });
      
      _isInitialized = true;
      debugPrint('AudioService: Initialized successfully');
    } catch (e) {
      debugPrint('AudioService: Initialization failed: $e');
    }
  }

  /// Play recording audio file
  Future<void> playRecording(String filePath) async {
    await _stopCurrentAndPrepare(AudioType.recording);
    
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await _player!.setFilePath(filePath);
      } else {
        await _player!.setUrl(Uri.file(filePath).toString());
      }
      
      await _player!.setVolume(1.0);
      await _player!.play();
      
      debugPrint('AudioService: Playing recording from $filePath');
    } catch (e) {
      debugPrint('AudioService: Recording playback failed: $e');
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

  /// Set callback for recording playback state changes
  void setRecordingPlaybackCallback(Function(bool isPlaying)? callback) {
    _recordingPlaybackCallback = callback;
  }

  /// Set callback for chord playback state changes
  void setChordPlaybackCallback(Function(bool isPlaying)? callback) {
    _chordPlaybackCallback = callback;
  }

  /// Prepare for recording (stop main audio but allow metronome)
  Future<void> prepareForRecording() async {
    // Only stop non-metronome audio
    await stopAll();
    
    if (_session != null) {
      try {
        await _session!.setActive(false);
        await _session!.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers, // Allow metronome to mix
          avAudioSessionMode: AVAudioSessionMode.defaultMode, // More compatible with multiple players
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.audibilityEnforced,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck, // Allow other audio to duck
          androidWillPauseWhenDucked: false,
        ));
        await _session!.setActive(true);
        debugPrint('AudioService: Configured for recording with mixing support');
      } catch (e) {
        debugPrint('AudioService: Recording config failed: $e');
      }
    }
  }

  /// Restore playback configuration
  Future<void> restorePlaybackConfiguration() async {
    if (_session != null) {
      try {
        await _session!.setActive(false);
        await _session!.configure(const AudioSessionConfiguration.music());
        await _session!.setActive(true);
        debugPrint('AudioService: Restored playback configuration');
      } catch (e) {
        debugPrint('AudioService: Playback config failed: $e');
      }
    }
  }

  /// Private method to stop current audio and prepare for new type
  Future<void> _stopCurrentAndPrepare(AudioType newType) async {
    if (!_isInitialized) await initialize();
    
    // Stop any current playback
    if (_player!.playing) {
      await _player!.stop();
    }
    
    // Restore playback configuration if needed
    await restorePlaybackConfiguration();
    
    // Update current audio type
    _currentAudioType = newType;
  }

  /// Notify state change to appropriate callback
  void _notifyStateChange(bool isPlaying) {
    switch (_currentAudioType) {
      case AudioType.recording:
        _recordingPlaybackCallback?.call(isPlaying);
        break;
      case AudioType.chord:
        _chordPlaybackCallback?.call(isPlaying);
        break;
      case null:
        break;
    }
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
}