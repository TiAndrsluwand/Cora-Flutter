import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../sound/chord_player.dart';
import '../sound/melody_player.dart';
import '../analysis/analysis_service.dart';
import '../audio/wav_decoder.dart';
import '../analysis/chord_progression_suggestion.dart';
import '../analysis/detected_chord.dart';
import '../analysis/simple_sheet_music_service.dart';
import '../audio/pitch_to_notes.dart';
import '../audio/pitch_detector.dart';
import '../widgets/minimal_piano_keyboard.dart';
import '../widgets/minimal_recording_interface.dart';
import '../widgets/minimal_metronome_controls.dart';
import '../widgets/minimal_analyzing_animation.dart';
import '../widgets/simple_sheet_music_display.dart';
import '../sound/metronome_player.dart';
import '../theme/minimal_design_system.dart';
import '../utils/debug_logger.dart';
import '../sound/audio_service.dart';

class RecorderPage extends StatefulWidget {
  final VoidCallback onThemeToggle;
  
  const RecorderPage({super.key, required this.onThemeToggle});
  
  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> with TickerProviderStateMixin {
  final AudioRecorder _record = AudioRecorder();
  Timer? _timer;
  int _seconds = 0;
  String? _path;
  bool _isRecording = false;
  static const int _maxSeconds = 20;

  bool _isAnalyzing = false;
  bool _analysisCompleted = false;
  String? _detectedKey;
  List<ChordProgressionSuggestion> _suggestions = const [];
  List<DiscreteNote> _extractedMelody = const [];
  SheetMusicData? _sheetMusicData;

  // Recording diagnostics
  double? _lastRmsDb;
  Duration? _recordingDuration;
  
  // Piano keyboard state
  DetectedChord? _selectedChord;
  
  // Metronome state
  bool _useMetronome = false;
  bool _continueMetronomeDuringRecording = true;
  RecordingPhase _recordingPhase = RecordingPhase.idle;
  int _currentBeat = 0;
  int _totalBeats = 4;
  bool _waitingForCountIn = false;
  
  // Continuous metronome state
  bool _isPreviewingMetronome = false;
  
  // Animation controllers for analyze button
  late AnimationController _analyzeButtonController;
  late Animation<double> _analyzeButtonAnimation;
  
  // Audio playback state
  bool _isPlayingRecording = false;
  double _playbackProgress = 0.0;
  Timer? _progressTimer;
  
  // Melody playback state
  bool _isPlayingMelody = false;
  double _melodyProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initAudioSession();
    _loadSf();
    _initMetronome();
    _initAudioPlayer();
    _initAnimations();
  }
  
  void _initAnimations() {
    _analyzeButtonController = AnimationController(
      duration: const Duration(milliseconds: 600), // Faster, smoother animation
      vsync: this,
    );
    _analyzeButtonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _analyzeButtonController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _loadSf() async {
    await ChordPlayer.ensureLoaded(context);
  }
  
  Future<void> _initAudioPlayer() async {
    // Initialize centralized audio service
    await AudioService.instance.initialize();
    
    // Set callback for recording playback state changes
    AudioService.instance.setRecordingPlaybackCallback((isPlaying) {
      DebugLogger.debug('UI: Received playback state callback - isPlaying: $isPlaying');
      if (mounted) {
        setState(() {
          DebugLogger.debug('UI: Updating UI state - _isPlayingRecording: $_isPlayingRecording -> $isPlaying');
          _isPlayingRecording = isPlaying;
          if (!isPlaying) {
            _playbackProgress = 0.0;
            _progressTimer?.cancel();
            _progressTimer = null;
            DebugLogger.debug('UI: Playback stopped - reset progress and timer');
          } else {
            _startProgressTracking();
            DebugLogger.debug('UI: Playback started - starting progress tracking');
          }
        });
      } else {
        DebugLogger.debug('UI: WARNING - Widget not mounted, ignoring callback');
      }
    });
    
    // Set callback for melody playback state changes
    AudioService.instance.setMelodyPlaybackCallback((isPlaying) {
      DebugLogger.debug('UI: Received melody playback state callback - isPlaying: $isPlaying');
      if (mounted) {
        setState(() {
          DebugLogger.debug('UI: Updating melody state - _isPlayingMelody: $_isPlayingMelody -> $isPlaying');
          _isPlayingMelody = isPlaying;
          if (!isPlaying) {
            _melodyProgress = 0.0;
            DebugLogger.debug('UI: Melody playback stopped - reset progress');
          }
        });
      } else {
        DebugLogger.debug('UI: WARNING - Widget not mounted, ignoring melody callback');
      }
    });
  }
  
  Future<void> _initMetronome() async {
    await MetronomePlayer.ensureLoaded(context);
    
    MetronomePlayer.setBeatCallback((beat, totalBeats, phase) {
      if (!mounted) return;
      
      if (_currentBeat != beat || _totalBeats != totalBeats || _recordingPhase != phase) {
        setState(() {
          _currentBeat = beat;
          _totalBeats = totalBeats;
          _recordingPhase = phase;
        });
      }
    });
    
    MetronomePlayer.setCountInCompleteCallback(() {
      if (!mounted) return;
      if (mounted && _waitingForCountIn) {
        _startActualRecording();
      }
    });
    
    setState(() {
      _useMetronome = MetronomePlayer.enabled;
      _totalBeats = MetronomePlayer.timeSignature.numerator;
    });
  }

  Future<void> _start() async {
    try {
      _clearAnalysisState();

      final mic = await Permission.microphone.request();
      if (mic != PermissionStatus.granted) {
        _showErrorSnackBar('Microphone permission is required to record');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      _path = '${tempDir.path}/temp.wav'; // WAV con configuración optimizada

      _seconds = 0;
      
      if (_useMetronome) {
        setState(() {
          _waitingForCountIn = true;
          _recordingPhase = RecordingPhase.countIn;
        });
        
        // CRITICAL: Ensure metronome continues during recording
        MetronomePlayer.setContinueMetronomeDuringRecording(_continueMetronomeDuringRecording);
        
        await MetronomePlayer.startRecordingWithCountIn();
      } else {
        await _startActualRecording();
      }
    } catch (e) {
      setState(() {
        _waitingForCountIn = false;
        _recordingPhase = RecordingPhase.idle;
      });
      _showErrorSnackBar('Failed to start recording: $e');
    }
  }

  Future<void> _startActualRecording() async {
    try {
      if (_path == null) {
        throw Exception('Recording path is null');
      }

      setState(() {
        _isRecording = true;
        _waitingForCountIn = false;
        _recordingPhase = RecordingPhase.recording;
        _seconds = 0;
      });

      // CRITICAL: Configure audio session for concurrent metronome + recording
      await _configureRecordingAudioSession();
      
      // CRITICAL: Enable recording mode to reduce metronome volume
      MetronomePlayer.setRecordingMode(true);

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _seconds++);
        if (_seconds >= _maxSeconds) {
          _stop();
        }
      });

      // Start recording inmediatamente - WAV optimizado para coexistir con metrónomo
      await _record.start(const RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 64000,  // Bitrate más bajo para reducir conflictos
        sampleRate: 22050, // Sample rate más bajo para reducir carga de sistema
        numChannels: 1,
      ), path: _path!);
      
