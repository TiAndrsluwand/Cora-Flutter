import 'package:flutter/material.dart';
import '../sound/metronome_player.dart';

class CountInIndicator extends StatefulWidget {
  final int currentBeat;
  final int totalBeats;
  final RecordingPhase phase;
  final String? timeSignatureDisplay;

  const CountInIndicator({
    super.key,
    required this.currentBeat,
    required this.totalBeats,
    required this.phase,
    this.timeSignatureDisplay,
  });

  @override
  State<CountInIndicator> createState() => _CountInIndicatorState();
}

class _CountInIndicatorState extends State<CountInIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();

    // Pulse animation for beat indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    ));

    // Scale animation for phase transitions
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _scaleController.forward();
  }

  @override
  void didUpdateWidget(CountInIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger pulse animation when beat changes (with safety checks)
    if (oldWidget.currentBeat != widget.currentBeat &&
        widget.currentBeat > 0 &&
        mounted &&
        !_pulseController.isAnimating) {
      try {
        _pulseController.forward().then((_) {
          if (mounted && !_isDisposed) {
            _pulseController.reverse();
          }
        });
      } catch (e) {
        print('CountInIndicator: Error in pulse animation: $e');
      }
    }

    // Trigger scale animation when phase changes (with safety checks)
    if (oldWidget.phase != widget.phase &&
        mounted &&
        !_scaleController.isAnimating) {
      try {
        _scaleController.reset();
        _scaleController.forward();
      } catch (e) {
        print('CountInIndicator: Error in scale animation: $e');
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Color _getPhaseColor() {
    switch (widget.phase) {
      case RecordingPhase.countIn:
        return Colors.amber;
      case RecordingPhase.recording:
        return Colors.red;
      case RecordingPhase.idle:
      default:
        return Colors.grey;
    }
  }

  String _getPhaseText() {
    switch (widget.phase) {
      case RecordingPhase.countIn:
        return 'Get Ready! Count-in...';
      case RecordingPhase.recording:
        return '🔴 Recording!';
      case RecordingPhase.idle:
      default:
        return '';
    }
  }

  List<Widget> _buildBeatIndicators() {
    final indicators = <Widget>[];

    for (int i = 1; i <= widget.totalBeats; i++) {
      final isActive = i <= widget.currentBeat;
      final isCurrentBeat = i == widget.currentBeat;

      Widget indicator = Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? _getPhaseColor() : Colors.grey.shade300,
          border: Border.all(
            color: i == 1
                ? Colors.black // Downbeat indicator
                : Colors.grey.shade400,
            width: i == 1 ? 3 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _getPhaseColor().withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            i.toString(),
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      );

      // Add pulse animation to current beat with proper safety checks
      if (isCurrentBeat &&
          widget.phase != RecordingPhase.idle &&
          !_isDisposed) {
        indicator = AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            if (_isDisposed || !mounted) {
              return indicator;
            }
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: indicator,
            );
          },
        );
      }

      indicators.add(indicator);
    }

    return indicators;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phase == RecordingPhase.idle) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Card(
            color: _getPhaseColor().withOpacity(0.1),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Phase text with icon
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.phase == RecordingPhase.countIn)
                        Icon(
                          Icons.timelapse,
                          color: _getPhaseColor(),
                          size: 28,
                        )
                      else if (widget.phase == RecordingPhase.recording)
                        Icon(
                          Icons.fiber_manual_record,
                          color: _getPhaseColor(),
                          size: 28,
                        ),
                      if (widget.phase != RecordingPhase.idle)
                        const SizedBox(width: 8),
                      Text(
                        _getPhaseText(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getPhaseColor(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Time signature display
                  if (widget.timeSignatureDisplay != null) ...[
                    Text(
                      'Time: ${widget.timeSignatureDisplay}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Beat indicators
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildBeatIndicators()
                        .expand((widget) => [widget, const SizedBox(width: 8)])
                        .toList()
                      ..removeLast(), // Remove last spacing
                  ),

                  const SizedBox(height: 12),

                  // Beat counter text
                  Text(
                    widget.phase == RecordingPhase.countIn
                        ? 'Count-in: ${widget.currentBeat}/${widget.totalBeats}'
                        : 'Beat: ${widget.currentBeat}/${widget.totalBeats}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _getPhaseColor(),
                    ),
                  ),

                  // Additional info for count-in
                  if (widget.phase == RecordingPhase.countIn) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Recording will start after count-in',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  // Additional info for recording
                  if (widget.phase == RecordingPhase.recording) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Following metronome timing',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
