import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ZenBackground extends StatelessWidget {
  final Widget child;
  final double opacity;
  final bool isGame;

  const ZenBackground({
    super.key,
    required this.child,
    this.opacity = 1.0,
    this.isGame = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final myTheme = myThemes.firstWhere(
      (t) => t.primary.toARGB32() == colors.primary.toARGB32(),
      orElse: () => myThemes[0],
    );

    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: opacity,
            child: CustomPaint(
              painter: ZenPainter(
                backgroundColor: myTheme.background,
                circleColor: isGame 
                    ? myTheme.accent.withAlpha(8)  // Más transparente en el juego
                    : myTheme.accent.withAlpha(15), // Normal en home
                waveColor: myTheme.primary.withAlpha(8), // 3% opacidad
                isDark: myTheme.brightness == Brightness.dark,
                isGame: isGame,
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class ZenPainter extends CustomPainter {
  final Color backgroundColor;
  final Color circleColor;
  final Color waveColor;
  final bool isDark;
  final bool isGame;

  ZenPainter({
    required this.backgroundColor,
    required this.circleColor,
    required this.waveColor,
    required this.isDark,
    this.isGame = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fondo base
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final random = Random(42); // Semilla fija para consistencia

    // 2. Dibujar Ondas de Arena (Karesansui)
    // Dibujamos círculos concéntricos en la esquina inferior izquierda y superior derecha
    final wavePaint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Ondas en esquina inferior izquierda
    final center1 = Offset(-20, size.height + 20);
    for (double r = 40; r < size.width * 0.9; r += 24) {
      canvas.drawCircle(center1, r, wavePaint);
    }

    // Ondas en esquina superior derecha
    final center2 = Offset(size.width + 40, -40);
    for (double r = 60; r < size.width * 0.8; r += 32) {
      canvas.drawCircle(center2, r, wavePaint);
    }

    // 3. Dibujar círculo Ensō (círculo de meditación zen pintado a mano)
    // El círculo se sitúa en el centro en GameScreen y más arriba en HomeScreen
    final ensoCenter = Offset(size.width * 0.5, size.height * (isGame ? 0.5 : 0.28));
    final baseRadius = min(size.width * (isGame ? 0.35 : 0.26), 180.0);

    final ensoPaint = Paint()
      ..color = circleColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Dibujamos el círculo en varias pasadas para simular cerdas de pincel
    final double startAngle = -pi * 0.45; // Empezamos en el cuadrante superior
    final double sweepAngle = 2 * pi * 0.85; // No se cierra del todo (característica del Ensō)

    for (int i = 0; i < 5; i++) {
      final double rOffset = (random.nextDouble() - 0.5) * 6;
      final double angleOffset = (random.nextDouble() - 0.5) * 0.15;
      final double width = 12.0 - (i * 2.0); // Trazos de diferentes grosores

      ensoPaint.strokeWidth = width;
      
      canvas.drawArc(
        Rect.fromCircle(center: ensoCenter, radius: baseRadius + rOffset),
        startAngle + angleOffset,
        sweepAngle - (i * 0.05),
        false,
        ensoPaint,
      );
    }

    // Dibujar algunas gotas de tinta salpicadas (Ink Splatters)
    final splatterPaint = Paint()
      ..color = circleColor
      ..style = PaintingStyle.fill;

    final List<Offset> splatters = [
      Offset(ensoCenter.dx - baseRadius - 15, ensoCenter.dy + baseRadius * 0.4),
      Offset(ensoCenter.dx + baseRadius + 10, ensoCenter.dy - baseRadius * 0.6),
      Offset(ensoCenter.dx + baseRadius * 0.3, ensoCenter.dy + baseRadius + 20),
      Offset(ensoCenter.dx - baseRadius * 0.5, ensoCenter.dy - baseRadius - 15),
    ];

    for (var pos in splatters) {
      final radius = 2.0 + random.nextDouble() * 3.0;
      canvas.drawCircle(pos, radius, splatterPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ZenPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.circleColor != circleColor ||
        oldDelegate.waveColor != waveColor;
  }
}
