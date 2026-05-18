import 'package:flutter/material.dart';
import '../booking_density.dart';
import '../booking_tokens.dart';

class RecentPartner {
  final String label;
  final String value;
  final bool available;
  const RecentPartner({
    required this.label,
    required this.value,
    this.available = false,
  });
}

class RecentsStrip extends StatelessWidget {
  final List<RecentPartner> recents;
  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback? onAddTap;

  const RecentsStrip({
    super.key,
    required this.recents,
    required this.selected,
    required this.onSelect,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = BookingTokens.of(context);
    final spec = BookingDensitySpec.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          bottom: BorderSide(color: tokens.line, width: 1),
        ),
      ),
      padding: spec.recentsPadding,
      child: Row(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(end: spec.recentsGap),
            child: Text(
              'עם:',
              style: TextStyle(
                color: tokens.ink2,
                fontSize: spec.recentsLeadingFontSize,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < recents.length; i++) ...[
                    _Chip(
                      partner: recents[i],
                      active: selected == recents[i].value,
                      tokens: tokens,
                      spec: spec,
                      onTap: () => onSelect(recents[i].value),
                    ),
                    if (i < recents.length - 1) SizedBox(width: spec.recentsGap),
                  ],
                ],
              ),
            ),
          ),
          if (onAddTap != null) ...[
            SizedBox(width: spec.recentsGap),
            _AddChip(onTap: onAddTap!, tokens: tokens, spec: spec),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final RecentPartner partner;
  final bool active;
  final BookingTokens tokens;
  final BookingDensitySpec spec;
  final VoidCallback onTap;

  const _Chip({
    required this.partner,
    required this.active,
    required this.tokens,
    required this.spec,
    required this.onTap,
  });

  String get _firstName {
    final t = partner.label.trim();
    if (t.isEmpty) return t;
    final parts = t.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? t : parts.first;
  }

  String get _initial {
    final n = _firstName;
    if (n.isEmpty) return '?';
    return n.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    final bg = active ? tokens.clay : tokens.clayTint;
    final fg = active ? Colors.white : tokens.clayInk;
    final padding = active ? spec.chipPaddingActive : spec.chipPadding;
    final fontSize = active ? spec.chipFontSizeActive : spec.chipFontSize;
    final fontWeight = active ? FontWeight.w800 : FontWeight.w700;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(spec.chipRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(spec.chipRadius),
        child: Container(
          constraints: BoxConstraints(minHeight: spec.chipMinHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(spec.chipRadius),
            border: Border.all(
              color: active ? tokens.clayD : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      offset: const Offset(0, -2),
                      spreadRadius: 0,
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active) ...[
                Container(
                  width: spec.avatarSize,
                  height: spec.avatarSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(spec.avatarRadius),
                  ),
                  child: Text(
                    _initial,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: spec.avatarFontSize,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
                SizedBox(width: spec.avatarLabelGap),
              ] else if (partner.available) ...[
                Container(
                  width: spec.onlineDotSize,
                  height: spec.onlineDotSize,
                  decoration: BoxDecoration(
                    color: tokens.green,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: spec.onlineDotGap),
              ],
              Text(
                _firstName,
                style: TextStyle(
                  color: fg,
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  height: 1,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final VoidCallback onTap;
  final BookingTokens tokens;
  final BookingDensitySpec spec;
  const _AddChip({required this.onTap, required this.tokens, required this.spec});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(spec.chipRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(spec.chipRadius),
        child: DottedBorder(
          color: tokens.line2,
          borderWidth: spec.addChipBorderWidth,
          radius: spec.chipRadius,
          child: SizedBox(
            width: spec.addChipSize,
            height: spec.addChipSize,
            child: Center(
              child: Text(
                '+',
                style: TextStyle(
                  color: tokens.ink2,
                  fontSize: spec.addChipGlyphSize,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight dashed-border wrapper. Renders a rounded rectangle with a
/// dashed stroke. Used by the recents-strip "+" chip.
class DottedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double borderWidth;
  final double radius;

  const DottedBorder({
    super.key,
    required this.child,
    required this.color,
    required this.borderWidth,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: color,
        strokeWidth: borderWidth,
        radius: radius,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, dashLength: 4, gapLength: 3);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path src, {required double dashLength, required double gapLength}) {
    final dest = Path();
    for (final metric in src.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0, metric.length).toDouble();
        dest.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + gapLength;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || old.radius != radius;
}
