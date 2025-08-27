import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../sound/chord_player.dart';
import '../analysis/analysis_service.dart';
import '../audio/wav_decoder.dart';
import '../audio/pitch_detector.dart';
import '../audio/pitch_to_notes.dart';
import '../analysis/key_detection.dart';
import '../analysis/chord_engine.dart' as CE;
import '../analysis/chord_progression_suggestion.dart';
import '../analysis/detected_chord.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/metronome_controls.dart';
import '../sound/metronome_player.dart';
import '../theme/theme_provider.dart';

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});
  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> with TickerProviderStateMixin {
  final AudioRecorder _record = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer;
  int _seconds = 0;
  String? _path;
  bool _isRecording = false;
  static const int _maxSeconds = 20;

  bool _isAnalyzing = false;
  String? _detectedKey;
  List<ChordProgressionSuggestion> _suggestions = const [];

  // Playback UI state
  Duration? _playbackDuration;
  Duration _playbackPosition = Duration.zero;
  bool _isPlayingBack = false;
  // Recording diagnostics
  double? _lastRmsDb;
  
  // Animation for musical note
  late AnimationController _noteAnimationController;
  late Animation<double> _noteAnimation;
  
  // Piano keyboard state
  DetectedChord? _selectedChord;
  
  // Metronome state
  bool _useMetronome = false;
  RecordingPhase _recordingPhase = RecordingPhase.idle;
  int _currentBeat = 0;
  int _totalBeats = 4;
  bool _waitingForCountIn = false;

  @override
  void initState() {
    super.initState();
    _initAudioSession();
    _loadSf();
    _bindPlayerStreams();
    _initMetronome();
    
    // Initialize animation controller
    _noteAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _noteAnimation = Tween<double>(
      begin: 0.0,
      end: -20.0,
    ).animate(CurvedAnimation(
      parent: _noteAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  Future<void> _loadSf() async {
    await ChordPlayer.ensureLoaded(context);
  }
  
  Future<void> _initMetronome() async {
    await MetronomePlayer.ensureLoaded(context);
    
    // Set up metronome callbacks with throttling
    MetronomePlayer.setBeatCallback((beat, totalBeats, phase) {
      if (!mounted) return;
      print('RecorderPage: Received beat callback - beat=$beat/$totalBeats phase=$phase');
      
      // Only update if something actually changed to prevent excessive rebuilds
      if (_currentBeat != beat || _totalBeats != totalBeats || _recordingPhase != phase) {
        print('RecorderPage: Updating UI state - beat $_currentBeat→$beat phase $_recordingPhase→$phase');
        
        // Use scheduleMicrotask to avoid blocking main thread with setState()
        scheduleMicrotask(() {
          if (!mounted) return;
          setState(() {
            _currentBeat = beat;
            _totalBeats = totalBeats;
            _recordingPhase = phase;
          });
        });
      } else {
        print('RecorderPage: No UI update needed - values unchanged');
      }
    });
    
    MetronomePlayer.setCountInCompleteCallback(() {
      if (!mounted) return;
      // Use scheduleMicrotask to avoid timer callback issues
      scheduleMicrotask(() {
        if (mounted && _waitingForCountIn) {
          _startActualRecording();
        }
      });
    });
    
    // Sync initial state
    setState(() {
      _useMetronome = MetronomePlayer.enabled;
      _totalBeats = MetronomePlayer.timeSignature.numerator;
    });
  }

  Future<void> _toggle() async {
    if (_isRecording || _waitingForCountIn) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    try {
      print('=== STARTING RECORDING WORKFLOW ===');
      
      // Pause any ongoing chord playback to avoid audio mix issues
      try { 
        await _player.stop(); 
        await ChordPlayer.stopAnyPlayback();
        print('Stopped existing audio playback');
      } catch (e) {
        print('Warning: Error stopping audio playback: $e');
      }

      print('Requesting microphone permission...');
      final mic = await Permission.microphone.request();
      if (mic != PermissionStatus.granted) {
        print('ERROR: Microphone permission not granted - status: $mic');
        _showErrorSnackBar('Microphone permission is required to record');
        return;
      }
      print('✓ Microphone permission granted');

      final tempDir = await getTemporaryDirectory();
      _path = '${tempDir.path}/temp.wav';
      print('Recording path set to: $_path');

      _seconds = 0;
      
      if (_useMetronome) {
        print('Using metronome - starting count-in phase');
        // Start with count-in if metronome is enabled
        setState(() {
          _waitingForCountIn = true;
          _recordingPhase = RecordingPhase.countIn;
        });
        
        print('Starting recording with metronome count-in');
        await MetronomePlayer.startRecordingWithCountIn();
      } else {
        print('No metronome - starting recording immediately');
        // Start recording immediately if metronome is disabled
        await _startActualRecording();
      }
      print('=== RECORDING WORKFLOW START COMPLETE ===');
    } catch (e) {
      print('ERROR starting recording: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        _waitingForCountIn = false;
        _recordingPhase = RecordingPhase.idle;
      });
      _showErrorSnackBar('Failed to start recording: $e');
    }
  }

  /// Starts the actual audio recording (called after count-in or immediately)
  Future<void> _startActualRecording() async {
    try {
      // Validate path exists before starting
      if (_path == null) {
        print('Error: Recording path is null!');
        throw Exception('Recording path not initialized');
      }
      
      print('Starting actual recording to: $_path');
      
      setState(() {
        _isRecording = true;
        _waitingForCountIn = false;
        _recordingPhase = RecordingPhase.recording;
      });
      
      // Start note bouncing animation
      _noteAnimationController.repeat(reverse: true);
      
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (!mounted) return;
        setState(() => _seconds = _seconds + 1);
        if (_seconds >= _maxSeconds) {
          await _stop();
        }
      });

      // CRITICAL: Ensure all audio resources are stopped before recording
      try {
        await _player.stop();
        await ChordPlayer.stopAnyPlayback();
        // Give metronome time to finish current beat if playing
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        print('Warning: Error stopping audio resources: $e');
      }

      // Configure audio session for recording
      await _configureForRecording();
      
      // Add delay to ensure audio session is properly configured
      await Future.delayed(const Duration(milliseconds: 150));
      
      await _record.start(const RecordConfig(encoder: AudioEncoder.wav), path: _path!);
      print('Actual recording started successfully');
    } catch (e) {
      print('Error starting actual recording: $e');
      // Stop metronome on error
      await MetronomePlayer.stopMetronome();
      setState(() {
        _isRecording = false;
        _waitingForCountIn = false;
        _recordingPhase = RecordingPhase.idle;
      });
      rethrow; // Re-throw so caller can handle
    }
  }
  
  Future<void> _stop() async {
    // Stop metronome first
    await MetronomePlayer.stopMetronome();
    
    String? filePath;
    if (_isRecording) {
      filePath = await _record.stop();
    }
    
    _timer?.cancel();
    
    // Stop note animation
    _noteAnimationController.stop();
    _noteAnimationController.reset();
    
    setState(() {
      _isRecording = false;
      _waitingForCountIn = false;
      _recordingPhase = RecordingPhase.idle;
      _currentBeat = 0;
      _path = filePath ?? _path;
      _seconds = 0;
    });
    
    // Switch session to playback after recording ends
    await _configureForPlayback();
    
    // Compute simple RMS level to detect silence
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
        print('Error computing RMS: $e');
      }
    }
  }

  void _bindPlayerStreams() {
    _player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _playbackDuration = d);
    });
    _player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _playbackPosition = p);
    });
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlayingBack = state.playing);
    });
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    // Start with a playback configuration; switch to record when needed
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker | AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
        flags: AndroidAudioFlags.none,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));
  }

  Future<void> _configureForRecording() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker | AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.measurement,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
        flags: AndroidAudioFlags.none,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));
    await session.setActive(true);
  }

  Future<void> _configureForPlayback() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker | AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
        flags: AndroidAudioFlags.none,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));
    await session.setActive(true);
  }

  List<String> _voiceChord(List<String> triad) {
    // Map note names to specific octaves for nicer playback
    final octaveMap = {
      'C':'C4','C#':'C#4','D':'D4','D#':'D#4','E':'E4','F':'F4','F#':'F#4','G':'G4','G#':'G#4','A':'A4','A#':'A#4','B':'B4'
    };
    return triad.map((n) => octaveMap[n] ?? n).toList();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _noteAnimationController.dispose();
    _player.dispose();
    ChordPlayer.dispose(); // Fire and forget for cleanup
    MetronomePlayer.dispose(); // Fire and forget for cleanup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cora Recorder'),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                onPressed: () => themeProvider.toggleTheme(),
                icon: Icon(
                  themeProvider.isDarkMode 
                    ? Icons.wb_sunny 
                    : Icons.nightlight_round,
                ),
                tooltip: themeProvider.isDarkMode 
                  ? 'Switch to Light Mode' 
                  : 'Switch to Dark Mode',
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metronome Controls
            MetronomeControls(
              onEnabledChanged: (enabled) {
                setState(() => _useMetronome = enabled);
              },
              onTimeSignatureChanged: (timeSignature) {
                setState(() => _totalBeats = timeSignature.numerator);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _toggle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_isRecording || _waitingForCountIn) 
                        ? Colors.red 
                        : null,
                    foregroundColor: (_isRecording || _waitingForCountIn) 
                        ? Colors.white 
                        : null,
                  ),
                  child: Text(
                    _waitingForCountIn 
                        ? 'CANCEL' 
                        : (_isRecording ? 'STOP' : 'RECORD')
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _waitingForCountIn
                      ? 'Get ready... Count-in starting!'
                      : (_isRecording
                          ? 'Recording... ${_seconds}s / ${_maxSeconds}s max'
                          : 'You can record up to ${_maxSeconds} seconds'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Count-in indicator (simple text to avoid widget rebuild issues)
            if (_recordingPhase != RecordingPhase.idle) ...[
              const SizedBox(height: 16),
              Center(
                child: Card(
                  color: _recordingPhase == RecordingPhase.countIn 
                      ? Colors.amber.shade100 
                      : Colors.red.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _recordingPhase == RecordingPhase.countIn
                              ? '🎵 Count-in: $_currentBeat/$_totalBeats'
                              : '🔴 Recording!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _recordingPhase == RecordingPhase.countIn
                                ? Colors.amber.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                        if (_recordingPhase == RecordingPhase.countIn) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Recording will start after count-in',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
            
            if (_isRecording && _recordingPhase == RecordingPhase.recording) ...[
              LinearProgressIndicator(value: _seconds / _maxSeconds),
              const SizedBox(height: 16),
              // Animated musical note during recording
              Center(
                child: AnimatedBuilder(
                  animation: _noteAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _noteAnimation.value),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.music_note,
                          size: 40,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Analysis actions  
            Row(
              children: [
                ElevatedButton(
                  onPressed: (_path != null && !_isAnalyzing)
                      ? () async {
                          if (_path == null) return;
                          setState(() {
                            _isAnalyzing = true;
                            _detectedKey = null;
                            _suggestions = const [];
                          });
                          try {
                            print('=== CHORD DETECTION DEBUG START ===');
                            final fileBytes = await File(_path!).readAsBytes();
                            print('File size: ${fileBytes.length} bytes');
                            
                            final wav = WavDecoder.decode(fileBytes);
                            if (wav == null) {
                              print('ERROR: WAV decoding failed - falling back to mock data');
                              print('This means chord detection will NOT work with real audio!');
                              final result = await AnalysisService.analyzeRecording(_path!);
                              if (!mounted) return;
                              setState(() {
                                _detectedKey = result.detectedKey;
                                _suggestions = result.suggestions;
                              });
                            } else {
                              print('✓ WAV decoded successfully: ${wav.samples.length} samples at ${wav.sampleRate}Hz');
                              final detector = const PitchDetector();
                              print('→ Running pitch detection...');
                              final points = detector.analyze(wav.samples, wav.sampleRate);
                              print('→ Found ${points.length} pitch points');
                              if (points.isNotEmpty) {
                                print('  First few pitches: ${points.take(5).map((p) => '${p.note}@${p.frequencyHz.toStringAsFixed(1)}Hz').join(', ')}');
                              }
                              
                              final discrete = PitchToNotes.consolidate(points);
                              print('→ Consolidated to ${discrete.length} discrete notes');
                              if (discrete.isNotEmpty) {
                                print('  Notes: ${discrete.map((d) => d.note).join(', ')}');
                              }
                              final onlyNames = discrete.map((d) => d.note).toList();
                              print('→ Running key detection on notes: $onlyNames');
                              final keyRes = KeyDetector.detect(onlyNames);
                              final keyLabel = keyRes.key;
                              final isMinor = keyRes.isMinor;
                              print('→ Detected key: $keyLabel ${isMinor ? 'minor' : 'major'} (confidence: ${keyRes.score.toStringAsFixed(3)})');
                              final ceNotes = discrete.map((d) => CE.DetectedNote(
                                note: d.note,
                                startTime: d.startMs,
                                duration: d.durationMs,
                              )).toList();
                              print('→ Running chord suggestion engine...');
                              final engine = const CE.ChordSuggestionEngine();
                              final progs = engine.suggest(ceNotes, keyLabel, isMinor);
                              print('→ Generated ${progs.length} chord progressions');
                              if (progs.isNotEmpty) {
                                print('  Best progression: ${progs.first.name} with ${progs.first.chords.length} chords');
                                print('  Chords: ${progs.first.chords.map((c) => c.symbol).join(' - ')}');
                              }
                              if (!mounted) return;
                              final mappedSuggestions = progs.map((p) => ChordProgressionSuggestion(
                                name: p.name,
                                key: "${p.key} ${p.scale == 'NATURAL_MINOR' ? 'minor' : 'major'}",
                                chords: p.chords.map((c) => DetectedChord(symbol: c.symbol, notes: _voiceChord(c.notes))).toList(),
                              )).toList();
                              
                              setState(() {
                                _detectedKey = "${keyLabel} ${isMinor ? 'minor' : 'major'}";
                                _suggestions = mappedSuggestions;
                                // Auto-select first chord if available
                                _selectedChord = mappedSuggestions.isNotEmpty && mappedSuggestions.first.chords.isNotEmpty 
                                    ? mappedSuggestions.first.chords.first 
                                    : null;
                              });
                              print('✓ Analysis complete: ${mappedSuggestions.length} suggestions, key=$_detectedKey');
                              print('=== CHORD DETECTION DEBUG END ===');
                            }
                          } catch (e) {
                            print('ERROR during analysis: $e');
                            print('=== CHORD DETECTION DEBUG END (ERROR) ===');
                            if (!mounted) return;
                          } finally {
                            if (mounted) setState(() => _isAnalyzing = false);
                          }
                        }
                      : null,
                  child: const Text('Analyze Recording'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _detectedKey = null;
                      _suggestions = const [];
                      _selectedChord = null;
                    });
                  },
                  child: const Text('Clear Results'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_path != null) ...[
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      if (_path == null) return;
                      try {
                        await _player.stop();
                        await _player.setVolume(1.0);
                        if (Platform.isAndroid || Platform.isIOS) {
                          await _player.setFilePath(_path!);
                        } else {
                          await _player.setUrl(Uri.file(_path!).toString());
                        }
                        await _player.play();
                      } catch (_) {}
                    },
                    child: const Text('Play Recording'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_lastRmsDb != null)
                Text('Recording level: ${_lastRmsDb!.toStringAsFixed(1)} dBFS', style: const TextStyle(fontSize: 12)),
              if (_playbackDuration != null && _playbackDuration!.inMilliseconds > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_playbackPosition.inMilliseconds.clamp(0, _playbackDuration!.inMilliseconds)) / _playbackDuration!.inMilliseconds,
                ),
                const SizedBox(height: 8),
                Text('${_formatTime(_playbackPosition)} / ${_formatTime(_playbackDuration!)}${_isPlayingBack ? '  (playing)' : ''}', style: const TextStyle(fontSize: 12)),
              ],
            ],
            // Results section
            if (_detectedKey != null || _suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (_detectedKey != null)
                Text('Detected key: $_detectedKey', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_suggestions.isNotEmpty) ...[
                const Text('Recommended Chord Progression:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final prog in _suggestions) ...[
                  Text('${prog.name} in ${prog.key}', style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final chord in prog.chords)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedChord = chord;
                            });
                            ChordPlayer.playChord(chord.notes);
                          },
                          style: _selectedChord?.symbol == chord.symbol
                              ? ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                )
                              : null,
                          child: Text(chord.symbol),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ] else if (_detectedKey != null) ...[
                const Text('No chord progression suggestions found for this recording. Try recording a melody with clearer notes.', 
                  style: TextStyle(color: Colors.orange, fontSize: 14)),
                const SizedBox(height: 8),
              ],
            ],
            // Interactive Piano Keyboard - only show after chord progression analysis
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 24),
              PianoKeyboard(
                selectedChord: _selectedChord,
                showChordNotes: true,
              ),
            ],
            ],
          ),
        ),
        // Loading overlay during analysis
        if (_isAnalyzing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Analyzing Melody...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Detecting pitch, key, and chord progressions',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}