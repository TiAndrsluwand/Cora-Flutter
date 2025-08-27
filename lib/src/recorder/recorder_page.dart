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
import '../audio/pitch_detector.dart';
import '../audio/pitch_to_notes.dart';
import '../analysis/key_detection.dart';
import '../analysis/chord_engine.dart' as CE;
import '../analysis/chord_progression_suggestion.dart';
import '../analysis/detected_chord.dart';
import '../widgets/piano_keyboard.dart';

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

  @override
  void initState() {
    super.initState();
    _initAudioSession();
    _loadSf();
    _bindPlayerStreams();
    
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

  Future<void> _toggle() async {
    if (_isRecording) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    try {
      // Pause any ongoing chord playback to avoid audio mix issues
      try { await _player.stop(); } catch (_) {}

      final mic = await Permission.microphone.request();
      if (mic != PermissionStatus.granted) {
        print('Microphone permission not granted');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      _path = '${tempDir.path}/temp.wav';
      print('Recording to: $_path');

      _seconds = 0;
      setState(() => _isRecording = true);
      
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

      // Configure audio session for recording
      await _configureForRecording();
      await _record.start(const RecordConfig(encoder: AudioEncoder.wav), path: _path!);
      print('Recording started');
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stop() async {
    final filePath = await _record.stop();
    _timer?.cancel();
    
    // Stop note animation
    _noteAnimationController.stop();
    _noteAnimationController.reset();
    
    setState(() {
      _isRecording = false;
      _path = filePath;
      _seconds = 0;
    });
    // Switch session to playback after recording ends
    await _configureForPlayback();
    // Compute simple RMS level to detect silence
    try {
      if (_path != null) {
        final bytes = await File(_path!).readAsBytes();
        final wav = WavDecoder.decode(bytes);
        if (wav != null && wav.samples.isNotEmpty) {
          double sum = 0;
          for (final s in wav.samples) { sum += s * s; }
          final rms = (sum / wav.samples.length).clamp(1e-12, 1.0);
          final db = 10 * (math.log(rms) / math.ln10);
          if (mounted) setState(() => _lastRmsDb = db);
        }
      }
    } catch (_) {}
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

  @override
  void dispose() {
    _timer?.cancel();
    _noteAnimationController.dispose();
    _player.dispose();
    ChordPlayer.dispose(); // Fire and forget for cleanup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cora Recorder')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ElevatedButton(
                  onPressed: _toggle,
                  child: Text(_isRecording ? 'STOP' : 'RECORD'),
                ),
                const SizedBox(width: 12),
                Text(
                  _isRecording
                      ? 'Recording... ${_seconds}s / ${_maxSeconds}s max'
                      : 'You can record up to ${_maxSeconds} seconds',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isRecording) ...[
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
                            final fileBytes = await File(_path!).readAsBytes();
                            final wav = WavDecoder.decode(fileBytes);
                            if (wav == null) {
                              final result = await AnalysisService.analyzeRecording(_path!);
                              if (!mounted) return;
                              setState(() {
                                _detectedKey = result.detectedKey;
                                _suggestions = result.suggestions;
                              });
                            } else {
                              final detector = const PitchDetector();
                              final points = detector.analyze(wav.samples, wav.sampleRate);
                              final discrete = PitchToNotes.consolidate(points);
                              final onlyNames = discrete.map((d) => d.note).toList();
                              final keyRes = KeyDetector.detect(onlyNames);
                              final keyLabel = keyRes.key;
                              final isMinor = keyRes.isMinor;
                              final ceNotes = discrete.map((d) => CE.DetectedNote(
                                note: d.note,
                                startTime: d.startMs,
                                duration: d.durationMs,
                              )).toList();
                              final engine = const CE.ChordSuggestionEngine();
                              final progs = engine.suggest(ceNotes, keyLabel, isMinor);
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
                            }
                          } catch (e) {
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
            const SizedBox(height: 24),
            // Interactive Piano Keyboard
            PianoKeyboard(
              selectedChord: _selectedChord,
              showChordNotes: true,
            ),
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