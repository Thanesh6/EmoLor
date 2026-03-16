import 'dart:math';
import 'package:flutter/material.dart';

/// A star reward animation widget that shows burst of stars on success
class StarRewardWidget extends StatefulWidget {
  final VoidCallback? onComplete;
  
  const StarRewardWidget({super.key, this.onComplete});

  @override
  State<StarRewardWidget> createState() => _StarRewardWidgetState();

  /// Show a star reward overlay on the current context
  static void show(BuildContext context, {VoidCallback? onComplete}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (context) => StarRewardWidget(
        onComplete: () {
          entry.remove();
          onComplete?.call();
        },
      ),
    );
    
    overlay.insert(entry);
  }
}

class _StarRewardWidgetState extends State<StarRewardWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _fadeController;
  final List<_StarParticle> _stars = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Create star particles
    for (int i = 0; i < 12; i++) {
      _stars.add(_StarParticle(
        angle: (i * 30) * (pi / 180),
        speed: 150 + _random.nextDouble() * 100,
        size: 20 + _random.nextDouble() * 20,
        color: _getStarColor(i),
        rotationSpeed: (_random.nextDouble() - 0.5) * 4,
      ));
    }
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _fadeController.reverse().then((_) {
          widget.onComplete?.call();
        });
      }
    });
    
    _fadeController.value = 1.0;
    _controller.forward();
  }

  Color _getStarColor(int index) {
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFFFE66D), // Yellow
      const Color(0xFFFF9F43), // Orange
      const Color(0xFFFF7EB3), // Pink
      const Color(0xFF7ED957), // Green
      const Color(0xFF74B9FF), // Blue
    ];
    return colors[index % colors.length];
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fadeController,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _StarPainter(
                  stars: _stars,
                  progress: _controller.value,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StarParticle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double rotationSpeed;

  _StarParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotationSpeed,
  });
}

class _StarPainter extends CustomPainter {
  final List<_StarParticle> stars;
  final double progress;

  _StarPainter({required this.stars, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Easing for burst effect
    final easedProgress = Curves.easeOutQuart.transform(progress);
    final fadeProgress = progress > 0.7 ? (progress - 0.7) / 0.3 : 0.0;
    
    for (final star in stars) {
      final distance = star.speed * easedProgress;
      final x = center.dx + cos(star.angle) * distance;
      final y = center.dy + sin(star.angle) * distance - (50 * easedProgress); // Rise up
      
      final opacity = (1.0 - fadeProgress).clamp(0.0, 1.0);
      final scale = (1.0 - fadeProgress * 0.5).clamp(0.0, 1.0);
      
      _drawStar(
        canvas,
        Offset(x, y),
        star.size * scale,
        star.color.withValues(alpha: opacity),
        star.rotationSpeed * progress * 2 * pi,
      );
    }
    
    // Center glow effect
    if (progress < 0.5) {
      final glowProgress = progress * 2;
      final glowRadius = 80 * glowProgress;
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.6 * (1 - glowProgress)),
            const Color(0xFFFFD700).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
      
      canvas.drawCircle(center, glowRadius, glowPaint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Color color, double rotation) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    const int points = 5;
    final outerRadius = size / 2;
    final innerRadius = outerRadius * 0.4;
    
    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = rotation + (i * pi / points) - (pi / 2);
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    // Add glow shadow
    canvas.drawShadow(path, color, 4, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
