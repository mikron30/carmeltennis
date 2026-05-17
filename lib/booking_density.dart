import 'package:flutter/material.dart';

enum BookingDensity { young, senior }

BookingDensity bookingDensityFromString(String? raw) {
  if (raw == 'senior') return BookingDensity.senior;
  return BookingDensity.young;
}

@immutable
class BookingDensitySpec {
  // Hero strip
  final double heroMinHeight;
  final EdgeInsets heroPadding;
  final double heroGap;
  final double dayToggleFontSize;
  final FontWeight dayToggleFontWeight;
  final EdgeInsets dayBtnPadding;
  final double dayBtnMinHeight;
  final double dayToggleOuterRadius;
  final double dayToggleInnerPadding;
  final double capFontSize;
  final FontWeight capFontWeight;
  final double pipDiameter;
  final double pipGap;
  final double capPipGap;
  final double iconBtnSize;
  final double iconBtnRadius;
  final double iconBtnGlyphSize;

  // Recents strip (partner row)
  final EdgeInsets recentsPadding;
  final double recentsGap;
  final double recentsLeadingFontSize;
  final EdgeInsets chipPadding;
  final double chipRadius;
  final double chipFontSize;
  final double chipMinHeight;
  final double chipFontSizeActive;
  final EdgeInsets chipPaddingActive;
  final double avatarSize;
  final double avatarRadius;
  final double avatarFontSize;
  final double avatarLabelGap;
  final double onlineDotSize;
  final double onlineDotGap;
  final double addChipSize;
  final double addChipBorderWidth;
  final double addChipGlyphSize;

  // Court header + time grid
  final double hourColumnWidth;
  final double gridGap;
  final EdgeInsets courtHeaderPadding;
  final double courtHeaderFontSize;
  final double courtHeaderLetterSpacing;
  final EdgeInsets gridRowMargin;
  final double hourLabelFontSize;

  // Slot button
  final double slotMinHeight;
  final double slotRadius;
  final EdgeInsets slotPadding;
  final double slotFontSize;
  final FontWeight slotFontWeight;
  final double slotTakenFontSize;
  final double slotMinePrimaryFontSize;
  final double slotMineSecondaryFontSize;
  final double slotMineGap;
  final double slotPreviewPrimaryFontSize;
  final double slotPreviewSecondaryFontSize;
  final double slotPreviewBorderWidth;
  final double slotPreviewPulseMaxSpread;
  final double slotFreeBorderWidth;
  final double slotMineBorderWidth;
  final double slotPastBorderWidth;
  final double slotPastFontSize;

  // Confirm banner
  final double bannerInset;
  final double bannerBorderWidth;
  final double bannerRadius;
  final EdgeInsets bannerPadding;
  final double bannerInfoGap;
  final double bannerAvatarSize;
  final double bannerAvatarRadius;
  final double bannerAvatarFontSize;
  final double bannerLabelFontSize;
  final double bannerTitleFontSize;
  final double bannerButtonGap;
  final EdgeInsets bannerConfirmPadding;
  final double bannerConfirmRadius;
  final double bannerConfirmFontSize;
  final double bannerConfirmMinHeight;
  final EdgeInsets bannerCancelPadding;
  final double bannerCancelBorderWidth;
  final String bannerCancelLabel;

  // Booking sheet (cancel / taken-info)
  final EdgeInsets sheetCardPadding;
  final double sheetCardRadius;
  final double sheetTitleFontSize;
  final double sheetSubFontSize;
  final double sheetSubBottomMargin;
  final double sheetButtonRadius;
  final double sheetButtonFontSize;
  final double sheetButtonMinHeight;

