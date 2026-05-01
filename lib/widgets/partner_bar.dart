import 'package:flutter/material.dart';
import '../booking_tokens.dart';

class PartnerBar extends StatelessWidget {
  final String? partnerName;
  final bool partnerAvailable;
  final int usedEvenings; // 0..3
  final bool darkMode;
  // Restore-last-week disabled — see docs/restore_last_week.md.
  final VoidCallback? onRestoreTap;
  final VoidCallback onThemeToggle;

  const PartnerBar({
    super.key,
    required this.partnerName,
    required this.partnerAvailable,
    required this.usedEvenings,
    required this.darkMode,
    this.onRestoreTap,
    required this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = BookingTokens.of(context);
    final clamped = usedEvenings.clamp(0, 3);
    final initial = (partnerName == null || partnerName!.trim().isEmpty)
        ? '?'
        : partnerName!.trim().characters.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          bottom: BorderSide(color: tokens.line, width: 1),
        ),
      ),
      child: Row(
        children: [
          _Avatar(initial: initial, tokens: tokens),
          const SizedBox(width: 10),
          Expanded(
            child: partnerName == null
                ? Text(
                    'בחר/י שותפ.ה',
                    style: TextStyle(
                      color: tokens.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'שותפ.ה  ',
                        style: TextStyle(
                          color: tokens.ink2,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (partnerAvailable) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: tokens.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          partnerName!,
                          style: TextStyle(
                            color: tokens.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'ערב ',
                  style: TextStyle(
                    color: tokens.ink2,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: '$clamped',
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: '/3',
                  style: TextStyle(
                    color: tokens.ink2,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Padding(
                padding: EdgeInsetsDirectional.only(end: i == 2 ? 0 : 2),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < clamped ? tokens.clay : tokens.line,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(width: 10),
          // Restore-last-week disabled — see docs/restore_last_week.md.
          // _IconBtn(glyph: '↻', tooltip: 'כמו בשבוע שעבר', onTap: onRestoreTap!, tokens: tokens),
          // const SizedBox(width: 3),
          // Cycle-partner button removed — added no value over the recents strip.
          _ThemeBtn(darkMode: darkMode, tokens: tokens, onTap: onThemeToggle),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initial;
  final BookingTokens tokens;
  const _Avatar({required this.initial, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.clayTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: tokens.clayInk,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          height: 1,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final String glyph;
  final String tooltip;
  final VoidCallback onTap;
  final BookingTokens tokens;
  const _IconBtn({required this.glyph, required this.tooltip, required this.onTap, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: tokens.clayTint,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: Text(
                glyph,
                style: TextStyle(
                  color: tokens.clayInk,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
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

class _ThemeBtn extends StatelessWidget {
  final bool darkMode;
  final BookingTokens tokens;
  final VoidCallback onTap;
  const _ThemeBtn({required this.darkMode, required this.tokens, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: darkMode ? 'מצב יום' : 'מצב לילה',
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: tokens.line2, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Text(
                darkMode ? '☀' : '☾',
                style: TextStyle(
                  color: tokens.ink2,
                  fontSize: 12,
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