      print('Recording started: $_path');
    } catch (e) {
      // UNIFIED: Stop metronome completely on error using single method
      await MetronomePlayer.stopRecordingMetronome();
      MetronomePlayer.setRecordingMode(false);
      setState(() {
        _isRecording = false;
        _waitingForCountIn = false;
        _recordingPhase = RecordingPhase.idle;
      });
      rethrow;
    }
  }
  
  Future<void> _stop() async {
    String? filePath;
    if (_isRecording) {
      filePath = await _record.stop();
      
      // Grabación terminada - archivo WAV optimizado
    }
    
    _timer?.cancel();
    
    setState(() {
      _isRecording = false;
      _waitingForCountIn = false;
      _recordingPhase = RecordingPhase.idle;
      _currentBeat = 0;
      _path = filePath ?? _path;
      _seconds = 0;
    });
    
    // UNIFIED: Stop metronome and disable recording mode using single method
    await MetronomePlayer.stopRecordingMetronome();
    MetronomePlayer.setRecordingMode(false);
    
    await AudioService.instance.restorePlaybackConfiguration();
    
    if (_path != null) {
      try {
        final bytes = await File(_path!).readAsBytes();
        final wav = WavDecoder.decode(bytes);
        if (wav != null && wav.samples.isNotEmpty) {
          double sum = 0;
          for (final s in wav.samples) { sum += s * s; }
          final rms = (sum / wav.samples.length).clamp(1e-12, 1.0);
          final db = 10 * (math.log(rms) / math.ln10);
          if (mounted) setState(() => _lastRmsDb = db);
        }
      } catch (e) {
        DebugLogger.debug('Error computing RMS: $e');
      }
    }
  }


  void _clearAnalysisState() {
    setState(() {
      _detectedKey = null;
      _suggestions = const [];
      _selectedChord = null;
      _isAnalyzing = false;
      _analysisCompleted = false;
      _playbackProgress = 0.0;
      _progressTimer?.cancel();
      _progressTimer = null;
      _extractedMelody = const [];
      _sheetMusicData = null;
    });
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      DebugLogger.debug('Audio session initialized');
    } catch (e) {
      DebugLogger.debug('Audio session init error: $e');
    }
  }


  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _analyzeRecording() async {
    if (_path == null || _isAnalyzing) return;

    DebugLogger.debug('Starting analysis for path: $_path');

    // Stop any audio playback before analysis
    try {
      await AudioService.instance.stopAll();
      if (_isPreviewingMetronome) {
        await _stopContinuousMetronome();
      }
    } catch (e) {
      DebugLogger.debug('Warning: Error stopping audio before analysis: $e');
    }

    // Set analyzing state and start button animation
    if (mounted) {
      setState(() => _isAnalyzing = true);
      _analyzeButtonController.repeat();
      DebugLogger.debug('Analysis state set to true, button animation started');
    }

    try {
      // Ensure minimum animation visibility (4.5 seconds for user enjoyment)
      final analysisStartTime = DateTime.now();
      
      // Run analysis in background isolate to prevent blocking animations
      final result = await compute(_analyzeRecordingIsolate, _path!);
      
      final analysisEndTime = DateTime.now();
      final analysisDuration = analysisEndTime.difference(analysisStartTime);
      
      DebugLogger.debug('Analysis completed in ${analysisDuration.inMilliseconds}ms');
      
      // Ensure minimum 4500ms for animation visibility and user enjoyment
      const minDuration = Duration(milliseconds: 4500);
      if (analysisDuration < minDuration) {
        final remainingTime = minDuration - analysisDuration;
        DebugLogger.debug('Adding ${remainingTime.inMilliseconds}ms delay for animation enjoyment');
        await Future.delayed(remainingTime);
      }
      
      if (mounted) {
        _analyzeButtonController.stop();
        _analyzeButtonController.reset();
        
        // Extract melody for sheet music generation (also in background)
        await _extractMelodyFromRecordingIsolate();
        
        setState(() {
          _detectedKey = result.detectedKey;
          _suggestions = result.suggestions;
          _isAnalyzing = false;
          _analysisCompleted = true;
        });
        DebugLogger.debug('Analysis completed: Key=${result.detectedKey}, Suggestions=${result.suggestions.length}');
      }
    } catch (e) {
      DebugLogger.debug('Analysis failed with error: $e');
      
      // Ensure minimum animation time even on error (4.5 seconds for consistency)
      await Future.delayed(const Duration(milliseconds: 4500));
      
      if (mounted) {
        _analyzeButtonController.stop();
        _analyzeButtonController.reset();
        setState(() {
          _isAnalyzing = false;
          _analysisCompleted = true;
        });
        _showErrorSnackBar('Analysis failed: $e');
      }
      DebugLogger.debug('Analysis state reset after error');
    }
  }

  void _updateBpm(int newBpm) {
    MetronomePlayer.setBpm(newBpm);
    setState(() {}); // Trigger rebuild
  }

  Future<void> _startContinuousMetronome() async {
    await MetronomePlayer.startContinuous();
    setState(() => _isPreviewingMetronome = true);
  }

  Future<void> _stopContinuousMetronome() async {
    await MetronomePlayer.stopContinuous();
    setState(() => _isPreviewingMetronome = false);
  }

  Future<void> _togglePlayback() async {
    if (_path == null) return;
    
    try {
      if (_isPlayingRecording) {
        // Stop playback
        await AudioService.instance.stopAll();
      } else {
        // Start playback via centralized audio service
        await _prepareAndPlayAudio();
      }
    } catch (e) {
      DebugLogger.debug('Playback error: $e');
      _showErrorSnackBar('Playback failed: $e');
    }
  }

  Future<void> _prepareAndPlayAudio() async {
    try {
      // Stop metronome temporarily for playback
      if (_isPreviewingMetronome) {
        await _stopContinuousMetronome();
      }
      await MetronomePlayer.stopContinuous();
      
      // File diagnostics
      await _diagnoseRecordingFile(_path!);
      
      // Wait briefly then play
      await Future.delayed(const Duration(milliseconds: 200));
      await AudioService.instance.playRecording(_path!);
      
      DebugLogger.debug('Recording playback started via AudioService (metronome fully stopped)');
    } catch (e) {
      DebugLogger.debug('Error preparing audio: $e');
      rethrow;
    }
  }
  
  /// Comprehensive recording file diagnostics
  Future<void> _diagnoseRecordingFile(String filePath) async {
    try {
      final file = File(filePath);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      
      DebugLogger.debug('=== RECORDING FILE DIAGNOSTICS ===');
      DebugLogger.debug('File path: $filePath');
      DebugLogger.debug('File exists: $exists');
      DebugLogger.debug('File size: ${(size / 1024).toStringAsFixed(1)} KB');
      
      if (exists && size > 0) {
        // Read first few bytes to check WAV header
        final bytes = await file.readAsBytes();
        final header = String.fromCharCodes(bytes.take(12));
        DebugLogger.debug('WAV header: ${header.substring(0, 4)} (should be RIFF)');
        DebugLogger.debug('Format: ${header.substring(8, 12)} (should be WAVE)');
        
        // Check if it's a valid WAV file
        if (header.startsWith('RIFF') && header.contains('WAVE')) {
          DebugLogger.debug('✅ Valid WAV file structure');
        } else {
          DebugLogger.debug('❌ INVALID WAV file structure!');
        }
        
        // Estimate duration based on file size and recording config
        final estimatedDuration = _estimateAudioDuration(size);
        DebugLogger.debug('Estimated duration: ${estimatedDuration.toStringAsFixed(1)}s');
      } else {
        DebugLogger.debug('❌ FILE MISSING OR EMPTY!');
      }
      DebugLogger.debug('=== END DIAGNOSTICS ===');
    } catch (e) {
      DebugLogger.debug('File diagnostics failed: $e');
    }
  }
  
  /// Estimate audio duration from file size
  double _estimateAudioDuration(int fileSizeBytes) {
    // WAV file size calculation:
    // Size = (sampleRate * channels * bitsPerSample * duration) / 8 + header
    const sampleRate = 44100; // Updated to match new recording config
    const channels = 1;       // Mono
    const bitsPerSample = 16; // Standard for WAV
    const headerSize = 44;    // Standard WAV header
    
    final dataSize = fileSizeBytes - headerSize;
    final bytesPerSecond = (sampleRate * channels * bitsPerSample) / 8;
    
    return dataSize / bytesPerSecond;
  }

  /// Play the extracted melody using synthesized audio
  Future<void> _playExtractedMelody() async {
    if (_extractedMelody.isEmpty) {
      _showErrorSnackBar('No melody to play. Please analyze a recording first.');
      return;
    }

    try {
      DebugLogger.debug('Playing extracted melody with ${_extractedMelody.length} notes');
      
      if (_isPlayingMelody) {
        // Stop current melody playback
        await AudioService.instance.stopAll();
        DebugLogger.debug('Stopped melody playback');
      } else {
        // EXPERIMENTAL: Check if we should run timing validation test
        // TODO: Remove this after debugging
        if (_extractedMelody.length <= 3) {
          print('Small melody detected - running timing validation test instead');
          _createTimingValidationTest();
        }
        
        // Start melody playback
        await _prepareAndPlayMelody();
      }
    } catch (e) {
      DebugLogger.debug('Melody playback error: $e');
      _showErrorSnackBar('Melody playback failed: $e');
    }
  }

  /// Prepare and play the extracted melody
  Future<void> _prepareAndPlayMelody() async {
    try {
      // Stop metronome temporarily for melody playback
      if (_isPreviewingMetronome) {
        await _stopContinuousMetronome();
      }
      await MetronomePlayer.stopContinuous();
      
      // Initialize MelodyPlayer if needed
      await MelodyPlayer.ensureLoaded(context);
      
      // CRITICAL TIMING COMPARISON DEBUG
      _debugCompareTiming();
      
      // DIRECT PLAYBACK TEST - Bypass sheet music completely
      print('=== DIRECT MELODY PLAYBACK (NO SHEET MUSIC) ===');
      print('Playing DIRECT extracted melody notes (DiscreteNote objects):');
      for (int i = 0; i < _extractedMelody.length; i++) {
        final note = _extractedMelody[i];
        print('Direct Note $i: ${note.note} at ${note.startMs}ms for ${note.durationMs}ms');
      }
      
      // Show what sheet music generated vs what we're actually playing
      if (_sheetMusicData != null) {
        print('--- COMPARISON: DiscreteNotes vs Sheet Music ---');
        print('PLAYING (DiscreteNotes): ${_extractedMelody.map((n) => '${n.note}@${n.startMs}ms').join(' → ')}');
        print('SHEET (converted):       ${_sheetMusicData!.notes.map((n) => '${n.displayNote}@${n.startBeat}beat').join(' → ')}');
        print('--- END COMPARISON ---');
      }
      
      print('IMPORTANT: MelodyPlayer receives DiscreteNotes directly, NOT sheet music!');
      print('=== END DIRECT MELODY DEBUG ===');
      
      DebugLogger.debug('Playing melody with notes: ${_extractedMelody.map((n) => '${n.note}(${n.startMs}ms,${n.durationMs}ms)').join(', ')}');
      
      // Play the melody through MelodyPlayer which will use AudioService
      await MelodyPlayer.playMelody(_extractedMelody);
      
      DebugLogger.debug('Melody playback started via AudioService (metronome stopped)');
    } catch (e) {
      DebugLogger.debug('Error preparing melody: $e');
      rethrow;
    }
  }
  
  /// Debug method to compare timing between extracted melody and sheet music
  void _debugCompareTiming() {
    if (_extractedMelody.isEmpty) return;
    
    print('=== MELODY TIMING COMPARISON DEBUG ===');
    print('Total extracted notes: ${_extractedMelody.length}');
    
    if (_sheetMusicData != null && _sheetMusicData!.notes.isNotEmpty) {
      print('Total sheet music notes: ${_sheetMusicData!.notes.length}');
      
      final minLength = math.min(_extractedMelody.length, _sheetMusicData!.notes.length);
      
      for (int i = 0; i < minLength; i++) {
        final extractedNote = _extractedMelody[i];
        final sheetNote = _sheetMusicData!.notes[i];
        
        print('Note $i:');
        print('  Extracted: ${extractedNote.note} | ${extractedNote.startMs}ms-${extractedNote.startMs + extractedNote.durationMs}ms (${extractedNote.durationMs}ms)');
        print('  Sheet:     ${sheetNote.displayNote} | Beat ${sheetNote.startBeat}-${sheetNote.startBeat + sheetNote.duration.durationRatio} (${sheetNote.duration.name} ${sheetNote.duration.durationRatio} beats)');
        
        // Calculate expected timing if sheet music timing is correct
        final expectedStartMs = (sheetNote.startBeat * (60000 / 120)).round(); // Assuming 120 BPM
        final expectedDurationMs = (sheetNote.duration.durationRatio * (60000 / 120)).round();
        print('  Expected:  ${sheetNote.displayNote} | ${expectedStartMs}ms-${expectedStartMs + expectedDurationMs}ms (${expectedDurationMs}ms @ 120BPM)');
        
        // Check for timing discrepancies
        final startDiff = (extractedNote.startMs - expectedStartMs).abs();
        final durationDiff = (extractedNote.durationMs - expectedDurationMs).abs();
        
        if (startDiff > 100) { // More than 100ms difference
          print('  WARNING: Start timing differs by ${startDiff}ms');
        }
        if (durationDiff > 100) {
          print('  WARNING: Duration differs by ${durationDiff}ms');
        }
      }
      
      if (_extractedMelody.length != _sheetMusicData!.notes.length) {
        print('WARNING: Note count mismatch! Extracted: ${_extractedMelody.length}, Sheet: ${_sheetMusicData!.notes.length}');
      }
    } else {
      print('No sheet music data available for comparison');
    }
    
    // Show melody timeline
    print('--- MELODY TIMELINE ---');
    for (int i = 0; i < _extractedMelody.length; i++) {
      final note = _extractedMelody[i];
      final startSec = note.startMs / 1000.0;
      final endSec = (note.startMs + note.durationMs) / 1000.0;
      print('${startSec.toStringAsFixed(2)}s-${endSec.toStringAsFixed(2)}s: ${note.note}');
    }
    
    print('=== END TIMING COMPARISON DEBUG ===');
  }
  
  /// Create a simple validation test melody for exact timing verification
  void _createTimingValidationTest() {
    print('=== CREATING TIMING VALIDATION TEST ===');
    
    // Create a simple test melody with known timing - IDENTICAL TO WHAT YOU RECORDED
    final testMelody = [
      DiscreteNote(note: 'C', startMs: 0, durationMs: 1000),     // 0-1 seconds: C
      DiscreteNote(note: 'D', startMs: 1500, durationMs: 1000), // 1.5-2.5 seconds: D (with 500ms gap)  
      DiscreteNote(note: 'E', startMs: 3000, durationMs: 1000), // 3-4 seconds: E (with 500ms gap)
    ];
    
    print('Test melody timing (what MelodyPlayer will receive):');
    for (int i = 0; i < testMelody.length; i++) {
      final note = testMelody[i];
      print('Test Note $i: ${note.note} at ${(note.startMs/1000).toStringAsFixed(1)}s for ${(note.durationMs/1000).toStringAsFixed(1)}s');
      
      if (i > 0) {
        final prevNote = testMelody[i - 1];
        final gapMs = note.startMs - (prevNote.startMs + prevNote.durationMs);
        print('  → Gap from previous: ${gapMs}ms');
      }
    }
    
    // Temporarily replace extracted melody with test melody
    print('REPLACING extracted melody with KNOWN GOOD test melody for validation...');
    print('This bypasses ALL extraction issues and tests ONLY MelodyPlayer synthesis.');
    _extractedMelody = testMelody;
    
    print('🎵 EXPECTED PLAYBACK SEQUENCE:');
    print('  0.0s: C note starts');
    print('  1.0s: C note ends, silence begins');
    print('  1.5s: D note starts');  
    print('  2.5s: D note ends, silence begins');
    print('  3.0s: E note starts');
    print('  4.0s: E note ends');
    print('');
    print('🎧 LISTEN: If timing is wrong, the problem is in MelodyPlayer synthesis');
    print('🎧 LISTEN: If timing is correct, the problem is in note extraction/consolidation');
    print('=== END TIMING VALIDATION TEST ===');
  }
  
  /// Force a manual melody for testing (call this method to override extracted melody)
  void _forceKnownMelody() {
    print('=== FORCING KNOWN MELODY FOR COMPARISON ===');
    
    // You can modify these notes to match exactly what you recorded
    // Format: DiscreteNote(note: 'NOTE_NAME', startMs: START_TIME, durationMs: DURATION)
    final manualMelody = [
      // Example: If you recorded C-E-G at 1 second intervals:
      DiscreteNote(note: 'C', startMs: 0, durationMs: 800),      // C at 0s
      DiscreteNote(note: 'E', startMs: 1000, durationMs: 800),  // E at 1s  
      DiscreteNote(note: 'G', startMs: 2000, durationMs: 800),  // G at 2s
      
      // TODO: Replace these with your actual recorded sequence
      // If you recorded different notes, change them here
    ];
    
    print('Manual melody (edit this to match your recording):');
    for (int i = 0; i < manualMelody.length; i++) {
      final note = manualMelody[i];
      print('Manual Note $i: ${note.note} at ${(note.startMs/1000).toStringAsFixed(1)}s for ${(note.durationMs/1000).toStringAsFixed(1)}s');
    }
    
    _extractedMelody = manualMelody;
    print('MELODY REPLACED: Now play melody to test if MelodyPlayer synthesis works correctly');
    print('=== END FORCED MELODY ===');
  }

  /// Extract melody notes from the recorded file for sheet music generation
  Future<void> _extractMelodyFromRecordingIsolate() async {
    if (_path == null) return;

    try {
      DebugLogger.debug('Extracting melody from recording for sheet music (background)');
      
      // TEMPORARY: Use main thread for debugging (isolate hides print logs)
      // TODO: Revert to isolate after debugging
      final notes = await _extractMelodyMainThread(_path!);
      
      _extractedMelody = notes;
      DebugLogger.debug('Extracted ${notes.length} melody notes for sheet music');
      
      // DEBUG: Show extracted melody details immediately
      print('=== EXTRACTED MELODY DETAILS ===');
      for (int i = 0; i < notes.length && i < 10; i++) { // Show first 10 notes max
        final note = notes[i];
        print('Extracted Note $i: ${note.note} at ${note.startMs}ms for ${note.durationMs}ms');
      }
      if (notes.length > 10) {
        print('... and ${notes.length - 10} more notes');
      }
      print('=== END EXTRACTED MELODY DETAILS ===');
      
    } catch (e) {
      DebugLogger.debug('Error extracting melody: $e');
      _extractedMelody = const [];
    }
  }
  
  /// Extract melody in main thread for debugging (shows all print logs)
  Future<List<DiscreteNote>> _extractMelodyMainThread(String filePath) async {
    try {
      print('=== STARTING MELODY EXTRACTION (MAIN THREAD) ===');
      print('File path: $filePath');
      
      // Use the same pipeline as analysis to extract melody
      final bytes = await File(filePath).readAsBytes();
      print('File loaded: ${bytes.length} bytes');
      
      final wav = WavDecoder.decode(bytes);
      if (wav == null || wav.samples.isEmpty) {
        print('WAV decoding failed or no samples');
        return const [];
      }
      print('WAV decoded: ${wav.samples.length} samples at ${wav.sampleRate}Hz');
      
      // Extract pitches and convert to notes (same as analysis)
      const detector = PitchDetector();
      print('Starting pitch detection...');
      final pitches = detector.analyze(wav.samples, wav.sampleRate.toDouble());
      
      print('Pitch detection complete: ${pitches.length} pitch points');
      if (pitches.isEmpty) {
        print('No pitches detected!');
        return const [];
      }
      
      // Show first few pitch points for debugging
      print('First 5 pitch points:');
      for (int i = 0; i < pitches.length && i < 5; i++) {
        final p = pitches[i];
        print('  PitchPoint $i: ${p.note} at ${p.timeSec.toStringAsFixed(2)}s (${p.frequencyHz.toStringAsFixed(1)}Hz)');
      }
      
      print('Starting note consolidation...');
      final notes = PitchToNotes.consolidate(pitches);
      print('Note consolidation complete: ${notes.length} discrete notes');
      print('=== END MELODY EXTRACTION (MAIN THREAD) ===');
      
      return notes;
      
    } catch (e) {
      print('Melody extraction error: $e');
      return const [];
    }
  }

  /// Generate sheet music from extracted melody
  Future<void> _generateSheetMusic() async {
    if (_extractedMelody.isEmpty || _detectedKey == null) {
      _showErrorSnackBar('No melody available for sheet music generation');
      return;
    }

    try {
      DebugLogger.debug('Generating sheet music from ${_extractedMelody.length} notes');
      
      // Generate sheet music data
      final sheetMusic = SimpleSheetMusicService.convertMelodyToSheetMusic(
        _extractedMelody,
        _detectedKey!,
        bpm: MetronomePlayer.bpm,
      );
      
      setState(() {
        _sheetMusicData = sheetMusic;
      });
      
      // Show sheet music modal
      if (mounted && _sheetMusicData != null) {
        await SimpleSheetMusicModal.show(context, _sheetMusicData!);
      }
      
      DebugLogger.debug('Sheet music generated and displayed');
      
    } catch (e) {
      DebugLogger.debug('Error generating sheet music: $e');
      _showErrorSnackBar('Failed to generate sheet music: $e');
    }
  }

  /// Clear current recording and return to recording state
  Future<void> _recordNew() async {
    try {
      // Stop any current playback
      await AudioService.instance.stopAll();
      
      // Clear current recording and analysis results
      setState(() {
        _path = null;
        _analysisCompleted = false;
        _detectedKey = null;
        _suggestions = const [];
        _selectedChord = null;
        _lastRmsDb = null;
        _isPlayingRecording = false;
        _playbackProgress = 0.0;
        _progressTimer?.cancel();
        _progressTimer = null;
        _extractedMelody = const [];
        _sheetMusicData = null;
      });
      
      DebugLogger.debug('Cleared recording - ready for new recording');
    } catch (e) {
      DebugLogger.debug('Error clearing recording: $e');
      _showErrorSnackBar('Failed to prepare for new recording');
    }
  }

  /// Configure audio session to allow concurrent metronome + recording
  Future<void> _configureRecordingAudioSession() async {
    try {
      final session = await AudioSession.instance;
      
      // Configure for speech/recording mode allowing concurrent audio
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ));
      
      DebugLogger.debug('Audio session configured for concurrent recording + metronome');
    } catch (e) {
      DebugLogger.debug('Warning: Could not configure recording audio session: $e');
    }
  }

  /// Static function to run analysis in background isolate
  static Future<AnalysisResult> _analyzeRecordingIsolate(String filePath) async {
    // This runs in a separate isolate to prevent blocking UI
    return await AnalysisService.analyzeRecording(filePath);
  }

  /// Static function to extract melody in background isolate
  static Future<List<DiscreteNote>> _extractMelodyIsolate(String filePath) async {
    try {
      // Use the same pipeline as analysis to extract melody
      final bytes = await File(filePath).readAsBytes();
      final wav = WavDecoder.decode(bytes);
      
      if (wav == null || wav.samples.isEmpty) {
        return const [];
      }

      // Extract pitches and convert to notes (same as analysis)
      const detector = PitchDetector();
      final pitches = detector.analyze(wav.samples, wav.sampleRate.toDouble());
      
      if (pitches.isEmpty) {
        return const [];
      }

      final notes = PitchToNotes.consolidate(pitches);
      return notes;
      
    } catch (e) {
      return const [];
    }
  }

  @override
  void dispose() async {
    _timer?.cancel();
    _progressTimer?.cancel();
    _analyzeButtonController.dispose();
    
    // Stop and dispose audio resources properly
    try {
      await AudioService.instance.stopAll();
      await ChordPlayer.dispose();
      await MetronomePlayer.dispose();
      // Note: AudioService disposal is handled globally, not per-page
    } catch (e) {
      DebugLogger.debug('Disposal error: $e');
    }
    
    super.dispose();
  }

  /// Start tracking playback progress with diagnostics
  void _startProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted && _isPlayingRecording && AudioService.instance.isPlaying) {
        final audioService = AudioService.instance;
        final progress = audioService.progress;
        final diagnostics = audioService.playbackDiagnostics;
        
        setState(() {
          _playbackProgress = progress;
        });
        
        // Enhanced logging for debugging
        if (timer.tick % 20 == 0) { // Log every 2 seconds
          DebugLogger.debug('Playback: ${(progress * 100).toStringAsFixed(1)}% - $diagnostics');
        }
        
        // CRITICAL FIX: Stop tracking when audio service indicates not playing
        if (!audioService.isPlaying) {
          DebugLogger.debug('AudioService indicates playback stopped - stopping progress tracking');
          timer.cancel();
          if (mounted) {
            setState(() {
              _isPlayingRecording = false;
              _playbackProgress = 0.0;
            });
          }
          return;
        }
        
        // Verify playback integrity (async check)
        if (progress > 0.5) {
          audioService.verifyPlaybackIntegrity().then((isValid) {
            if (!isValid) {
              DebugLogger.debug('Warning: Playback integrity issue detected');
            }
          });
        }
        
        // Stop timer when playback completes
        if (progress >= 0.99) { // Use 99% to account for rounding
          DebugLogger.debug('Playback completed - stopping progress tracking');
          timer.cancel();
        }
      } else {
        DebugLogger.debug('Stopping progress tracking - conditions not met (mounted: $mounted, playing: $_isPlayingRecording, service: ${AudioService.instance.isPlaying})');
        timer.cancel();
      }
    });
  }

  Widget _buildPlaybackProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Playing',
              style: MinimalDesign.caption.copyWith(
                color: MinimalDesign.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${(_playbackProgress * 100).toStringAsFixed(0)}%',
              style: MinimalDesign.caption,
            ),
          ],
        ),
        MinimalDesign.verticalSpace(MinimalDesign.space1),
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: MinimalDesign.lightGray,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _playbackProgress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: MinimalDesign.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalPlaybackControls() {
    return Padding(
      padding: MinimalDesign.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recording Complete',
            style: MinimalDesign.heading,
          ),
          MinimalDesign.verticalSpace(MinimalDesign.space3),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _path != null ? _togglePlayback : null,
                  child: Text(_isPlayingRecording ? 'Stop' : 'Play'),
                ),
              ),
              MinimalDesign.horizontalSpace(MinimalDesign.space3),
              Expanded(
                child: _buildAnimatedAnalyzeButton(),
              ),
            ],
          ),
          
          // Playback progress bar
          if (_isPlayingRecording || _playbackProgress > 0.0) ...{
            MinimalDesign.verticalSpace(MinimalDesign.space2),
            _buildPlaybackProgressBar(),
          },
          
          MinimalDesign.verticalSpace(MinimalDesign.space3),
          
          // Record New button for clean workflow
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isAnalyzing ? null : _recordNew,
              style: ElevatedButton.styleFrom(
                backgroundColor: MinimalDesign.lightGray,
                foregroundColor: MinimalDesign.black,
              ),
              child: const Text('Record New'),
            ),
          ),
          if (_lastRmsDb != null) ...[
            MinimalDesign.verticalSpace(MinimalDesign.space2),
            Text(
              'Level: ${_lastRmsDb!.toStringAsFixed(1)} dBFS',
              style: MinimalDesign.caption,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMinimalKeyDisplay() {
    return Padding(
      padding: MinimalDesign.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Key: $_detectedKey',
                style: MinimalDesign.heading,
              ),
              // Action buttons - Only show if melody was extracted
              if (_extractedMelody.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Play Melody Button
                    ElevatedButton(
                      onPressed: _playExtractedMelody,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPlayingMelody ? MinimalDesign.black : MinimalDesign.white,
                        foregroundColor: _isPlayingMelody ? MinimalDesign.white : MinimalDesign.black,
                        side: BorderSide(
                          color: MinimalDesign.black,
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: MinimalDesign.space3,
                          vertical: MinimalDesign.space2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isPlayingMelody ? Icons.stop : Icons.play_arrow,
                            size: 18,
                            color: _isPlayingMelody ? MinimalDesign.white : MinimalDesign.black,
                          ),
                          const SizedBox(width: MinimalDesign.space1),
                          Text(
                            _isPlayingMelody ? 'Stop' : 'Play Melody',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _isPlayingMelody ? MinimalDesign.white : MinimalDesign.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: MinimalDesign.space2),
                    // Sheet Music Button
                    ElevatedButton(
                      onPressed: _generateSheetMusic,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MinimalDesign.white,
                        foregroundColor: MinimalDesign.black,
                        side: BorderSide(
                          color: MinimalDesign.black,
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: MinimalDesign.space3,
                          vertical: MinimalDesign.space2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.music_note,
                            size: 18,
                            color: MinimalDesign.black,
                          ),
                          const SizedBox(width: MinimalDesign.space1),
                          const Text(
                            'Create Sheet Music',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Progress indicator for melody playback
          if (_isPlayingMelody && _extractedMelody.isNotEmpty) ...[
            MinimalDesign.verticalSpace(MinimalDesign.space2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MinimalDesign.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Playing melody...',
                    style: TextStyle(
                      fontSize: 12,
                      color: MinimalDesign.black.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: MinimalDesign.space1),
                  LinearProgressIndicator(
                    backgroundColor: MinimalDesign.black.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(MinimalDesign.black),
                  ),
                ],
              ),
            ),
          ],
          MinimalDesign.verticalSpace(MinimalDesign.space2),
        ],
      ),
    );
  }

  Widget _buildMinimalChordDisplay() {
    return Padding(
      padding: MinimalDesign.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chord Progressions',
            style: MinimalDesign.heading,
          ),
          MinimalDesign.verticalSpace(MinimalDesign.space3),
          for (final progression in _suggestions) ...[
            Text(
              '${progression.name} in ${progression.key}',
              style: MinimalDesign.body,
            ),
            MinimalDesign.verticalSpace(MinimalDesign.space2),
            Wrap(
              spacing: MinimalDesign.space2,
              runSpacing: MinimalDesign.space1,
              children: progression.chords.map((chord) {
                final isSelected = _selectedChord?.symbol == chord.symbol;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedChord = chord);
                    ChordPlayer.playChord(chord.notes);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? MinimalDesign.black : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? MinimalDesign.black : MinimalDesign.lightGray,
                      ),
                    ),
                    child: Text(
                      chord.symbol,
                      style: MinimalDesign.body.copyWith(
                        color: isSelected ? MinimalDesign.white : MinimalDesign.black,
                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            MinimalDesign.verticalSpace(MinimalDesign.space3),
          ],
        ],
      ),
    );
  }

  Widget _buildNoSuggestionsMessage() {
    return Padding(
      padding: MinimalDesign.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analysis Complete',
            style: MinimalDesign.heading,
          ),
          MinimalDesign.verticalSpace(MinimalDesign.space3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: MinimalDesign.lightGray.withValues(alpha: 0.3),
              border: Border.all(
                color: MinimalDesign.lightGray,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.music_note,
                  size: 32,
                  color: MinimalDesign.black.withValues(alpha: 0.6),
                ),
                MinimalDesign.verticalSpace(MinimalDesign.space2),
                Text(
                  'Unable to generate chord suggestions',
                  style: MinimalDesign.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                MinimalDesign.verticalSpace(MinimalDesign.space1),
                Text(
                  'Try recording with clearer melody or stronger note definition',
                  style: MinimalDesign.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          MinimalDesign.verticalSpace(MinimalDesign.space3),
          ElevatedButton(
            onPressed: () {
              _clearAnalysisState();
            },
            child: const Text('Record Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: MinimalDesign.theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cora'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: MinimalDesign.space3),
              child: MinimalDesign.buildThemeToggle(widget.onThemeToggle),
            ),
          ],
        ),
        
        body: _isAnalyzing 
            ? const MinimalAnalyzingAnimation()
            : SingleChildScrollView(
                child: Column(
                  children: [
                    MinimalRecordingInterface(
                      isRecording: _isRecording,
                      isWaitingForCountIn: _waitingForCountIn,
                      seconds: _seconds,
                      maxSeconds: _maxSeconds,
                      onRecord: _start,
                      onStop: _stop,
                      recordingPhase: _recordingPhase,
                      currentBeat: _currentBeat,
                      totalBeats: _totalBeats,
                      useMetronome: _useMetronome,
                      onMetronomeToggle: (enabled) {
                        setState(() => _useMetronome = enabled);
                        MetronomePlayer.setEnabled(enabled);
                      },
                    ),
                    
                    if (_useMetronome && 
                        !(_isRecording || _waitingForCountIn) && 
                        _path == null) // Hide when recording is available
                      MinimalDesign.section(
                        child: MinimalMetronomeControls(
                          enabled: _useMetronome,
                          bpm: MetronomePlayer.bpm,
                          timeSignature: MetronomePlayer.timeSignature,
                          isPlaying: _isPreviewingMetronome,
                          onEnabledChanged: (enabled) {
                            setState(() => _useMetronome = enabled);
                            MetronomePlayer.setEnabled(enabled);
                          },
                          onBpmChanged: _updateBpm,
                          onTimeSignatureChanged: (ts) {
                            MetronomePlayer.setTimeSignature(ts);
                            setState(() => _totalBeats = ts.numerator);
                          },
                          onStartStop: _isPreviewingMetronome 
                              ? _stopContinuousMetronome
                              : _startContinuousMetronome,
                        ),
                      ),
                    
                    if (_path != null && !_analysisCompleted)
                      _buildMinimalPlaybackControls(),
                    
                    if (_analysisCompleted && _suggestions.isEmpty)
                      _buildNoSuggestionsMessage(),
                    
                    if (_suggestions.isNotEmpty) ...[
                      if (_detectedKey != null)
                        _buildMinimalKeyDisplay(),
                      
                      _buildMinimalChordDisplay(),
                      
                      MinimalDesign.verticalSpace(MinimalDesign.space4),
                      
                      Padding(
                        padding: MinimalDesign.screenPadding,
                        child: MinimalPianoKeyboard(
                          selectedChord: _selectedChord,
                          onNotePressed: (note) {
                            ChordPlayer.playChord([note]);
                          },
                        ),
                      ),
                    ],
                    
                    MinimalDesign.verticalSpace(MinimalDesign.space8),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAnimatedAnalyzeButton() {
    return AnimatedBuilder(
      animation: _analyzeButtonAnimation,
      builder: (context, child) {
        return ElevatedButton(
          onPressed: (_path != null && !_isAnalyzing) ? _analyzeRecording : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isAnalyzing 
                ? MinimalDesign.accent.withValues(alpha: 0.1 + 0.3 * _analyzeButtonAnimation.value)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isAnalyzing) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(MinimalDesign.accent),
                    value: null, // Indeterminate
                  ),
                ),
                MinimalDesign.horizontalSpace(MinimalDesign.space2),
                Text(
                  'Analyzing...',
                  style: TextStyle(
                    color: MinimalDesign.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                const Text('Analyze'),
              ],
            ],
          ),
        );
      },
    );
  }
}