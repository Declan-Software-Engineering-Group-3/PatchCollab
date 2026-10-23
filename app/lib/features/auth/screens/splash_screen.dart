import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'registration_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF061112);
    const cyanColor = Color(0xFF00E5D4);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          const Positioned.fill(child: BubbleBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  Image.asset(
                    'assets/images/patchcollab_logo.png',
                    width: 290,
                    height: 290,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 65,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegistrationScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cyanColor,
                        foregroundColor: backgroundColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 65,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BubbleBackground extends StatefulWidget {
  const BubbleBackground({super.key});

  @override
  State<BubbleBackground> createState() => _BubbleBackgroundState();
}

class _BubbleBackgroundState extends State<BubbleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: BubbleBackgroundPainter(_controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class BubbleBackgroundPainter extends CustomPainter {
  BubbleBackgroundPainter(this.progress);

  final double progress;

  void drawBubble(
    Canvas canvas,
    Size size, {
    required double x,
    required double y,
    required double radius,
    double opacity = 1,
    double phase = 0,
  }) {
    final t = progress * 2 * math.pi + phase;
    final center = Offset(
      size.width * x + math.sin(t) * size.width * 0.018,
      size.height * y + math.cos(t) * size.height * 0.025,
    );
    final r = size.width * radius;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00E5D4).withValues(alpha: 0.20 * opacity),
          const Color(0xFF00BFAF).withValues(alpha: 0.07 * opacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 1.8));

    canvas.drawCircle(center, r * 1.8, glowPaint);

    final bubblePaint = Paint()
      ..shader = ui.Gradient.radial(
        center.translate(-r * 0.28, -r * 0.3),
        r * 1.7,
        [
          const Color(0xFF00E5D4).withValues(alpha: 0.28 * opacity),
          const Color(0xFF007F78).withValues(alpha: 0.14 * opacity),
          const Color(0xFF003A3A).withValues(alpha: 0.07 * opacity),
        ],
        const [0.0, 0.55, 1.0],
      );

    canvas.drawCircle(center, r, bubblePaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF00E5D4).withValues(alpha: 0.24 * opacity);

    canvas.drawCircle(center, r, rimPaint);

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF65FFF3).withValues(alpha: 0.25 * opacity);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      3.6,
      1.3,
      false,
      highlightPaint,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    drawBubble(
      canvas,
      size,
      x: -0.04,
      y: 0.04,
      radius: 0.25,
      opacity: 0.8,
      phase: 0,
    );
    drawBubble(
      canvas,
      size,
      x: 1.02,
      y: 0.36,
      radius: 0.24,
      opacity: 0.75,
      phase: 1.5,
    );
    drawBubble(
      canvas,
      size,
      x: 0.02,
      y: 0.90,
      radius: 0.24,
      opacity: 0.7,
      phase: 3,
    );
    drawBubble(
      canvas,
      size,
      x: 1.02,
      y: 0.94,
      radius: 0.24,
      opacity: 0.65,
      phase: 4.5,
    );
    drawBubble(
      canvas,
      size,
      x: 0.30,
      y: 0.15,
      radius: 0.075,
      opacity: 0.75,
      phase: 2,
    );
    drawBubble(
      canvas,
      size,
      x: 0.80,
      y: 0.72,
      radius: 0.085,
      opacity: 0.8,
      phase: 4,
    );
    drawBubble(
      canvas,
      size,
      x: 0.90,
      y: 0.16,
      radius: 0.045,
      opacity: 0.6,
      phase: 5,
    );
  }

  @override
  bool shouldRepaint(covariant BubbleBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
