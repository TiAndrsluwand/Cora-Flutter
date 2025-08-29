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
import '../sound/metronome_player.dart';
import '../theme/minimal_design_system.dart';
import '../utils/debug_logger.dart';

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});
  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
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

  // Recording diagnostics
  double? _lastRmsDb;
  
  // Piano keyboard state
  DetectedChord? _selectedChord;
  
  // Metronome state
  bool _useMetronome = false;
  RecordingPhase _recordingPhase = RecordingPhase.idle;
  int _currentBeat = 0;
  int _totalBeats = 4;
  bool _waitingForCountIn = false;
  
  // Continuous metronome state
  bool _isPreviewingMetronome = false;

  @override
  void initState() {
    super.initState();
    _initAudioSession();
    _loadSf();
    _initMetronome();
  }

  Future<void> _loadSf() async {
    await ChordPlayer.ensureLoaded(context);
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
      _path = '${tempDir.path}/temp.wav';

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
        await _player.stop();
        await ChordPlayer.stopAnyPlayback();
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        DebugLogger.debug('Warning: Error stopping audio resources: $e');
      }

      await _configureForRecording();
      await Future.delayed(const Duration(milliseconds: 150));
      
      await _record.start(const RecordConfig(encoder: AudioEncoder.wav), path: _path!);
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
    await MetronomePlayer.stopMetronome();
    
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
    
    await _configureForPlayback();
    
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

  Future<void> _configureForRecording() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.measurement,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.audibilityEnforced,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      await session.setActive(true);
    } catch (e) {
      DebugLogger.debug('Audio session config error: $e');
    }
  }

  Future<void> _configureForPlayback() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
    } catch (e) {
      DebugLogger.debug('Playback session config error: $e');
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

    setState(() => _isAnalyzing = true);

    try {
      final result = await AnalysisService.analyzeRecording(_path!);
      
      if (mounted) {
        setState(() {
          _detectedKey = result.detectedKey;
          _suggestions = result.suggestions;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        _showErrorSnackBar('Analysis failed: $e');
      }
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

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    ChordPlayer.dispose();
    MetronomePlayer.dispose();
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
                  child: const Text('Play'),
                ),
              ),
              MinimalDesign.horizontalSpace(MinimalDesign.space3),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_path != null && !_isAnalyzing) ? _analyzeRecording : null,
                  child: const Text('Analyze'),
                ),
              ),
            ],
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: MinimalDesign.theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cora'),
        ),
        
        body: _isAnalyzing 
            ? Container(
                color: MinimalDesign.white.withOpacity(0.9),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: MinimalDesign.black,
                        strokeWidth: 2,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Analyzing...',
                        style: MinimalDesign.body,
                      ),
                    ],
                  ),
                ),
              )
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
                    
                    if (_useMetronome && !(_isRecording || _waitingForCountIn))
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
                    
                    if (_path != null && _suggestions.isEmpty && !_isAnalyzing)
                      _buildMinimalPlaybackControls(),
                    
                    if (_suggestions.isNotEmpty && !_isAnalyzing) ...[
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
}