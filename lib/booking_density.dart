import 'package:flutter/material.dart';

enum BookingDensity { young, senior, compact }

BookingDensity bookingDensityFromString(String? raw) {
  if (raw == 'senior') return BookingDensity.senior;
  if (raw == 'compact') return BookingDensity.compact;
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
  final double nowDividerFontSize;

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

  // Layout strategy: when true, TimeGrid auto-distributes vertical space
  // across all 15 hour rows so the whole day fits without scrolling.
  final bool fitAllHours;

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
    required this.nowDividerFontSize,
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
    this.fitAllHours = false,
  });

  static const BookingDensitySpec young = BookingDensitySpec(
    heroMinHeight: 40,
    heroPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
    heroGap: 7,
    dayToggleFontSize: 12,
    dayToggleFontWeight: FontWeight.w700,
    dayBtnPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    dayBtnMinHeight: 28,
    dayToggleOuterRadius: 7,
    dayToggleInnerPadding: 2,
    capFontSize: 13,
    capFontWeight: FontWeight.w800,
    pipDiameter: 7,
    pipGap: 4,
    capPipGap: 6,
    iconBtnSize: 28,
    iconBtnRadius: 7,
    iconBtnGlyphSize: 13,
    recentsPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
    recentsGap: 5,
    recentsLeadingFontSize: 10,
    chipPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 9),
    chipRadius: 7,
    chipFontSize: 12,
    chipMinHeight: 30,
    chipFontSizeActive: 13,
    chipPaddingActive: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
    avatarSize: 18,
    avatarRadius: 5,
    avatarFontSize: 10,
    avatarLabelGap: 5,
    onlineDotSize: 5,
    onlineDotGap: 5,
    addChipSize: 30,
    addChipBorderWidth: 1.5,
    addChipGlyphSize: 16,

    hourColumnWidth: 32,
    gridGap: 5,
    courtHeaderPadding: EdgeInsets.fromLTRB(10, 6, 10, 3),
    courtHeaderFontSize: 10,
    courtHeaderLetterSpacing: 0.6,
    gridRowMargin: EdgeInsets.only(bottom: 5),
    hourLabelFontSize: 13,
    nowDividerFontSize: 9.5,
    slotMinHeight: 42,
    slotRadius: 8,
    slotPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 7),
    slotFontSize: 13,
    slotFontWeight: FontWeight.w700,
    slotTakenFontSize: 11,
    slotMinePrimaryFontSize: 12,
    slotMineSecondaryFontSize: 10,
    slotMineGap: 1,
    slotPreviewPrimaryFontSize: 13,
    slotPreviewSecondaryFontSize: 9,
    slotPreviewBorderWidth: 1.5,
    slotPreviewPulseMaxSpread: 4,
    slotFreeBorderWidth: 1.5,
    slotMineBorderWidth: 1.5,
    slotPastBorderWidth: 1.5,
    slotPastFontSize: 12,
    bannerInset: 10,
    bannerBorderWidth: 2,
    bannerRadius: 12,
    bannerPadding: EdgeInsets.symmetric(vertical: 9, horizontal: 11),
    bannerInfoGap: 8,
    bannerAvatarSize: 32,
    bannerAvatarRadius: 9,
    bannerAvatarFontSize: 13,
    bannerLabelFontSize: 9,
    bannerTitleFontSize: 13,
    bannerButtonGap: 7,
    bannerConfirmPadding: EdgeInsets.all(9),
    bannerConfirmRadius: 9,
    bannerConfirmFontSize: 13,
    bannerConfirmMinHeight: 40,
    bannerCancelPadding: EdgeInsets.symmetric(vertical: 9, horizontal: 14),
    bannerCancelBorderWidth: 1.5,
    bannerCancelLabel: 'בטל',
    sheetCardPadding: EdgeInsets.all(16),
    sheetCardRadius: 18,
    sheetTitleFontSize: 16,
    sheetSubFontSize: 12,
    sheetSubBottomMargin: 12,
    sheetButtonRadius: 10,
    sheetButtonFontSize: 14,
    sheetButtonMinHeight: 44,
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
    nowDividerFontSize: 15,
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

  // Compact: shrinks slot rows so all 15 hours fit on screen without
  // scrolling. Hero and recents sized similar to young; the slot grid
  // distributes available vertical space across its rows.
  static const BookingDensitySpec compact = BookingDensitySpec(
    heroMinHeight: 36,
    heroPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
    heroGap: 7,
    dayToggleFontSize: 12,
    dayToggleFontWeight: FontWeight.w700,
    dayBtnPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    dayBtnMinHeight: 26,
    dayToggleOuterRadius: 7,
    dayToggleInnerPadding: 2,
    capFontSize: 13,
    capFontWeight: FontWeight.w800,
    pipDiameter: 7,
    pipGap: 4,
    capPipGap: 6,
    iconBtnSize: 26,
    iconBtnRadius: 7,
    iconBtnGlyphSize: 13,
    recentsPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
    recentsGap: 5,
    recentsLeadingFontSize: 10,
    chipPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 9),
    chipRadius: 7,
    chipFontSize: 12,
    chipMinHeight: 28,
    chipFontSizeActive: 13,
    chipPaddingActive: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
    avatarSize: 18,
    avatarRadius: 5,
    avatarFontSize: 10,
    avatarLabelGap: 5,
    onlineDotSize: 5,
    onlineDotGap: 5,
    addChipSize: 28,
    addChipBorderWidth: 1.5,
    addChipGlyphSize: 15,
    hourColumnWidth: 28,
    gridGap: 4,
    courtHeaderPadding: EdgeInsets.fromLTRB(10, 4, 10, 2),
    courtHeaderFontSize: 10,
    courtHeaderLetterSpacing: 0.6,
    gridRowMargin: EdgeInsets.only(bottom: 2),
    hourLabelFontSize: 12,
    nowDividerFontSize: 9.5,
    slotMinHeight: 1, // Expanded rows distribute height; min just prevents 0
    slotRadius: 7,
    slotPadding: EdgeInsets.symmetric(vertical: 2, horizontal: 6),
    slotFontSize: 12,
    slotFontWeight: FontWeight.w700,
    slotTakenFontSize: 11,
    slotMinePrimaryFontSize: 11,
    slotMineSecondaryFontSize: 9,
    slotMineGap: 0,
    slotPreviewPrimaryFontSize: 12,
    slotPreviewSecondaryFontSize: 9,
    slotPreviewBorderWidth: 1.5,
    slotPreviewPulseMaxSpread: 4,
    slotFreeBorderWidth: 1.5,
    slotMineBorderWidth: 1.5,
    slotPastBorderWidth: 1.5,
    slotPastFontSize: 11,
    bannerInset: 10,
    bannerBorderWidth: 2,
    bannerRadius: 12,
    bannerPadding: EdgeInsets.symmetric(vertical: 9, horizontal: 11),
    bannerInfoGap: 8,
    bannerAvatarSize: 32,
    bannerAvatarRadius: 9,
    bannerAvatarFontSize: 13,
    bannerLabelFontSize: 9,
    bannerTitleFontSize: 13,
    bannerButtonGap: 7,
    bannerConfirmPadding: EdgeInsets.all(9),
    bannerConfirmRadius: 9,
    bannerConfirmFontSize: 13,
    bannerConfirmMinHeight: 40,
    bannerCancelPadding: EdgeInsets.symmetric(vertical: 9, horizontal: 14),
    bannerCancelBorderWidth: 1.5,
    bannerCancelLabel: 'בטל',
    sheetCardPadding: EdgeInsets.all(16),
    sheetCardRadius: 18,
    sheetTitleFontSize: 16,
    sheetSubFontSize: 12,
    sheetSubBottomMargin: 12,
    sheetButtonRadius: 10,
    sheetButtonFontSize: 14,
    sheetButtonMinHeight: 44,
    fitAllHours: true,
  );

  static BookingDensitySpec of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<BookingDensityScope>();
    if (scope == null) return young;
    switch (scope.density) {
      case BookingDensity.senior:
        return senior;
      case BookingDensity.compact:
        return compact;
      case BookingDensity.young:
        return young;
    }
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
