import 'dart:math';
import 'package:flutter/material.dart';

/// A widget that displays three concentric circular progress rings
/// Perfect for showing medication adherence progress
class MedicationRings extends StatefulWidget {
  /// The progress value from 0.0 to 1.0 (e.g., 0.67 for 67%)
  final double progress;

  /// Optional colors for the three rings (inner, middle, outer)
  final Color? ring1Color;
  final Color? ring2Color;
  final Color? ring3Color;

  /// Background color for the ring tracks
  final Color? ringBackgroundColor;

  const MedicationRings({
    super.key,
    required this.progress,
    this.ring1Color,
    this.ring2Color,
    this.ring3Color,
    this.ringBackgroundColor,
  });

  @override
  State<MedicationRings> createState() => _MedicationRingsState();
}

class _MedicationRingsState extends State<MedicationRings>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;

  // 3D rotation angles for perspective effect
  final double rotateX = -128;
  final double rotateY = -8;

  @override
  void initState() {
    super.initState();
    // Animation controller for the entrance effect
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Smooth ease-in-out animation from 0 to 1
    _sizeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Start the animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Default colors (matches the reference design)
    final Color innerRingColor = widget.ring1Color ?? const Color(0xFFFF6B35); // Orange
    final Color middleRingColor = widget.ring2Color ?? const Color(0xFF8B5CF6); // Purple
    final Color outerRingColor = widget.ring3Color ?? const Color(0xFF3B82F6); // Blue
    final Color bgColor = widget.ringBackgroundColor ?? const Color(0xFFE5E7EB); // Light gray

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          // Adjust this offset to position the rings where you want them
          offset: const Offset(80, 230),
          child: Transform.scale(
            scale: 0.82,
            child: Column(
              children: [
                // Inner ring (orange/red)
                Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0011) // Perspective depth
                    ..rotateX(0.01 * rotateX)
                    ..rotateY(-0.01 * rotateY),
                  alignment: FractionalOffset.center,
                  child: CustomPaint(
                    painter: RingPainter(
                      animateValue: _sizeAnimation.value,
                      progress: widget.progress,
                      ringColor: innerRingColor,
                      backgroundColor: bgColor,
                      offset: const Offset(40, 350),
                      size: const Size(140, 140),
                      maxSweep: 3.2, // How much of the circle to fill at 100%
                    ),
                  ),
                ),

                // Middle ring (purple)
                Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0011)
                    ..rotateX(0.01 * rotateX)
                    ..rotateY(-0.01 * rotateY),
                  alignment: FractionalOffset.center,
                  child: CustomPaint(
                    painter: RingPainter(
                      animateValue: _sizeAnimation.value,
                      progress: widget.progress,
                      ringColor: middleRingColor,
                      backgroundColor: bgColor,
                      offset: const Offset(28, 338),
                      size: const Size(165, 165),
                      maxSweep: 3.8,
                    ),
                  ),
                ),

                // Outer ring (cyan/blue)
                Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0011)
                    ..rotateX(0.01 * rotateX)
                    ..rotateY(-0.01 * rotateY),
                  alignment: FractionalOffset.center,
                  child: CustomPaint(
                    painter: RingPainter(
                      animateValue: _sizeAnimation.value,
                      progress: widget.progress,
                      ringColor: outerRingColor,
                      backgroundColor: bgColor,
                      offset: const Offset(16, 326),
                      size: const Size(190, 190),
                      maxSweep: 4.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter that draws a single ring with background track and progress arc
class RingPainter extends CustomPainter {
  final double animateValue; // Animation progress (0 to 1)
  final double progress; // Actual progress value (0 to 1)
  final Color ringColor; // Color of the progress arc
  final Color backgroundColor; // Color of the background track
  final Offset offset; // Position of the ring
  final Size size; // Size of the ring
  final double maxSweep; // Maximum sweep angle in radians

  RingPainter({
    required this.animateValue,
    required this.progress,
    required this.ringColor,
    required this.backgroundColor,
    required this.offset,
    required this.size,
    required this.maxSweep,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Background track (full circle)
    var backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    canvas.drawArc(
      offset & size,
      3 * pi / 2, // Start at top (270 degrees)
      2 * pi,     // Full circle (360 degrees)
      false,
      backgroundPaint,
    );

    // Progress arc (colored based on progress)
    var progressPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round; // Rounded ends for polished look

    // Calculate sweep angle based on progress and animation
    double sweepAngle = maxSweep * progress * animateValue;

    canvas.drawArc(
      offset & size,
      5.5,        // Start angle (in radians, ~315 degrees)
      sweepAngle, // Sweep based on progress
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(RingPainter oldDelegate) {
    return oldDelegate.animateValue != animateValue ||
        oldDelegate.progress != progress;
  }
}