import 'package:flutter/material.dart';
import '../theme/minimal_design_system.dart';
import '../sound/metronome_player.dart';

/// Minimal Recording Interface - True minimalism through restraint
/// 
/// Features:
/// - Clean, simple record button with elegant animations
/// - Essential information only
/// - Subtle visual feedback on interactions
/// - Generous white space
/// - Clear functional hierarchy
class MinimalRecordingInterface extends StatefulWidget {
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
  State<MinimalRecordingInterface> createState() => _MinimalRecordingInterfaceState();
}

class _MinimalRecordingInterfaceState extends State<MinimalRecordingInterface> 
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Press animation - quick scale down/up on tap
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeInOut,
    ));
    
    // Pulse animation - subtle pulse while recording
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(MinimalRecordingInterface oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Start pulse animation when recording starts
    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Press animation
    _pressController.forward().then((_) {
      _pressController.reverse();
    });
    
    // Trigger the actual action
    final isActive = widget.isRecording || widget.isWaitingForCountIn;
    if (isActive) {
      widget.onStop?.call();
    } else {
      widget.onRecord?.call();
    }
  }

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
          
          // Record button - clean and animated
          _buildRecordButton(),
          
          MinimalDesign.verticalSpace(MinimalDesign.space4),
          
          // Progress indicator (only when recording)
          if (widget.isRecording) _buildProgress(),
          
          // Count-in indicator (only when waiting)
          if (widget.isWaitingForCountIn) _buildCountIn(),
          
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
    
    if (widget.isWaitingForCountIn) {
      status = 'Count-in starting';
    } else if (widget.isRecording) {
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
    final isActive = widget.isRecording || widget.isWaitingForCountIn;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _pulseAnimation]),
      builder: (context, child) {
        // Combine both animations - press scale + recording pulse
        double scale = _scaleAnimation.value;
        if (widget.isRecording) {
          scale *= _pulseAnimation.value;
        }
        
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: _handleTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? MinimalDesign.red : MinimalDesign.primary,
                boxShadow: widget.isRecording 
                    ? [
                        BoxShadow(
                          color: MinimalDesign.red.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  key: ValueKey(isActive),
                  isActive ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
                  color: MinimalDesign.secondary,
                  size: 32,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgress() {
    final progress = widget.seconds / widget.maxSeconds;
    
    return Column(
      children: [
        Container(
          width: 120,
          height: 2,
          decoration: BoxDecoration(
            color: MinimalDesign.lightGray,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 120 * progress,
              height: 2,
              color: MinimalDesign.primary,
            ),
          ),
        ),
        MinimalDesign.verticalSpace(MinimalDesign.space2),
        Text(
          '${widget.seconds}s / ${widget.maxSeconds}s',
          style: MinimalDesign.small,
        ),
      ],
    );
  }

  Widget _buildCountIn() {
    return Column(
      children: [
        Text(
          '${widget.currentBeat} / ${widget.totalBeats}',
          style: MinimalDesign.body.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        MinimalDesign.verticalSpace(MinimalDesign.space2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.totalBeats,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < widget.currentBeat 
                    ? MinimalDesign.primary 
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
          onTap: () => widget.onMetronomeToggle?.call(!widget.useMetronome),
          child: Container(
            width: 32,
            height: 18,
            decoration: BoxDecoration(
              color: widget.useMetronome ? MinimalDesign.primary : MinimalDesign.lightGray,
              borderRadius: BorderRadius.circular(9),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: widget.useMetronome ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: MinimalDesign.secondary,
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