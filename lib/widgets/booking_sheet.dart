import 'package:flutter/material.dart';
import '../booking_density.dart';
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
  final spec = BookingDensitySpec.of(context);
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.5),
    isScrollControlled: true,
    builder: (ctx) {
      return _SheetCard(
        tokens: tokens,
        spec: spec,
        title: title,
        subtitle: subtitle,
        options: options,
      );
    },
  );
}

class _SheetCard extends StatelessWidget {
  final BookingTokens tokens;
  final BookingDensitySpec spec;
  final String title;
  final String subtitle;
  final List<SheetOption> options;
  const _SheetCard({
    required this.tokens,
    required this.spec,
    required this.title,
    required this.subtitle,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(spec.sheetCardRadius),
          topRight: Radius.circular(spec.sheetCardRadius),
        ),
      ),
      padding: spec.sheetCardPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: tokens.ink,
              fontSize: spec.sheetTitleFontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: tokens.ink2,
              fontSize: spec.sheetSubFontSize,
              height: 1.4,
            ),
          ),
          SizedBox(height: spec.sheetSubBottomMargin),
          for (int i = 0; i < options.length; i++) ...[
            _OptionRow(
              option: options[i],
              tokens: tokens,
              spec: spec,
              isFirst: i == 0,
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final SheetOption option;
  final BookingTokens tokens;
  final BookingDensitySpec spec;
  final bool isFirst;
  const _OptionRow({
    required this.option,
    required this.tokens,
    required this.spec,
    required this.isFirst,
  });

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
        constraints: BoxConstraints(minHeight: spec.sheetButtonMinHeight),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.clayTint,
                borderRadius: BorderRadius.circular(spec.sheetButtonRadius),
              ),
              child: Text(
                option.glyph,
                style: TextStyle(
                  color: tokens.clayInk,
                  fontWeight: FontWeight.w800,
                  fontSize: spec.sheetButtonFontSize - 1,
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
                      fontSize: spec.sheetButtonFontSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (option.subtitle.isNotEmpty)
                    Text(
                      option.subtitle,
                      style: TextStyle(
                        color: tokens.ink2,
                        fontSize: spec.sheetSubFontSize - 2,
                      ),
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
