import 'package:flutter/material.dart';
import '../sound/metronome_player.dart';

class MetronomeControls extends StatefulWidget {
  final Function(bool enabled)? onEnabledChanged;
  final Function(int bpm)? onBpmChanged;
  final Function(TimeSignature timeSignature)? onTimeSignatureChanged;
  final Function(bool continueMetronome)? onContinueMetronomeChanged;
  final Function(double volume)? onVolumeChanged;
  
  const MetronomeControls({
    super.key,
    this.onEnabledChanged,
    this.onBpmChanged,
    this.onTimeSignatureChanged,
    this.onContinueMetronomeChanged,
    this.onVolumeChanged,
  });

  @override
  State<MetronomeControls> createState() => _MetronomeControlsState();
}

class _MetronomeControlsState extends State<MetronomeControls> {
  late bool _enabled;
  late int _bpm;
  late TimeSignature _timeSignature;
  late bool _continueMetronome;
  late double _volume;
  final TextEditingController _bpmController = TextEditingController();
  bool _showAdvancedSettings = false;

  @override
  void initState() {
    super.initState();
    _enabled = MetronomePlayer.enabled;
    _bpm = MetronomePlayer.bpm;
    _timeSignature = MetronomePlayer.timeSignature;
    _continueMetronome = MetronomePlayer.continueMetronomeDuringRecording;
    _volume = MetronomePlayer.volume;
    _bpmController.text = _bpm.toString();
  }

  @override
  void dispose() {
    _bpmController.dispose();
    super.dispose();
  }

  void _updateEnabled(bool enabled) {
    setState(() => _enabled = enabled);
    MetronomePlayer.setEnabled(enabled);
    widget.onEnabledChanged?.call(enabled);
  }

  void _updateBpm(int bpm) {
    final clampedBpm = bpm.clamp(60, 200);
    setState(() => _bpm = clampedBpm);
    MetronomePlayer.setBpm(clampedBpm);
    _bpmController.text = clampedBpm.toString();
    widget.onBpmChanged?.call(clampedBpm);
  }

  void _updateTimeSignature(TimeSignature timeSignature) {
    setState(() => _timeSignature = timeSignature);
    MetronomePlayer.setTimeSignature(timeSignature);
    widget.onTimeSignatureChanged?.call(timeSignature);
  }

  void _updateContinueMetronome(bool continueMetronome) {
    setState(() => _continueMetronome = continueMetronome);
    MetronomePlayer.setContinueMetronomeDuringRecording(continueMetronome);
    widget.onContinueMetronomeChanged?.call(continueMetronome);
  }

  void _updateVolume(double volume) {
    setState(() => _volume = volume);
    MetronomePlayer.setVolume(volume);
    widget.onVolumeChanged?.call(volume);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main metronome toggle
            Row(
              children: [
                Switch(
                  value: _enabled,
                  onChanged: _updateEnabled,
                  activeColor: Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Use Metronome with Count-In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _enabled ? null : Colors.grey,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(_showAdvancedSettings ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _showAdvancedSettings = !_showAdvancedSettings),
                  tooltip: 'Show/Hide Advanced Settings',
                ),
              ],
            ),
            
            if (_enabled) ...[
              const SizedBox(height: 16),
              
              // BPM Control
              Row(
                children: [
                  const Text('BPM:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 12),
                  
                  // BPM decrease button
                  IconButton(
                    onPressed: () => _updateBpm(_bpm - 5),
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Decrease BPM by 5',
                  ),
                  
                  // BPM text field
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _bpmController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        isDense: true,
                      ),
                      onSubmitted: (value) {
                        final bpm = int.tryParse(value);
                        if (bpm != null) _updateBpm(bpm);
                      },
                    ),
                  ),
                  
                  // BPM increase button
                  IconButton(
                    onPressed: () => _updateBpm(_bpm + 5),
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Increase BPM by 5',
                  ),
                  
                  const Spacer(),
                  
                  // Time Signature Dropdown
                  const Text('Time:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButton<TimeSignature>(
                      value: _timeSignature,
                      underline: const SizedBox(),
                      items: TimeSignature.common.map((ts) => DropdownMenuItem(
                        value: ts,
                        child: Text(
                          ts.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      )).toList(),
                      onChanged: (ts) {
                        if (ts != null) _updateTimeSignature(ts);
                      },
                    ),
                  ),
                ],
              ),
              
              // BPM Slider for fine control
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('60', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Expanded(
                    child: Slider(
                      value: _bpm.toDouble(),
                      min: 60,
                      max: 200,
                      divisions: 140,
                      onChanged: (value) => _updateBpm(value.round()),
                    ),
                  ),
                  const Text('200', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              
              if (_showAdvancedSettings) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                // Continue metronome during recording toggle
                Row(
                  children: [
                    Checkbox(
                      value: _continueMetronome,
                      onChanged: (value) => _updateContinueMetronome(value ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        'Continue metronome during recording',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Volume control
                Row(
                  children: [
                    const Icon(Icons.volume_down, size: 20),
                    Expanded(
                      child: Slider(
                        value: _volume,
                        min: 0.1,
                        max: 1.0,
                        onChanged: _updateVolume,
                      ),
                    ),
                    const Icon(Icons.volume_up, size: 20),
                    const SizedBox(width: 8),
                    Text('${(_volume * 100).round()}%', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Information text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'When you press Record, the metronome will count-in one full measure (${_timeSignature.numerator} beats) before recording starts.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}