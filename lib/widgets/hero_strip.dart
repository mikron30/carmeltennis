import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../booking_tokens.dart';

class NextUpInfo {
  final int hour;
  final int courtNumber;
  final String partnerShort;
  final String? dateLabel; // null when next-up is today; e.g. 'מחר' otherwise
  const NextUpInfo({
    required this.hour,
    required this.courtNumber,
    required this.partnerShort,
    this.dateLabel,
  });
}

enum HeroDay { today, tomorrow }

class HeroStrip extends StatelessWidget {
  final HeroDay day;
  final DateTime date;
  final NextUpInfo? nextUp;
  final int? todayTemp;
  final int? tomorrowTemp;
  final ValueChanged<HeroDay> onDayChanged;
  final VoidCallback? onMenuTap;
  final bool afterRollover;

  const HeroStrip({
    super.key,
    required this.day,
    required this.date,
    required this.nextUp,
    required this.todayTemp,
    required this.tomorrowTemp,
    required this.onDayChanged,
    this.onMenuTap,
    this.afterRollover = false,
  });

  String get _todayLabel => afterRollover ? 'מחר' : 'היום';
  String get _tomorrowLabel => afterRollover ? 'מחרתיים' : 'מחר';

  @override
  Widget build(BuildContext context) {
    final tokens = BookingTokens.of(context);
    final hasNext = nextUp != null;
    final dayLabel = day == HeroDay.today ? _todayLabel : _tomorrowLabel;
    final dateStr = DateFormat('d.M').format(date);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.ease,
      padding: hasNext
          ? const EdgeInsets.fromLTRB(16, 11, 16, 12)
          : const EdgeInsets.fromLTRB(16, 9, 16, 10),
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
          if (hasNext)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topRow(dayLabel, dateStr),
                const SizedBox(height: 6),
                _bottomRowHasNext(context, tokens),
              ],
            )
          else
            _bottomRowNoNext(context, tokens, dayLabel),
        ],
      ),
    );
  }

  Widget _topRow(String dayLabel, String dateStr) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          dayLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: -0.48,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          dateStr,
          style: TextStyle(
            color: Colors.white.withOpacity(afterRollover ? 1.0 : 0.78),
            fontSize: afterRollover ? 13 : 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.44,
          ),
        ),
        const Spacer(),
        if (onMenuTap != null) _menuButton(),
      ],
    );
  }

  Widget _bottomRowHasNext(BuildContext context, BookingTokens tokens) {
    final n = nextUp!;
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: 'הבא ',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              if (n.dateLabel != null)
                TextSpan(
                  text: '${n.dateLabel} ',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.96),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              TextSpan(
                text: '${n.hour.toString().padLeft(2, '0')}:00',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: ' עם ',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.96),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: n.partnerShort,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: ' · מגרש ${n.courtNumber}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.96),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        _DayToggle(
          day: day,
          todayLabel: _todayLabel,
          tomorrowLabel: _tomorrowLabel,
          todayTemp: todayTemp,
          tomorrowTemp: tomorrowTemp,
          onChanged: onDayChanged,
          tokens: tokens,
        ),
      ],
    );
  }

  Widget _bottomRowNoNext(BuildContext context, BookingTokens tokens, String dayLabel) {
    final dateStr = DateFormat('d.M').format(date);
    return Row(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                dayLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.36,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                dateStr,
                style: TextStyle(
                  color: Colors.white.withOpacity(afterRollover ? 1.0 : 0.78),
                  fontSize: afterRollover ? 13 : 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.44,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '· אין הזמנה',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _DayToggle(
          day: day,
          todayLabel: _todayLabel,
          tomorrowLabel: _tomorrowLabel,
          todayTemp: todayTemp,
          tomorrowTemp: tomorrowTemp,
          onChanged: onDayChanged,
          tokens: BookingTokens.of(context),
        ),
        if (onMenuTap != null) ...[
          const SizedBox(width: 6),
          _menuButton(),
        ],
      ],
    );
  }

  Widget _menuButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onMenuTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: const Icon(Icons.menu, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  final HeroDay day;
  final String todayLabel;
  final String tomorrowLabel;
  final int? todayTemp;
  final int? tomorrowTemp;
  final ValueChanged<HeroDay> onChanged;
  final BookingTokens tokens;

  const _DayToggle({
    required this.day,
    required this.todayLabel,
    required this.tomorrowLabel,
    required this.todayTemp,
    required this.tomorrowTemp,
    required this.onChanged,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            label: todayLabel,
            temp: todayTemp,
            active: day == HeroDay.today,
            onTap: () => onChanged(HeroDay.today),
          ),
          const SizedBox(width: 1),
          _segment(
            label: tomorrowLabel,
            temp: tomorrowTemp,
            active: day == HeroDay.tomorrow,
            onTap: () => onChanged(HeroDay.tomorrow),
          ),
        ],
      ),
    );
  }

  Widget _segment({required String label, required int? temp, required bool active, required VoidCallback onTap}) {
    final fg = active ? tokens.clayD : Colors.white;
    final isWarn = temp != null && temp > 27;
    final tempColor = isWarn
        ? (active ? tokens.clay : tokens.warn)
        : (active ? tokens.clayD : Colors.white.withOpacity(0.8));
    return Material(
      color: active ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              if (temp != null) ...[
                const SizedBox(width: 4),
                Text(
                  '$temp°',
                  style: TextStyle(
                    color: tempColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
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
