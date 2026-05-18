import 'package:flutter/material.dart';
import '../booking_density.dart';
import '../booking_tokens.dart';

enum HeroDay { today, tomorrow }

class HeroStrip extends StatelessWidget {
  final HeroDay day;
  final ValueChanged<HeroDay> onDayChanged;
  final int usedEvenings; // 0..3
  final int eveningQuota;
  final bool darkMode;
  final VoidCallback onThemeToggle;
  final VoidCallback? onMenuTap;
  final bool afterRollover;

  const HeroStrip({
    super.key,
    required this.day,
    required this.onDayChanged,
    required this.usedEvenings,
    required this.darkMode,
    required this.onThemeToggle,
    this.onMenuTap,
    this.eveningQuota = 3,
    this.afterRollover = false,
  });

  String get _todayLabel => afterRollover ? 'מחר' : 'היום';
  String get _tomorrowLabel => afterRollover ? 'מחרתיים' : 'מחר';

  @override
  Widget build(BuildContext context) {
    final tokens = BookingTokens.of(context);
    final spec = BookingDensitySpec.of(context);
    final clamped = usedEvenings.clamp(0, eveningQuota);

    return Container(
      constraints: BoxConstraints(minHeight: spec.heroMinHeight),
      padding: spec.heroPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tokens.clay, tokens.clayD],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _LineTexturePainter()),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _DayToggle(
                  day: day,
                  todayLabel: _todayLabel,
                  tomorrowLabel: _tomorrowLabel,
                  onChanged: onDayChanged,
                  tokens: tokens,
                  spec: spec,
                ),
              ),
              SizedBox(width: spec.heroGap),
              _ErevCap(
                used: clamped,
                quota: eveningQuota,
                spec: spec,
              ),
              SizedBox(width: spec.heroGap),
              _IconBtn(
                glyph: darkMode ? '☀' : '☾',
                onTap: onThemeToggle,
                spec: spec,
              ),
              if (onMenuTap != null) ...[
                SizedBox(width: spec.heroGap),
                _IconBtn(
                  glyph: '☰',
                  onTap: onMenuTap!,
                  spec: spec,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  final HeroDay day;
  final String todayLabel;
  final String tomorrowLabel;
  final ValueChanged<HeroDay> onChanged;
  final BookingTokens tokens;
  final BookingDensitySpec spec;

  const _DayToggle({
    required this.day,
    required this.todayLabel,
    required this.tomorrowLabel,
    required this.onChanged,
    required this.tokens,
    required this.spec,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(spec.dayToggleInnerPadding),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(spec.dayToggleOuterRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segment(
              label: todayLabel,
              active: day == HeroDay.today,
              onTap: () => onChanged(HeroDay.today),
            ),
          ),
          SizedBox(width: spec.dayToggleInnerPadding),
          Expanded(
            child: _segment(
              label: tomorrowLabel,
              active: day == HeroDay.tomorrow,
              onTap: () => onChanged(HeroDay.tomorrow),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final fg = active ? tokens.clayD : Colors.white;
    final innerRadius = (spec.dayToggleOuterRadius - 3).clamp(2, 16).toDouble();
    return Material(
      color: active ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(innerRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(innerRadius),
        child: Container(
          constraints: BoxConstraints(minHeight: spec.dayBtnMinHeight),
          padding: spec.dayBtnPadding,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: spec.dayToggleFontSize,
              fontWeight: spec.dayToggleFontWeight,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErevCap extends StatelessWidget {
  final int used;
  final int quota;
  final BookingDensitySpec spec;
  const _ErevCap({required this.used, required this.quota, required this.spec});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ערב $used/$quota',
          style: TextStyle(
            color: Colors.white,
            fontSize: spec.capFontSize,
            fontWeight: spec.capFontWeight,
            height: 1,
          ),
        ),
        SizedBox(width: spec.capPipGap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < quota; i++) ...[
              if (i > 0) SizedBox(width: spec.pipGap),
              Container(
                width: spec.pipDiameter,
                height: spec.pipDiameter,
                decoration: BoxDecoration(
                  color: i < used
                      ? Colors.white
                      : Colors.white.withOpacity(0.28),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final String glyph;
  final VoidCallback onTap;
  final BookingDensitySpec spec;
  const _IconBtn({required this.glyph, required this.onTap, required this.spec});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.22),
      borderRadius: BorderRadius.circular(spec.iconBtnRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(spec.iconBtnRadius),
        child: SizedBox(
          width: spec.iconBtnSize,
          height: spec.iconBtnSize,
          child: Center(
            child: Text(
              glyph,
              style: TextStyle(
                color: Colors.white,
                fontSize: spec.iconBtnGlyphSize,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LineTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    for (double y = 22.5; y < size.height; y += 23) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
