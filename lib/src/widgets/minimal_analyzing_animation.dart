import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/minimal_design_system.dart';

/// Ultra-minimal analyzing animation with clean audio wave visualization
class MinimalAnalyzingAnimation extends StatefulWidget {
  const MinimalAnalyzingAnimation({super.key});

  @override
  State<MinimalAnalyzingAnimation> createState() => _MinimalAnalyzingAnimationState();
}

class _MinimalAnalyzingAnimationState extends State<MinimalAnalyzingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _dotsController;
  late Animation<int> _dotsAnimation;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _initializeAnimations();
  }
  
  void _initializeAnimations() {
    if (_isDisposed) return;
    
    // Balanced wave animation - peaceful but not too slow
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 3000), // Slightly faster than 4000ms
      vsync: this,
    );
    
    // Text dots animation - counts 1, 2, 3, 1, 2, 3...
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 2000), // Slightly faster text animation
      vsync: this,
    );
    _dotsAnimation = IntTween(begin: 1, end: 3).animate(CurvedAnimation(
      parent: _dotsController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations with a small delay to ensure proper initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        _startAnimations();
      }
    });
  }
  
  void _startAnimations() {
    if (_isDisposed || !mounted) return;
    
    try {
      // Stop any existing animations first
      if (_pulseController.isAnimating) _pulseController.stop();
      if (_dotsController.isAnimating) _dotsController.stop();
      
      // Reset to ensure clean state
      _pulseController.reset();
      _dotsController.reset();
      
      // Start animations
      _pulseController.repeat(reverse: true);
      _dotsController.repeat();
    } catch (e) {
      // Handle any animation errors gracefully
      print('Animation error: $e');
    }
  }
  
  @override
  void didUpdateWidget(MinimalAnalyzingAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Double check animations are running
    if (!_isDisposed && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted && (!_pulseController.isAnimating || !_dotsController.isAnimating)) {
          _startAnimations();
        }
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      if (_pulseController.isAnimating) _pulseController.stop();
      if (_dotsController.isAnimating) _dotsController.stop();
      _pulseController.dispose();
      _dotsController.dispose();
    } catch (e) {
      print('Dispose error: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MinimalDesign.secondary,
      width: double.infinity,
      height: MediaQuery.of(context).size.height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Elegant flowing wave animation
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return SizedBox(
                  width: 200,
                  height: 100,
                  child: CustomPaint(
                    painter: WavePainter(_pulseController.value),
                    size: const Size(200, 100),
                  ),
                );
              },
            ),
            
            MinimalDesign.verticalSpace(MinimalDesign.space4),
            
            // Animated text with dots
            AnimatedBuilder(
              animation: _dotsAnimation,
              builder: (context, child) {
                return Text(
                  'Analyzing melody${'.' * _dotsAnimation.value}',
                  style: MinimalDesign.body.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: MinimalDesign.primary,
                  ),
                );
              },
            ),
            
            MinimalDesign.verticalSpace(MinimalDesign.space3),
            
            // Simple progress indicator
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: MinimalDesign.lightGray,
                valueColor: AlwaysStoppedAnimation<Color>(MinimalDesign.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for audio wave animation
class WavePainter extends CustomPainter {
  final double animationValue;
  
  WavePainter(this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    
    final paint = Paint()
      ..color = MinimalDesign.primary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final centerY = size.height / 2;
    final amplitude = size.height * 0.3; // Wave height
    
    // Create smooth flowing wave
    final path = Path();
    final waveLength = size.width / 2; // Two complete waves across width
    final frequency = 2 * math.pi / waveLength;
    
    // Calculate points for smooth wave
    final points = <Offset>[];
    final stepSize = size.width / 80; // 80 points for ultra-smooth curve
    
    for (double x = 0; x <= size.width; x += stepSize) {
      final normalizedX = x / size.width; // 0 to 1
      
      // Create balanced infinite-loop pattern
      // Primary wave with smooth pulsing
      final primaryWave = math.sin(frequency * x) * math.cos(animationValue * 1.6 * math.pi);
      
      // Gentle harmonic for subtle complexity
      final harmonicWave = math.sin(frequency * x * 2) * math.sin(animationValue * 2.2 * math.pi) * 0.25;
      
      // Balanced breathing effect - gentle but noticeable
      final breathingPhase = math.sin(animationValue * 1.0 * math.pi) * 0.3 + 0.85;
      
      final y = centerY + (primaryWave + harmonicWave) * amplitude * breathingPhase;
      points.add(Offset(x, y));
    }
    
    if (points.isEmpty) return;
    
    // Create smooth path using the points
    path.moveTo(points.first.dx, points.first.dy);
    
    // Use quadratic bezier curves for ultra-smooth waves
    for (int i = 1; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final controlPoint = Offset(
        (current.dx + next.dx) / 2,
        current.dy,
      );
      path.quadraticBezierTo(current.dx, current.dy, controlPoint.dx, controlPoint.dy);
    }
    
    // Draw the final segment
    if (points.length > 1) {
      path.lineTo(points.last.dx, points.last.dy);
    }
    
    // Draw the main wave
    canvas.drawPath(path, paint);
    
    // Draw a second wave with different phase for depth
    final secondaryPath = Path();
    final secondaryPaint = Paint()
      ..color = MinimalDesign.primary.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final secondaryPoints = <Offset>[];
    for (double x = 0; x <= size.width; x += stepSize) {
      final normalizedX = x / size.width; // 0 to 1
      
      // Balanced secondary wave for smooth interweaving
      // Uses cosine base with moderate phase changes
      final secondaryWave = math.cos(frequency * x * 0.8) * math.sin(animationValue * 1.8 * math.pi + math.pi);
      
      // Subtle tertiary harmonic for gentle complexity
      final tertiaryWave = math.cos(frequency * x * 1.5) * math.cos(animationValue * 1.3 * math.pi) * 0.3;
      
      // Balanced inverse breathing for smooth counter-movement
      final inverseBreathing = math.cos(animationValue * 1.1 * math.pi + math.pi) * 0.25 + 0.7;
      
      final y = centerY + (secondaryWave + tertiaryWave) * amplitude * inverseBreathing;
      secondaryPoints.add(Offset(x, y));
    }
    
    if (secondaryPoints.isNotEmpty) {
      secondaryPath.moveTo(secondaryPoints.first.dx, secondaryPoints.first.dy);
      for (int i = 1; i < secondaryPoints.length - 1; i++) {
        final current = secondaryPoints[i];
        final next = secondaryPoints[i + 1];
        final controlPoint = Offset(
          (current.dx + next.dx) / 2,
          current.dy,
        );
        secondaryPath.quadraticBezierTo(current.dx, current.dy, controlPoint.dx, controlPoint.dy);
      }
      if (secondaryPoints.length > 1) {
        secondaryPath.lineTo(secondaryPoints.last.dx, secondaryPoints.last.dy);
      }
      canvas.drawPath(secondaryPath, secondaryPaint);
    }
  }
  
  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}
