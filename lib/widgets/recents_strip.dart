import 'package:flutter/material.dart';
import '../booking_tokens.dart';

class RecentPartner {
  final String name;
  final bool available;
  const RecentPartner({required this.name, required this.available});
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
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          bottom: BorderSide(color: tokens.line, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            _Legend(tokens: tokens),
            const SizedBox(width: 8),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recents.length + (onAddTap != null ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(width: 5),
                itemBuilder: (ctx, i) {
                  if (onAddTap != null && i == recents.length) {
                    return _AddChip(onTap: onAddTap!, tokens: tokens);
                  }
                  final r = recents[i];
                  final isOn = selected == r.name;
                  return _Chip(
                    partner: r,
                    active: isOn,
                    tokens: tokens,
                    onTap: () => onSelect(r.name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final BookingTokens tokens;
  const _Legend({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: tokens.green,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'פנוי.ה',
          style: TextStyle(
            color: tokens.ink2,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final RecentPartner partner;
  final bool active;
  final BookingTokens tokens;
  final VoidCallback onTap;
  const _Chip({required this.partner, required this.active, required this.tokens, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = active ? tokens.ink : tokens.clayTint;
    final fg = active ? tokens.bg : tokens.clayInk;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (partner.available) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: tokens.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                partner.name,
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
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
  const _AddChip({required this.onTap, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: BorderSide(color: tokens.line2, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 12, color: tokens.ink2),
              const SizedBox(width: 3),
              Text(
                'אחר',
                style: TextStyle(
                  color: tokens.ink2,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
