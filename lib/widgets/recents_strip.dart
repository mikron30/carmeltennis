import 'package:flutter/material.dart';
import '../booking_tokens.dart';

class RecentPartner {
  final String label;
  final String value;
  const RecentPartner({required this.label, required this.value});
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
    final itemCount = recents.length + (onAddTap != null ? 1 : 0);

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
            for (int i = 0; i < itemCount; i++) ...[
              Expanded(
                child: i == recents.length
                    ? _AddChip(onTap: onAddTap!, tokens: tokens)
                    : _Chip(
                        partner: recents[i],
                        active: selected == recents[i].value,
                        tokens: tokens,
                        onTap: () => onSelect(recents[i].value),
                      ),
              ),
              if (i < itemCount - 1) const SizedBox(width: 5),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final RecentPartner partner;
  final bool active;
  final BookingTokens tokens;
  final VoidCallback onTap;

  const _Chip({
    required this.partner,
    required this.active,
    required this.tokens,
    required this.onTap,
  });

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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Center(
            child: Text(
              partner.label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'אחר',
                  style: TextStyle(
                    color: tokens.ink2,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
