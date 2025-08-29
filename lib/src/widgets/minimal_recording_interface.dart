import 'package:flutter/material.dart';
import '../theme/minimal_design_system.dart';
import '../sound/metronome_player.dart';

/// Minimal Recording Interface - True minimalism through restraint
/// 
/// Features:
/// - Clean, simple record button
/// - Essential information only
/// - No decorative elements or effects
/// - Generous white space
/// - Clear functional hierarchy
class MinimalRecordingInterface extends StatelessWidget {
  final bool isRecording;
  final bool isWaitingForCountIn;
  final int seconds;
  final int maxSeconds;
  final VoidCallback? onRecord;
  final VoidCallback? onStop;
  final RecordingPhase recordingPhase;
  final int currentBeat;
  final int totalBeats;
  final bool useMetronome;
  final Function(bool)? onMetronomeToggle;

  const MinimalRecordingInterface({
    super.key,
    required this.isRecording,
    required this.isWaitingForCountIn,
    required this.seconds,
    required this.maxSeconds,
    this.onRecord,
    this.onStop,
    required this.recordingPhase,
    required this.currentBeat,
    required this.totalBeats,
    required this.useMetronome,
    this.onMetronomeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MinimalDesign.screenPadding,
      child: Column(
        children: [
          MinimalDesign.verticalSpace(MinimalDesign.space8),
          
          // Status text - minimal and clear
          _buildStatus(),
          
          MinimalDesign.verticalSpace(MinimalDesign.space6),
          
          // Record button - clean and simple
          _buildRecordButton(),
          
          MinimalDesign.verticalSpace(MinimalDesign.space4),
          
          // Progress indicator (only when recording)
          if (isRecording) _buildProgress(),
          
          // Count-in indicator (only when waiting)
          if (isWaitingForCountIn) _buildCountIn(),
          
          MinimalDesign.verticalSpace(MinimalDesign.space6),
          
          // Metronome toggle - subtle and functional
          _buildMetronomeToggle(),
          
          MinimalDesign.verticalSpace(MinimalDesign.space8),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    String status;
    TextStyle style = MinimalDesign.body;
    
    if (isWaitingForCountIn) {
      status = 'Count-in starting';
    } else if (isRecording) {
      status = 'Recording';
    } else {
      status = 'Ready';
    }
    
    return Text(
      status,
      style: style,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildRecordButton() {
    final isActive = isRecording || isWaitingForCountIn;
    
    return GestureDetector(
      onTap: isActive ? onStop : onRecord,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? MinimalDesign.red : MinimalDesign.black,
        ),
        child: Icon(
          isActive ? Icons.stop : Icons.fiber_manual_record,
          color: MinimalDesign.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final progress = seconds / maxSeconds;
    
    return Column(
      children: [
        Container(
          width: 120,
          height: 2,
          decoration: const BoxDecoration(
            color: MinimalDesign.lightGray,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 120 * progress,
              height: 2,
              color: MinimalDesign.black,
            ),
          ),
        ),
        MinimalDesign.verticalSpace(MinimalDesign.space2),
        Text(
          '${seconds}s / ${maxSeconds}s',
          style: MinimalDesign.small,
        ),
      ],
    );
  }

  Widget _buildCountIn() {
    return Column(
      children: [
        Text(
          '$currentBeat / $totalBeats',
          style: MinimalDesign.body.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        MinimalDesign.verticalSpace(MinimalDesign.space2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            totalBeats,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < currentBeat 
                    ? MinimalDesign.black 
                    : MinimalDesign.lightGray,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetronomeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Metronome',
          style: MinimalDesign.caption,
        ),
        MinimalDesign.horizontalSpace(MinimalDesign.space2),
        GestureDetector(
          onTap: () => onMetronomeToggle?.call(!useMetronome),
          child: Container(
            width: 32,
            height: 18,
            decoration: BoxDecoration(
              color: useMetronome ? MinimalDesign.black : MinimalDesign.lightGray,
              borderRadius: BorderRadius.circular(9),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: useMetronome ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: MinimalDesign.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}