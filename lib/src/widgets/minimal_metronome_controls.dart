import 'package:flutter/material.dart';
import '../theme/minimal_design_system.dart';
import '../sound/metronome_player.dart';

/// Minimal Metronome Controls - Clean, functional interface
/// 
/// Features:
/// - Simple BPM control with direct input
/// - Basic time signature selector
/// - Clean start/stop functionality  
/// - No decorative elements or effects
/// - Straightforward layout and typography
class MinimalMetronomeControls extends StatefulWidget {
  final bool enabled;
  final int bpm;
  final TimeSignature timeSignature;
  final bool isPlaying;
  final Function(bool)? onEnabledChanged;
  final Function(int)? onBpmChanged;
  final Function(TimeSignature)? onTimeSignatureChanged;
  final VoidCallback? onStartStop;

  const MinimalMetronomeControls({
    super.key,
    required this.enabled,
    required this.bpm,
    required this.timeSignature,
    this.isPlaying = false,
    this.onEnabledChanged,
    this.onBpmChanged,
    this.onTimeSignatureChanged,
    this.onStartStop,
  });

  @override
  State<MinimalMetronomeControls> createState() =>
      _MinimalMetronomeControlsState();
}

class _MinimalMetronomeControlsState extends State<MinimalMetronomeControls> {
  late TextEditingController _bpmController;

  @override
  void initState() {
    super.initState();
    _bpmController = TextEditingController(text: widget.bpm.toString());
  }

  @override
  void didUpdateWidget(MinimalMetronomeControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bpm != widget.bpm) {
      _bpmController.text = widget.bpm.toString();
    }
  }

  @override
  void dispose() {
    _bpmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    
    return Container(
      padding: MinimalDesign.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Text(
            'Metronome',
            style: MinimalDesign.heading,
          ),
          
          MinimalDesign.verticalSpace(MinimalDesign.space3),
          
          // BPM Control
          _buildBpmControl(),
          
          MinimalDesign.verticalSpace(MinimalDesign.space3),
          
          // Time Signature
          _buildTimeSignatureControl(),
          
          MinimalDesign.verticalSpace(MinimalDesign.space4),
          
          // Continue During Recording Toggle
          _buildRecordingToggle(),
          
          MinimalDesign.verticalSpace(MinimalDesign.space4),
          
          // Start/Stop Button
          _buildPlayButton(),
        ],
      ),
    );
  }

  Widget _buildBpmControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // BPM Label and Value
        Row(
          children: [
            Text(
              'BPM',
              style: MinimalDesign.body,
            ),
            const Spacer(),
            Text(
              '${widget.bpm}',
              style: MinimalDesign.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        
        MinimalDesign.verticalSpace(MinimalDesign.space2),
        
        // BPM Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: MinimalDesign.black,
            inactiveTrackColor: MinimalDesign.lightGray,
            thumbColor: MinimalDesign.black,
            overlayColor: MinimalDesign.black.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: widget.bpm.toDouble(),
            min: 60,
            max: 200,
            divisions: 140, // 1 BPM increments
            onChanged: (value) {
              widget.onBpmChanged?.call(value.round());
              _bpmController.text = value.round().toString();
            },
          ),
        ),
        
        MinimalDesign.verticalSpace(MinimalDesign.space1),
        
        // Min/Max labels
        Row(
          children: [
            Text(
              '60',
              style: MinimalDesign.small,
            ),
            const Spacer(),
            Text(
              '200',
              style: MinimalDesign.small,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeSignatureControl() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Label
        SizedBox(
          width: 60,
          child: Text(
            'Time',
            style: MinimalDesign.body,
          ),
        ),
        
        MinimalDesign.horizontalSpace(MinimalDesign.space3),
        
        // Time Signature Options
        Expanded(
          child: Wrap(
            spacing: MinimalDesign.space2,
            children: TimeSignature.common.map((ts) {
              final isSelected = ts == widget.timeSignature;
              
              return GestureDetector(
                onTap: () => widget.onTimeSignatureChanged?.call(ts),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? MinimalDesign.black : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? MinimalDesign.black : MinimalDesign.lightGray,
                    ),
                  ),
                  child: Text(
                    ts.toString(),
                    style: MinimalDesign.body.copyWith(
                      color: isSelected ? MinimalDesign.white : MinimalDesign.black,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Continue metronome during recording',
                    style: MinimalDesign.body,
                  ),
                  MinimalDesign.verticalSpace(MinimalDesign.space1),
                  Text(
                    'Hear the beat while recording (not saved in audio)',
                    style: MinimalDesign.small.copyWith(
                      color: MinimalDesign.black.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            // Continue during recording option removed - handled internally
          ],
        ),
      ],
    );
  }

  Widget _buildPlayButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.onStartStop,
        style: MinimalDesign.primaryButton,
        child: Text(
          widget.isPlaying ? 'Stop' : 'Start',
        ),
      ),
    );
  }
}