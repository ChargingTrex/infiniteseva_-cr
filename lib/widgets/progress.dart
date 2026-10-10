import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../util.dart';

/// Number that counts up (and re-animates when the value changes).
class CountUp extends StatelessWidget {
  final num value;
  final TextStyle style;
  final Duration duration;
  const CountUp({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(fmt(v.round()), style: style),
    );
  }
}

/// Home-page ring: six gold arcs around a framed picture with the live count.
class SixfoldRing extends StatelessWidget {
  final double pct; // 0..100
  final num completed;
  final String completedLabel;
  final String ofTargetLabel;
  final double size;

  const SixfoldRing({
    super.key,
    required this.pct,
    required this.completed,
    required this.completedLabel,
    required this.ofTargetLabel,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final inset = size * 0.07;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(inset),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: C.gold.withOpacity(0.7), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: C.maroon.withOpacity(0.35),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                      spreadRadius: -20,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/vel.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: C.maroon),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              C.maroon.withOpacity(0.70),
                              C.maroon.withOpacity(0.45),
                              C.maroon.withOpacity(0.25),
                            ],
                            stops: const [0, 0.6, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: pct),
              duration: const Duration(milliseconds: 1600),
              curve: Curves.easeOutQuart,
              builder: (_, v, __) => CustomPaint(painter: _SixPainter(v)),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(completedLabel,
                  style: body(size * 0.05, color: C.cream.withOpacity(0.9), weight: FontWeight.w600)),
              const SizedBox(height: 2),
              CountUp(
                value: completed,
                style: display(size * 0.18, color: C.cream, height: 1)
                    .copyWith(shadows: const [Shadow(blurRadius: 12, color: Color(0x73000000))]),
              ),
              const SizedBox(height: 4),
              Text('${fmtPct(pct)}% $ofTargetLabel',
                  style: body(size * 0.045, color: C.gold, weight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SixPainter extends CustomPainter {
  final double pct;
  _SixPainter(this.pct);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.03;
    final radius = size.width * 0.46;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    const per = 100 / 6;
    const seg = math.pi / 3;
    const pad = 0.05;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = C.gold.withOpacity(0.22);
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [C.gold, C.goldDark],
      ).createShader(rect);

    for (var i = 0; i < 6; i++) {
      final start = -math.pi / 2 + i * seg + pad;
      final sweep = seg - pad * 2;
      canvas.drawArc(rect, start, sweep, false, track);
      final fill = ((pct - i * per) / per).clamp(0.0, 1.0);
      if (fill > 0) canvas.drawArc(rect, start, sweep * fill, false, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SixPainter old) => old.pct != pct;
}

/// Dashboard ring (single arc on dark maroon card).
class ProgressRing extends StatelessWidget {
  final double percent; // 0..100
  final Widget child;
  final double size;
  const ProgressRing({super.key, required this.percent, required this.child, this.size = 140});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: percent.clamp(0, 100).toDouble()),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutQuart,
            builder: (_, v, __) => CustomPaint(size: Size(size, size), painter: _RingPainter(v)),
          ),
          child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  _RingPainter(this.percent);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.width - stroke) / 2,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withOpacity(0.15);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF4C95D);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (percent > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * percent / 100, false, arc);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.percent != percent;
}
