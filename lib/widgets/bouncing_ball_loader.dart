import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../booking_tokens.dart';

class BouncingBallLoader extends StatefulWidget {
  final double size;
  final bool showBaseline;
  final Duration period;

  const BouncingBallLoader({
    super.key,
    this.size = 36,
    this.showBaseline = true,
    this.period = const Duration(milliseconds: 700),
  });

  @override
  State<BouncingBallLoader> createState() => _BouncingBallLoaderState();
}

class _BouncingBallLoaderState extends State<BouncingBallLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disable) {
      if (_ctrl.isAnimating) _ctrl.stop();
      _ctrl.value = 0;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = BookingTokens.of(context);
    final w = widget.size * 2.5;
    final h = widget.size * (widget.showBaseline ? 1.8 : 1.4);

    return SizedBox(
      width: w,
      height: h,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _TennisBallPainter(
            t: _ctrl.value,
            ballSize: widget.size,
            showBaseline: widget.showBaseline,
            clay: tokens.clay,
            ink2: tokens.ink2,
          ),
          size: Size(w, h),
        ),
      ),
    );
  }
}

class _TennisBallPainter extends CustomPainter {
  final double t;
  final double ballSize;
  final bool showBaseline;
  final Color clay;
  final Color ink2;

  static const Color _ballYellow = Color(0xFFD9F03A);
  static const Color _ballHighlight = Color(0xFFEFFA8B);
  static const Color _seam = Color(0xFFFFFFFF);

  _TennisBallPainter({
    required this.t,
    required this.ballSize,
    required this.showBaseline,
    required this.clay,
    required this.ink2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = ballSize / 2;
    final centerX = size.width / 2;
    final groundY = size.height - (showBaseline ? r * 0.6 : r * 0.2) - r;

    // Bounce: parabolic 0→1→0 over the period.
    // Use sin(πt) for symmetric arc, then ease the up/down halves separately.
    final phase = t;
    final bounce = math.sin(phase * math.pi); // 0..1..0
    final eased = phase < 0.5
        ? Curves.easeOutQuad.transform(bounce)
        : Curves.easeInQuad.transform(bounce);
    final amplitude = ballSize * 1.6;
    final ballY = groundY - eased * amplitude;

    // Squash/stretch: squash near ground (low bounce), stretch near apex.
    final grounded = (1.0 - eased).clamp(0.0, 1.0);
    final apex = eased.clamp(0.0, 1.0);
    final scaleX = 1.0 + 0.15 * grounded - 0.05 * apex;
    final scaleY = 1.0 - 0.22 * grounded + 0.05 * apex;

    // Shadow: wider/darker when grounded.
    if (showBaseline || grounded > 0.05) {
      final shadowAlpha = (0.18 * grounded + 0.05).clamp(0.0, 0.32);
      final shadowW = ballSize * (0.95 + 0.6 * grounded);
      final shadowH = ballSize * 0.18 * (0.6 + 0.4 * grounded);
      final shadowRect = Rect.fromCenter(
        center: Offset(centerX, groundY + r * 0.95),
        width: shadowW,
        height: shadowH,
      );
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(shadowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawOval(shadowRect, shadowPaint);
    }

    // Baseline (court line) under the ball.
    if (showBaseline) {
      final lineY = groundY + r * 1.25;
      final lineW = ballSize * 2.2;
      final linePaint = Paint()
        ..color = clay.withOpacity(0.35)
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(centerX - lineW / 2, lineY),
        Offset(centerX + lineW / 2, lineY),
        linePaint,
      );
    }

    // Ball.
    canvas.save();
    canvas.translate(centerX, ballY);
    canvas.scale(scaleX, scaleY);

    // Body
    final bodyPaint = Paint()..color = _ballYellow;
    canvas.drawCircle(Offset.zero, r, bodyPaint);

    // Highlight
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.5),
        radius: 0.9,
        colors: [
          _ballHighlight.withOpacity(0.85),
          _ballHighlight.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    canvas.drawCircle(Offset.zero, r, highlightPaint);

    // Outline tinted with brand clay.
    final outlinePaint = Paint()
      ..color = clay.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, r * 0.06);
    canvas.drawCircle(Offset.zero, r - outlinePaint.strokeWidth / 2, outlinePaint);

    // Felt seams: two opposing arcs.
    final seamPaint = Paint()
      ..color = _seam.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, r * 0.12)
      ..strokeCap = StrokeCap.round;
    final seamRectA = Rect.fromCircle(
      center: Offset(-r * 0.55, 0),
      radius: r * 0.95,
    );
    final seamRectB = Rect.fromCircle(
      center: Offset(r * 0.55, 0),
      radius: r * 0.95,
    );
    canvas.drawArc(seamRectA, -math.pi / 2.6, math.pi / 1.3, false, seamPaint);
    canvas.drawArc(seamRectB, math.pi / 2 + (math.pi / 2 - math.pi / 2.6),
        math.pi / 1.3, false, seamPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TennisBallPainter old) {
    return old.t != t ||
        old.ballSize != ballSize ||
        old.showBaseline != showBaseline ||
        old.clay != clay ||
        old.ink2 != ink2;
  }
}
