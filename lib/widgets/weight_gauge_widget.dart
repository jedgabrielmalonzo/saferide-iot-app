import 'dart:math';
import 'package:flutter/material.dart';

/// A curved arc gauge widget that visualizes weight/load percentage
/// with smooth green → yellow → red color transitions.
class WeightGaugeWidget extends StatelessWidget {
  final double currentWeight;
  final double maxWeight;
  final double size;

  const WeightGaugeWidget({
    super.key,
    required this.currentWeight,
    required this.maxWeight,
    this.size = 200,
  });

  double get _percent => (currentWeight / maxWeight).clamp(0.0, 1.2);

  Color get _gaugeColor {
    final p = _percent;
    if (p <= 0.5) {
      // Green to Yellow
      return Color.lerp(
        const Color(0xFF00C853),
        const Color(0xFFFFAB00),
        (p / 0.5).clamp(0.0, 1.0),
      )!;
    } else if (p <= 0.85) {
      // Yellow to Orange
      return Color.lerp(
        const Color(0xFFFFAB00),
        const Color(0xFFFF6D00),
        ((p - 0.5) / 0.35).clamp(0.0, 1.0),
      )!;
    } else {
      // Orange to Red
      return Color.lerp(
        const Color(0xFFFF6D00),
        const Color(0xFFD32F2F),
        ((p - 0.85) / 0.15).clamp(0.0, 1.0),
      )!;
    }
  }

  String get _statusLabel {
    final p = _percent;
    if (p < 0.5) return "Light";
    if (p < 0.75) return "Moderate";
    if (p < 1.0) return "Heavy";
    return "Overloaded!";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _gaugeColor.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: size,
            height: size * 0.6,
            child: CustomPaint(
              painter: _GaugeArcPainter(
                percent: _percent,
                color: _gaugeColor,
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(top: size * 0.08),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${currentWeight.toStringAsFixed(0)}",
                        style: TextStyle(
                          fontSize: size * 0.18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                          height: 1.0,
                        ),
                      ),
                      Text(
                        "/ ${maxWeight.toStringAsFixed(0)} kg",
                        style: TextStyle(
                          fontSize: size * 0.07,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _gaugeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel,
              style: TextStyle(
                color: _gaugeColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugeArcPainter extends CustomPainter {
  final double percent;
  final Color color;

  _GaugeArcPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = size.width * 0.42;
    const startAngle = pi; // 180° (left)
    const sweepTotal = pi; // sweeping 180° (half circle)
    const strokeWidth = 14.0;

    // Background track
    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // Colored arc
    final sweepAngle = sweepTotal * percent.clamp(0.0, 1.0);
    if (sweepAngle > 0) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: _gradientColors,
          stops: _gradientStops,
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }

    // Tick marks: 0%, 25%, 50%, 75%, 100%
    for (int i = 0; i <= 4; i++) {
      final tickAngle = startAngle + (sweepTotal * i / 4);
      final innerPoint = Offset(
        center.dx + (radius - strokeWidth - 6) * cos(tickAngle),
        center.dy + (radius - strokeWidth - 6) * sin(tickAngle),
      );
      final outerPoint = Offset(
        center.dx + (radius - strokeWidth + 2) * cos(tickAngle),
        center.dy + (radius - strokeWidth + 2) * sin(tickAngle),
      );

      final tickPaint = Paint()
        ..color = Colors.grey[400]!
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(innerPoint, outerPoint, tickPaint);
    }
  }

  List<Color> get _gradientColors => [
    const Color(0xFF00C853),
    const Color(0xFFFFAB00),
    const Color(0xFFFF6D00),
    const Color(0xFFD32F2F),
  ];

  List<double> get _gradientStops => [0.0, 0.35, 0.65, 1.0];

  @override
  bool shouldRepaint(covariant _GaugeArcPainter oldDelegate) =>
      oldDelegate.percent != percent || oldDelegate.color != color;
}
