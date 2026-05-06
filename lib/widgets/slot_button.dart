import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../booking_tokens.dart';

enum SlotState { free, preview, pending, failed, taken, mine, mineLocked, past, coach }

class SlotButton extends StatefulWidget {
  final SlotState state;
  final String? primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onTap;

  const SlotButton({
    super.key,
    required this.state,
    this.primaryLabel,
    this.secondaryLabel,
    this.onTap,
  });

  @override
  State<SlotButton> createState() => _SlotButtonState();
}

class _SlotButtonState extends State<SlotButton> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _shimmer;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant SlotButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncAnimations();
    }
  }

  void _syncAnimations() {
    if (widget.state == SlotState.preview) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
    if (widget.state == SlotState.pending) {
      if (!_shimmer.isAnimating) _shimmer.repeat();
    } else {
      _shimmer.stop();
      _shimmer.value = 0;
    }
    if (widget.state == SlotState.failed) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _shimmer.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = BookingTokens.of(context);
    final decoration = _decorationFor(tokens);
    final textColor = _textColorFor(tokens);
    final cursor = widget.state == SlotState.past
        ? SystemMouseCursors.forbidden
        : (widget.state == SlotState.pending
            ? SystemMouseCursors.wait
            : SystemMouseCursors.click);

    Widget child = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: decoration,
      alignment: Alignment.center,
      child: _buildLabel(textColor),
    );

    child = Stack(
      fit: StackFit.passthrough,
      children: [
        if (widget.state == SlotState.free)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: CustomPaint(painter: _DiagonalHatchPainter()),
              ),
            ),
          ),
        child,
        if (widget.state == SlotState.preview)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) {
                  final t = (math.sin(_pulse.value * 2 * math.pi) + 1) / 2;
                  final spread = 6 * t;
                  final opacity = 0.4 * (1 - t);
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(
                          color: tokens.clay.withOpacity(opacity),
                          spreadRadius: spread,
                          blurRadius: 0,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        if (widget.state == SlotState.pending)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: AnimatedBuilder(
                  animation: _shimmer,
                  builder: (_, __) {
                    return ShaderMask(
                      shaderCallback: (rect) {
                        final dx = (1 - 2 * _shimmer.value) * rect.width;
                        return LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.25),
                            Colors.white.withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                          transform: GradientTranslate(dx),
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.srcATop,
                      child: Container(color: Colors.white.withOpacity(0.001)),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.state == SlotState.failed) {
      child = AnimatedBuilder(
        animation: _shake,
        builder: (_, c) {
          final v = _shake.value;
          double dx = 0;
          if (v < 0.2) {
            dx = -4 * (v / 0.2);
          } else if (v < 0.4) {
            dx = -4 + 8 * ((v - 0.2) / 0.2);
          } else if (v < 0.6) {
            dx = 4 - 7 * ((v - 0.4) / 0.2);
          } else if (v < 0.8) {
            dx = -3 + 6 * ((v - 0.6) / 0.2);
          } else {
            dx = 3 * (1 - (v - 0.8) / 0.2);
          }
          return Transform.translate(offset: Offset(dx, 0), child: c);
        },
        child: child,
      );
    }

    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        onTap: widget.onTap,
        child: child,
      ),
    );
  }

  Widget _buildLabel(Color color) {
    final base = TextStyle(
      color: color,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final secondaryStyle = base.copyWith(
      fontSize: 9,
      fontWeight: FontWeight.w800,
    );

    final primary = widget.primaryLabel ?? '';
    final secondary = widget.secondaryLabel;

    final mineBadge = widget.state == SlotState.mine
        ? '·${secondary ?? 'שלי'}'
        : (widget.state == SlotState.mineLocked ? '·נעול' : null);

    if (widget.state == SlotState.preview) {
      return Text.rich(
        TextSpan(children: [
          TextSpan(text: primary.isEmpty ? 'פנוי' : primary, style: base),
          TextSpan(text: ' ·אישור?', style: secondaryStyle),
        ]),
        textAlign: TextAlign.center,
      );
    }
    if (mineBadge != null) {
      return Text.rich(
        TextSpan(children: [
          TextSpan(text: primary, style: base),
          TextSpan(
            text: ' $mineBadge',
            style: secondaryStyle.copyWith(color: color.withOpacity(0.85)),
          ),
        ]),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (widget.state == SlotState.taken && secondary != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(primary, style: base, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
        ],
      );
    }
    return Text(
      primary,
      style: base,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );
  }

  BoxDecoration _decorationFor(BookingTokens t) {
    final radius = BorderRadius.circular(7);
    switch (widget.state) {
      case SlotState.free:
        return BoxDecoration(color: t.green, borderRadius: radius);
      case SlotState.preview:
        return BoxDecoration(
          color: t.clayTint,
          borderRadius: radius,
          border: Border.all(color: t.clay, width: 2, style: BorderStyle.solid),
        );
      case SlotState.pending:
        return BoxDecoration(color: t.green.withOpacity(0.65), borderRadius: radius);
      case SlotState.failed:
        return BoxDecoration(color: t.clay, borderRadius: radius);
      case SlotState.taken:
        return BoxDecoration(
          color: t.surface,
          borderRadius: radius,
          border: Border.all(color: t.line, width: 1.5),
        );
      case SlotState.mine:
      case SlotState.mineLocked:
        return BoxDecoration(
          color: t.clay,
          borderRadius: radius,
          boxShadow: t.shadowMine,
        );
      case SlotState.past:
        return BoxDecoration(
          color: t.pastBg,
          borderRadius: radius,
          border: Border.all(color: t.line, width: 1.5),
        );
      case SlotState.coach:
        return BoxDecoration(
          color: t.clayTint,
          borderRadius: radius,
          border: Border.all(color: t.clay.withOpacity(0.5), width: 1),
        );
    }
  }

  Color _textColorFor(BookingTokens t) {
    switch (widget.state) {
      case SlotState.free:
      case SlotState.pending:
      case SlotState.failed:
      case SlotState.mine:
      case SlotState.mineLocked:
        return Colors.white;
      case SlotState.preview:
        return t.clayInk;
      case SlotState.taken:
        return t.ink2;
      case SlotState.past:
        return t.pastInk;
      case SlotState.coach:
        return t.clayInk;
    }
  }
}

class _DiagonalHatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 1;
    const spacing = 7.0;
    final diag = size.width + size.height;
    for (double offset = -size.height; offset < diag; offset += spacing) {
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GradientTranslate extends GradientTransform {
  final double dx;
  const GradientTranslate(this.dx);
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.identity()..translate(dx);
  }
}