  const BookingDensitySpec({
    required this.heroMinHeight,
    required this.heroPadding,
    required this.heroGap,
    required this.dayToggleFontSize,
    required this.dayToggleFontWeight,
    required this.dayBtnPadding,
    required this.dayBtnMinHeight,
    required this.dayToggleOuterRadius,
    required this.dayToggleInnerPadding,
    required this.capFontSize,
    required this.capFontWeight,
    required this.pipDiameter,
    required this.pipGap,
    required this.capPipGap,
    required this.iconBtnSize,
    required this.iconBtnRadius,
    required this.iconBtnGlyphSize,
    required this.recentsPadding,
    required this.recentsGap,
    required this.recentsLeadingFontSize,
    required this.chipPadding,
    required this.chipRadius,
    required this.chipFontSize,
    required this.chipMinHeight,
    required this.chipFontSizeActive,
    required this.chipPaddingActive,
    required this.avatarSize,
    required this.avatarRadius,
    required this.avatarFontSize,
    required this.avatarLabelGap,
    required this.onlineDotSize,
    required this.onlineDotGap,
    required this.addChipSize,
    required this.addChipBorderWidth,
    required this.addChipGlyphSize,
    required this.hourColumnWidth,
    required this.gridGap,
    required this.courtHeaderPadding,
    required this.courtHeaderFontSize,
    required this.courtHeaderLetterSpacing,
    required this.gridRowMargin,
    required this.hourLabelFontSize,
    required this.slotMinHeight,
    required this.slotRadius,
    required this.slotPadding,
    required this.slotFontSize,
    required this.slotFontWeight,
    required this.slotTakenFontSize,
    required this.slotMinePrimaryFontSize,
    required this.slotMineSecondaryFontSize,
    required this.slotMineGap,
    required this.slotPreviewPrimaryFontSize,
    required this.slotPreviewSecondaryFontSize,
    required this.slotPreviewBorderWidth,
    required this.slotPreviewPulseMaxSpread,
    required this.slotFreeBorderWidth,
    required this.slotMineBorderWidth,
    required this.slotPastBorderWidth,
    required this.slotPastFontSize,
    required this.bannerInset,
    required this.bannerBorderWidth,
    required this.bannerRadius,
    required this.bannerPadding,
    required this.bannerInfoGap,
    required this.bannerAvatarSize,
    required this.bannerAvatarRadius,
    required this.bannerAvatarFontSize,
    required this.bannerLabelFontSize,
    required this.bannerTitleFontSize,
    required this.bannerButtonGap,
    required this.bannerConfirmPadding,
    required this.bannerConfirmRadius,
    required this.bannerConfirmFontSize,
    required this.bannerConfirmMinHeight,
    required this.bannerCancelPadding,
    required this.bannerCancelBorderWidth,
    required this.bannerCancelLabel,
    required this.sheetCardPadding,
    required this.sheetCardRadius,
    required this.sheetTitleFontSize,
    required this.sheetSubFontSize,
    required this.sheetSubBottomMargin,
    required this.sheetButtonRadius,
    required this.sheetButtonFontSize,
    required this.sheetButtonMinHeight,
  });

