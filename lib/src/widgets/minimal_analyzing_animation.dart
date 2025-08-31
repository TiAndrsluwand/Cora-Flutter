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
    
    // Balanced wave animation - slower to reduce CPU load
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 3000), // Más lento para mejor performance
      vsync: this,
    );
    
    // Text dots animation - counts 1, 2, 3, 1, 2, 3...
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1800), // Más lento para mejor performance
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
      // Start animations without stopping first to avoid conflicts
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
      if (!_dotsController.isAnimating) {
        _dotsController.repeat();
      }
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
      ..color = MinimalDesign.accent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final centerY = size.height / 2;
    final amplitude = size.height * 0.25;
    
    // Simplified wave - much more performant
    final path = Path();
    final points = <Offset>[];
    
    // Use fewer points for better performance
    const int pointCount = 40;
    final stepSize = size.width / pointCount;
    
    for (int i = 0; i <= pointCount; i++) {
      final x = i * stepSize;
      
      // Simple sine wave with animation
      final wave1 = math.sin((x / size.width) * 4 * math.pi + animationValue * 4 * math.pi) * amplitude;
      final wave2 = math.sin((x / size.width) * 6 * math.pi + animationValue * 3 * math.pi) * amplitude * 0.5;
      
      final y = centerY + wave1 + wave2;
      points.add(Offset(x, y));
    }
    
    if (points.isEmpty) return;
    
    // Simple path without bezier curves
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    
    canvas.drawPath(path, paint);
    
    // Simple second wave
    final secondPath = Path();
    final secondPaint = Paint()
      ..color = MinimalDesign.accent.withValues(alpha: 0.4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final secondPoints = <Offset>[];
    for (int i = 0; i <= pointCount; i++) {
      final x = i * stepSize;
      
      // Offset phase for second wave
      final wave = math.cos((x / size.width) * 3 * math.pi + animationValue * 5 * math.pi) * amplitude * 0.7;
      final y = centerY + wave;
      secondPoints.add(Offset(x, y));
    }
    
    if (secondPoints.isNotEmpty) {
      secondPath.moveTo(secondPoints.first.dx, secondPoints.first.dy);
      for (int i = 1; i < secondPoints.length; i++) {
        secondPath.lineTo(secondPoints[i].dx, secondPoints[i].dy);
      }
      canvas.drawPath(secondPath, secondPaint);
    }
  }
  
  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}
