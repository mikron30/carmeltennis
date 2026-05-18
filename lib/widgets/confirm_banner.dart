import 'package:flutter/material.dart';
import '../booking_density.dart';
import '../booking_tokens.dart';

class ConfirmBanner extends StatelessWidget {
  final String partnerInitial;
  final String partnerShort;
  final int hour;
  final int courtNumber;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmBanner({
    super.key,
    required this.partnerInitial,
    required this.partnerShort,
    required this.hour,
    required this.courtNumber,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = BookingTokens.of(context);
    final spec = BookingDensitySpec.of(context);
    final hourStr = hour.toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(spec.bannerRadius),
        border: Border.all(color: tokens.clay, width: spec.bannerBorderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            offset: Offset(0, spec.bannerBorderWidth * 5),
            blurRadius: spec.bannerBorderWidth * 14,
          ),
        ],
      ),
      padding: spec.bannerPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: spec.bannerAvatarSize,
                height: spec.bannerAvatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.clay,
                  borderRadius: BorderRadius.circular(spec.bannerAvatarRadius),
                ),
                child: Text(
                  partnerInitial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: spec.bannerAvatarFontSize,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
              SizedBox(width: spec.bannerInfoGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'אישור הזמנה',
                      style: TextStyle(
                        color: tokens.clayInk,
                        fontSize: spec.bannerLabelFontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          color: tokens.ink,
                          fontSize: spec.bannerTitleFontSize,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                        children: [
                          TextSpan(text: '$hourStr:00 · מגרש $courtNumber '),
                          TextSpan(
                            text: 'עם $partnerShort',
                            style: TextStyle(color: tokens.clay),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: spec.bannerInfoGap),
          Row(
            children: [
              Expanded(
                child: _ConfirmButton(
                  tokens: tokens,
                  spec: spec,
                  onTap: onConfirm,
                ),
              ),
              SizedBox(width: spec.bannerButtonGap),
              _CancelButton(
                tokens: tokens,
                spec: spec,
                onTap: onCancel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final BookingTokens tokens;
  final BookingDensitySpec spec;
  final VoidCallback onTap;
  const _ConfirmButton({required this.tokens, required this.spec, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.clay,
      borderRadius: BorderRadius.circular(spec.bannerConfirmRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(spec.bannerConfirmRadius),
        child: Container(
          constraints: BoxConstraints(minHeight: spec.bannerConfirmMinHeight),
          padding: spec.bannerConfirmPadding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(spec.bannerConfirmRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                offset: Offset(0, -spec.bannerBorderWidth * 1.5),
                spreadRadius: 0,
                blurRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'אשר הזמנה',
            style: TextStyle(
              color: Colors.white,
              fontSize: spec.bannerConfirmFontSize,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final BookingTokens tokens;
  final BookingDensitySpec spec;
  final VoidCallback onTap;
  const _CancelButton({required this.tokens, required this.spec, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(spec.bannerConfirmRadius),
        side: BorderSide(color: tokens.line2, width: spec.bannerCancelBorderWidth),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(spec.bannerConfirmRadius),
        child: Container(
          constraints: BoxConstraints(minHeight: spec.bannerConfirmMinHeight),
          padding: spec.bannerCancelPadding,
          alignment: Alignment.center,
          child: Text(
            spec.bannerCancelLabel,
            style: TextStyle(
              color: tokens.ink2,
              fontSize: spec.bannerConfirmFontSize,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