  static const BookingDensitySpec young = BookingDensitySpec(
    heroMinHeight: 44,
    heroPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
    heroGap: 8,
    dayToggleFontSize: 13,
    dayToggleFontWeight: FontWeight.w700,
    dayBtnPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 9),
    dayBtnMinHeight: 30,
    dayToggleOuterRadius: 8,
    dayToggleInnerPadding: 2,
    capFontSize: 11,
    capFontWeight: FontWeight.w700,
    pipDiameter: 6,
    pipGap: 3,
    capPipGap: 5,
    iconBtnSize: 32,
    iconBtnRadius: 8,
    iconBtnGlyphSize: 14,
    recentsPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    recentsGap: 6,
    recentsLeadingFontSize: 11,
    chipPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
    chipRadius: 8,
    chipFontSize: 13,
    chipMinHeight: 34,
    chipFontSizeActive: 14,
    chipPaddingActive: EdgeInsets.symmetric(vertical: 7, horizontal: 12),
    avatarSize: 20,
    avatarRadius: 6,
    avatarFontSize: 11,
    avatarLabelGap: 6,
    onlineDotSize: 6,
    onlineDotGap: 6,
    addChipSize: 34,
    addChipBorderWidth: 1.5,
    addChipGlyphSize: 18,
    hourColumnWidth: 38,
    gridGap: 6,
    courtHeaderPadding: EdgeInsets.fromLTRB(12, 8, 12, 4),
    courtHeaderFontSize: 11,
    courtHeaderLetterSpacing: 0.66,
    gridRowMargin: EdgeInsets.only(bottom: 6),
    hourLabelFontSize: 15,
    slotMinHeight: 48,
    slotRadius: 9,
    slotPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    slotFontSize: 14,
    slotFontWeight: FontWeight.w700,
    slotTakenFontSize: 12,
    slotMinePrimaryFontSize: 13,
    slotMineSecondaryFontSize: 11,
    slotMineGap: 1,
    slotPreviewPrimaryFontSize: 14,
    slotPreviewSecondaryFontSize: 9.5,
    slotPreviewBorderWidth: 1.5,
    slotPreviewPulseMaxSpread: 5,
    slotFreeBorderWidth: 1.5,
    slotMineBorderWidth: 1.5,
    slotPastBorderWidth: 1.5,
    slotPastFontSize: 13,
    bannerInset: 12,
    bannerBorderWidth: 2,
    bannerRadius: 14,
    bannerPadding: EdgeInsets.symmetric(vertical: 11, horizontal: 13),
    bannerInfoGap: 10,
    bannerAvatarSize: 36,
    bannerAvatarRadius: 10,
    bannerAvatarFontSize: 15,
    bannerLabelFontSize: 9.5,
    bannerTitleFontSize: 15,
    bannerButtonGap: 8,
    bannerConfirmPadding: EdgeInsets.all(11),
    bannerConfirmRadius: 10,
    bannerConfirmFontSize: 14,
    bannerConfirmMinHeight: 44,
    bannerCancelPadding: EdgeInsets.symmetric(vertical: 11, horizontal: 16),
    bannerCancelBorderWidth: 1.5,
    bannerCancelLabel: 'בטל',
    sheetCardPadding: EdgeInsets.all(18),
    sheetCardRadius: 20,
    sheetTitleFontSize: 18,
    sheetSubFontSize: 13,
    sheetSubBottomMargin: 14,
    sheetButtonRadius: 11,
    sheetButtonFontSize: 15,
    sheetButtonMinHeight: 48,
  );

  static const BookingDensitySpec senior = BookingDensitySpec(
    heroMinHeight: 64,
    heroPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    heroGap: 10,
    dayToggleFontSize: 18,
    dayToggleFontWeight: FontWeight.w800,
    dayBtnPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    dayBtnMinHeight: 44,
    dayToggleOuterRadius: 11,
    dayToggleInnerPadding: 3,
    capFontSize: 14,
    capFontWeight: FontWeight.w800,
    pipDiameter: 9,
    pipGap: 5,
    capPipGap: 7,
    iconBtnSize: 48,
    iconBtnRadius: 12,
    iconBtnGlyphSize: 22,
    recentsPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
    recentsGap: 8,
    recentsLeadingFontSize: 13,
    chipPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    chipRadius: 10,
    chipFontSize: 14,
    chipMinHeight: 40,
    chipFontSizeActive: 15,
    chipPaddingActive: EdgeInsets.symmetric(vertical: 9, horizontal: 14),
    avatarSize: 24,
    avatarRadius: 7,
    avatarFontSize: 13,
    avatarLabelGap: 7,
    onlineDotSize: 7,
    onlineDotGap: 7,
    addChipSize: 40,
    addChipBorderWidth: 2,
    addChipGlyphSize: 22,
    hourColumnWidth: 32,
    gridGap: 10,
    courtHeaderPadding: EdgeInsets.fromLTRB(16, 12, 16, 6),
    courtHeaderFontSize: 14,
    courtHeaderLetterSpacing: 1.12,
    gridRowMargin: EdgeInsets.only(bottom: 10),
    hourLabelFontSize: 18,
    slotMinHeight: 76,
    slotRadius: 14,
    slotPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    slotFontSize: 20,
    slotFontWeight: FontWeight.w800,
    slotTakenFontSize: 16,
    slotMinePrimaryFontSize: 18,
    slotMineSecondaryFontSize: 14,
    slotMineGap: 2,
    slotPreviewPrimaryFontSize: 20,
    slotPreviewSecondaryFontSize: 12,
    slotPreviewBorderWidth: 2.5,
    slotPreviewPulseMaxSpread: 8,
    slotFreeBorderWidth: 2,
    slotMineBorderWidth: 2,
    slotPastBorderWidth: 2,
    slotPastFontSize: 17,
    bannerInset: 14,
    bannerBorderWidth: 2.5,
    bannerRadius: 18,
    bannerPadding: EdgeInsets.all(16),
    bannerInfoGap: 12,
    bannerAvatarSize: 48,
    bannerAvatarRadius: 14,
    bannerAvatarFontSize: 22,
    bannerLabelFontSize: 11,
    bannerTitleFontSize: 18,
    bannerButtonGap: 10,
    bannerConfirmPadding: EdgeInsets.all(16),
    bannerConfirmRadius: 13,
    bannerConfirmFontSize: 17,
    bannerConfirmMinHeight: 56,
    bannerCancelPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 22),
    bannerCancelBorderWidth: 2,
    bannerCancelLabel: 'ביטול',
    sheetCardPadding: EdgeInsets.fromLTRB(20, 22, 20, 24),
    sheetCardRadius: 22,
    sheetTitleFontSize: 22,
    sheetSubFontSize: 15,
    sheetSubBottomMargin: 18,
    sheetButtonRadius: 13,
    sheetButtonFontSize: 17,
    sheetButtonMinHeight: 58,
  );

  static BookingDensitySpec of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<BookingDensityScope>();
    if (scope == null) return young;
    return scope.density == BookingDensity.senior ? senior : young;
  }

  static BookingDensity densityOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<BookingDensityScope>();
    return scope?.density ?? BookingDensity.young;
  }
}

class BookingDensityScope extends InheritedWidget {
  final BookingDensity density;

  const BookingDensityScope({
    super.key,
    required this.density,
    required super.child,
  });

  @override
  bool updateShouldNotify(BookingDensityScope oldWidget) =>
      oldWidget.density != density;
}
