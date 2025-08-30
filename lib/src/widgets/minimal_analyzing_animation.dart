import 'package:flutter/material.dart';
import '../theme/minimal_design_system.dart';

/// Ultra-minimal analyzing animation with clean pulsing dots
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

  @override
  void initState() {
    super.initState();
    
    // Simple pulse animation for dots
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Text dots animation - counts 1, 2, 3, 1, 2, 3...
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _dotsAnimation = IntTween(begin: 1, end: 3).animate(CurvedAnimation(
      parent: _dotsController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _pulseController.repeat(reverse: true);
    _dotsController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MinimalDesign.secondary,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Three clean pulsing dots
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPulsingDot(0),
                    MinimalDesign.horizontalSpace(MinimalDesign.space2),
                    _buildPulsingDot(1),
                    MinimalDesign.horizontalSpace(MinimalDesign.space2),
                    _buildPulsingDot(2),
                  ],
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
  
  Widget _buildPulsingDot(int index) {
    // Stagger the animation timing for each dot
    final delayedAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Interval(
        index * 0.2, // Stagger start time
        1.0,
        curve: Curves.easeInOut,
      ),
    ));
    
    return AnimatedBuilder(
      animation: delayedAnimation,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MinimalDesign.primary.withOpacity(delayedAnimation.value),
          ),
        );
      },
    );
  }
}
