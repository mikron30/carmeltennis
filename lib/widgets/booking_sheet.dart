import 'package:flutter/material.dart';
import '../booking_tokens.dart';

class SheetOption {
  final String glyph;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const SheetOption({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

Future<void> showBookingSheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<SheetOption> options,
}) {
  final tokens = BookingTokens.of(context);
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.5),
    isScrollControlled: true,
    builder: (ctx) {
      return _SheetCard(
        tokens: tokens,
        title: title,
        subtitle: subtitle,
        options: options,
      );
    },
  );
}

class _SheetCard extends StatelessWidget {
  final BookingTokens tokens;
  final String title;
  final String subtitle;
  final List<SheetOption> options;
  const _SheetCard({
    required this.tokens,
    required this.title,
    required this.subtitle,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: tokens.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: tokens.ink2, fontSize: 12),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < options.length; i++) ...[
            _OptionRow(option: options[i], tokens: tokens, isFirst: i == 0),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final SheetOption option;
  final BookingTokens tokens;
  final bool isFirst;
  const _OptionRow({required this.option, required this.tokens, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: option.onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: isFirst
                ? BorderSide.none
                : BorderSide(color: tokens.line, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.clayTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                option.glyph,
                style: TextStyle(
                  color: tokens.clayInk,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      color: tokens.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    option.subtitle,
                    style: TextStyle(color: tokens.ink2, fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(
              '›',
              style: TextStyle(
                color: tokens.ink2.withOpacity(0.5),
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
