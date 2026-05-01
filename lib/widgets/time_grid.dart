import 'package:flutter/material.dart';
import '../booking_tokens.dart';
import 'slot_button.dart';

typedef SlotBuilder = SlotData Function(int courtUiIndex, int hour);

class SlotData {
  final SlotState state;
  final String? primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onTap;

  const SlotData({
    required this.state,
    this.primaryLabel,
    this.secondaryLabel,
    this.onTap,
  });
}

const Set<int> kEveningHours = {18, 19, 20};
const Set<int> kBusyHours = kEveningHours;

const List<int> kHours = [
  7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
];

class TimeGrid extends StatelessWidget {
  final int numberOfCourts;
  final int? nowHour; // null when not viewing today
  final SlotBuilder slotBuilder;

  const TimeGrid({
    super.key,
    required this.numberOfCourts,
    required this.nowHour,
    required this.slotBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = BookingTokens.of(context);
    if (numberOfCourts <= 0) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'אין מגרשים זמינים ביום זה',
              style: TextStyle(color: tokens.ink2, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Expanded(
      child: Column(
        children: [
          _CourtHeader(numberOfCourts: numberOfCourts, tokens: tokens),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              itemCount: kHours.length,
              itemBuilder: (ctx, i) {
                final hour = kHours[i];
                final showNow = nowHour != null && hour == nowHour! + 1;
                return Column(
                  children: [
                    if (showNow) _NowDivider(tokens: tokens, nowHour: nowHour!),
                    _HourRow(
                      hour: hour,
                      numberOfCourts: numberOfCourts,
                      tokens: tokens,
                      slotBuilder: slotBuilder,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CourtHeader extends StatelessWidget {
  final int numberOfCourts;
  final BookingTokens tokens;
  const _CourtHeader({required this.numberOfCourts, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.bg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const SizedBox(width: 36),
          for (int i = 0; i < numberOfCourts; i++) ...[
            Expanded(
              child: Center(
                child: Text(
                  'מגרש ${i + 1}',
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            if (i < numberOfCourts - 1) const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }
}

class _HourRow extends StatelessWidget {
  final int hour;
  final int numberOfCourts;
  final BookingTokens tokens;
  final SlotBuilder slotBuilder;

  const _HourRow({
    required this.hour,
    required this.numberOfCourts,
    required this.tokens,
    required this.slotBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final busy = kBusyHours.contains(hour);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: busy
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  tokens.clay.withOpacity(0.0),
                  tokens.clay.withOpacity(0.05),
                  tokens.clay.withOpacity(0.10),
                ],
              ),
            )
          : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 36,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hour.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: tokens.ink2,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (busy) ...[
                      const SizedBox(width: 2),
                      Text(
                        '●',
                        style: TextStyle(color: tokens.clay, fontSize: 7),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            for (int i = 0; i < numberOfCourts; i++) ...[
              Expanded(
                child: Builder(builder: (_) {
                  final data = slotBuilder(numberOfCourts - 1 - i, hour);
                  return SlotButton(
                    state: data.state,
                    primaryLabel: data.primaryLabel,
                    secondaryLabel: data.secondaryLabel,
                    onTap: data.onTap,
                  );
                }),
              ),
              if (i < numberOfCourts - 1) const SizedBox(width: 5),
            ],
          ],
        ),
      ),
    );
  }
}

class _NowDivider extends StatelessWidget {
  final BookingTokens tokens;
  final int nowHour;
  const _NowDivider({required this.tokens, required this.nowHour});

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final label = '— עכשיו ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} —';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Container(height: 2, color: tokens.clay.withOpacity(0.5))),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: tokens.clay,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 2, color: tokens.clay.withOpacity(0.5))),
        ],
      ),
    );
  }
}
