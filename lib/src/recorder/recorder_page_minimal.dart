import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../sound/chord_player.dart';
import '../analysis/analysis_service.dart';
import '../audio/wav_decoder.dart';
import '../analysis/chord_progression_suggestion.dart';
import '../analysis/detected_chord.dart';
import '../widgets/minimal_piano_keyboard.dart';
import '../widgets/minimal_recording_interface.dart';
import '../widgets/minimal_metronome_controls.dart';
import '../widgets/minimal_analyzing_animation.dart';
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

  // Recording diagnostics
  double? _lastRmsDb;
  
  // Piano keyboard state
  DetectedChord? _selectedChord;
  
  // Metronome state
  bool _useMetronome = false;
  bool _continueMetronomeDuringRecording = false;
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
      duration: const Duration(milliseconds: 1000),
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
      if (mounted) {
        setState(() {
          _isPlayingRecording = isPlaying;
        });
      }
    });
  }
  
  Future<void> _initMetronome() async {
    await MetronomePlayer.ensureLoaded(context);
    
    MetronomePlayer.setBeatCallback((beat, totalBeats, phase) {
      if (!mounted) return;
      
      if (_currentBeat != beat || _totalBeats != totalBeats || _recordingPhase != phase) {
        scheduleMicrotask(() {
          if (!mounted) return;
          setState(() {
            _currentBeat = beat;
            _totalBeats = totalBeats;
            _recordingPhase = phase;
          });
        });
      }
    });
    
    MetronomePlayer.setCountInCompleteCallback(() {
      if (!mounted) return;
      scheduleMicrotask(() {
        if (mounted && _waitingForCountIn) {
          _startActualRecording();
        }
      });
    });
    
    setState(() {
      _useMetronome = MetronomePlayer.enabled;
      _continueMetronomeDuringRecording = MetronomePlayer.continueMetronomeDuringRecording;
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
      _path = '${tempDir.path}/temp.wav'; // Keep WAV for compatibility with analysis

      _seconds = 0;
      
      if (_useMetronome) {
        setState(() {
          _waitingForCountIn = true;
          _recordingPhase = RecordingPhase.countIn;
        });
        
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

      // Lower metronome volume during recording
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

      try {
        // Stop all audio playback before recording
        await AudioService.instance.stopAll();
        await ChordPlayer.stopAnyPlayback();
        
        // Stop metronome preview if running
        if (_isPreviewingMetronome) {
          await _stopContinuousMetronome();
        }
        
        // Configure audio session for recording
        await AudioService.instance.prepareForRecording();
        
        // Give audio system time to settle
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (e) {
        DebugLogger.debug('Warning: Error stopping audio resources: $e');
      }
      
      // Use WAV with reduced quality for smaller file size (~800KB vs ~1.7MB)
      await _record.start(const RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 64000, // Lower bitrate to reduce size
        sampleRate: 22050, // Half sample rate for smaller file
      ), path: _path!);
    } catch (e) {
      await MetronomePlayer.stopMetronome();
      setState(() {
        _isRecording = false;
        _waitingForCountIn = false;
        _recordingPhase = RecordingPhase.idle;
      });
      rethrow;
    }
  }
  
  Future<void> _stop() async {
    await MetronomePlayer.stopRecordingMetronome();
    
    // Restore normal metronome volume
    MetronomePlayer.setRecordingMode(false);
    
    String? filePath;
    if (_isRecording) {
      filePath = await _record.stop();
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
    });
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
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
      // Ensure minimum animation visibility (1.5 seconds)
      final analysisStartTime = DateTime.now();
      
      final result = await AnalysisService.analyzeRecording(_path!);
      
      final analysisEndTime = DateTime.now();
      final analysisDuration = analysisEndTime.difference(analysisStartTime);
      
      DebugLogger.debug('Analysis completed in ${analysisDuration.inMilliseconds}ms');
      
      // Ensure minimum 1500ms for animation visibility
      const minDuration = Duration(milliseconds: 1500);
      if (analysisDuration < minDuration) {
        final remainingTime = minDuration - analysisDuration;
        DebugLogger.debug('Adding ${remainingTime.inMilliseconds}ms delay for animation visibility');
        await Future.delayed(remainingTime);
      }
      
      if (mounted) {
        _analyzeButtonController.stop();
        _analyzeButtonController.reset();
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
      
      // Ensure minimum animation time even on error
      await Future.delayed(const Duration(milliseconds: 1500));
      
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
      // Step 1: Stop any ongoing metronome to avoid conflicts
      if (_isPreviewingMetronome) {
        await _stopContinuousMetronome();
      }
      
      // Step 2: Play recording via centralized service
      await AudioService.instance.playRecording(_path!);
      
      DebugLogger.debug('Recording playback started via AudioService');
    } catch (e) {
      DebugLogger.debug('Error preparing audio: $e');
      rethrow;
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
      });
      
      DebugLogger.debug('Cleared recording - ready for new recording');
    } catch (e) {
      DebugLogger.debug('Error clearing recording: $e');
      _showErrorSnackBar('Failed to prepare for new recording');
    }
  }

  @override
  void dispose() async {
    _timer?.cancel();
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
          Text(
            'Key: $_detectedKey',
            style: MinimalDesign.heading,
          ),
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