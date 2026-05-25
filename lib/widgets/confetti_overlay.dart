import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiParticle {
  final double x;
  final double startY;
  final double speed;
  final Color color;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final double drift;

  const ConfettiParticle({
    required this.x,
    required this.startY,
    required this.speed,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.drift,
  });
}

List<ConfettiParticle> generateConfettiParticles({int count = 60}) {
  final rng = Random();
  const colors = [
    Color(0xFFF5A623),
    Color(0xFFFFD600),
    Color(0xFF4CAF50),
    Colors.white,
    Color(0xFFFFF8EC),
    Color(0xFF81C784),
    Color(0xFF64B5F6),
    Color(0xFFFF80AB),
  ];
  return List.generate(
    count,
    (_) => ConfettiParticle(
      x: rng.nextDouble(),
      startY: -0.05 - rng.nextDouble() * 0.14,
      speed: 0.50 + rng.nextDouble() * 0.50,
      color: colors[rng.nextInt(colors.length)],
      size: 5.0 + rng.nextDouble() * 8.0,
      rotation: rng.nextDouble() * 2 * pi,
      rotationSpeed: (rng.nextDouble() - 0.5) * 10,
      drift: (rng.nextDouble() - 0.5) * 0.16,
    ),
  );
}

class ConfettiPainter extends CustomPainter {
  final double progress;
  final List<ConfettiParticle> particles;

  ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1 || particles.isEmpty) return;

    final fade = progress < 0.65
        ? 1.0
        : (1.0 - (progress - 0.65) / 0.35).clamp(0.0, 1.0);

    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final x = (p.x + p.drift * progress) * size.width;
      final y = (p.startY + p.speed * progress) * size.height;
      if (y < -p.size || y > size.height + p.size) continue;

      paint.color = p.color.withValues(alpha: fade * 0.92);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * p.rotationSpeed);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.48),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter old) => progress != old.progress;
}

class ConfettiOverlay extends StatelessWidget {
  final AnimationController controller;
  final List<ConfettiParticle> particles;

  const ConfettiOverlay({
    super.key,
    required this.controller,
    required this.particles,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, _) => CustomPaint(
            painter: ConfettiPainter(
              progress: controller.value,
              particles: particles,
            ),
          ),
        ),
      ),
    );
  }
}
