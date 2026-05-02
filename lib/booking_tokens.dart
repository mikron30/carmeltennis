import 'package:flutter/material.dart';

/// Design tokens for the Variant B v3.1 booking grid redesign.
/// Mirrors the CSS variable block in design_handoff_booking_grid/variant-sport-v31.jsx.
@immutable
class BookingTokens extends ThemeExtension<BookingTokens> {
  final Color bg;
  final Color surface;
  final Color ink;
  final Color ink2;
  final Color line;
  final Color line2;
  final Color clay;
  final Color clayD;
  final Color clayTint;
  final Color clayInk;
  final Color green;
  final Color greenTint;
  final Color pastBg;
  final Color pastInk;
  final Color warn;
  final List<BoxShadow> shadowMine;

  const BookingTokens({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.ink2,
    required this.line,
    required this.line2,
    required this.clay,
    required this.clayD,
    required this.clayTint,
    required this.clayInk,
    required this.green,
    required this.greenTint,
    required this.pastBg,
    required this.pastInk,
    required this.warn,
    required this.shadowMine,
  });

  static const light = BookingTokens(
    bg: Color(0xFFFFF8F3),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF1F1715),
    ink2: Color(0xFF7A5447),
    line: Color(0xFFF0E3D4),
    line2: Color(0xFFE9D8C8),
    clay: Color(0xFFC0532B),
    clayD: Color(0xFFA8431F),
    clayTint: Color(0xFFFBEADB),
    clayInk: Color(0xFFA8431F),
    green: Color(0xFF1F6F4A),
    greenTint: Color(0xFFE2F1E9),
    pastBg: Color(0xFFF7EFE7),
    pastInk: Color(0xFFC8B8AC),
    warn: Color(0xFFFFD6A8),
    shadowMine: [
      BoxShadow(
        color: Color(0x2E000000), // rgba(0,0,0,0.18)
        offset: Offset(0, -3),
        spreadRadius: 0,
        blurRadius: 0,
      ),
    ],
  );

  static const dark = BookingTokens(
    bg: Color(0xFF0E1413),
    surface: Color(0xFF161E1C),
    ink: Color(0xFFF1EBE4),
    ink2: Color(0xFF9A8A7E),
    line: Color(0xFF22302C),
    line2: Color(0xFF1A2422),
    clay: Color(0xFFE06A3E),
    clayD: Color(0xFFC0532B),
    clayTint: Color(0xFF2A1A13),
    clayInk: Color(0xFFF5A884),
    green: Color(0xFF3AA674),
    greenTint: Color(0xFF0F2A1F),
    pastBg: Color(0xFF141A19),
    pastInk: Color(0xFF3A4744),
    warn: Color(0xFFFFB877),
    shadowMine: [
      BoxShadow(
        color: Color(0x59000000), // rgba(0,0,0,0.35)
        offset: Offset(0, -3),
        spreadRadius: 0,
        blurRadius: 0,
      ),
    ],
  );

  static BookingTokens of(BuildContext context) {
    final t = Theme.of(context).extension<BookingTokens>();
    assert(t != null, 'BookingTokens not registered on Theme');
    return t!;
  }

  @override
  BookingTokens copyWith({
    Color? bg,
    Color? surface,
    Color? ink,
    Color? ink2,
    Color? line,
    Color? line2,
    Color? clay,
    Color? clayD,
    Color? clayTint,
    Color? clayInk,
    Color? green,
    Color? greenTint,
    Color? pastBg,
    Color? pastInk,
    Color? warn,
    List<BoxShadow>? shadowMine,
  }) {
    return BookingTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      clay: clay ?? this.clay,
      clayD: clayD ?? this.clayD,
      clayTint: clayTint ?? this.clayTint,
      clayInk: clayInk ?? this.clayInk,
      green: green ?? this.green,
      greenTint: greenTint ?? this.greenTint,
      pastBg: pastBg ?? this.pastBg,
      pastInk: pastInk ?? this.pastInk,
      warn: warn ?? this.warn,
      shadowMine: shadowMine ?? this.shadowMine,
    );
  }

  @override
  BookingTokens lerp(ThemeExtension<BookingTokens>? other, double t) {
    if (other is! BookingTokens) return this;
    return BookingTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      clay: Color.lerp(clay, other.clay, t)!,
      clayD: Color.lerp(clayD, other.clayD, t)!,
      clayTint: Color.lerp(clayTint, other.clayTint, t)!,
      clayInk: Color.lerp(clayInk, other.clayInk, t)!,
      green: Color.lerp(green, other.green, t)!,
      greenTint: Color.lerp(greenTint, other.greenTint, t)!,
      pastBg: Color.lerp(pastBg, other.pastBg, t)!,
      pastInk: Color.lerp(pastInk, other.pastInk, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      shadowMine: t < 0.5 ? shadowMine : other.shadowMine,
    );
  }
}
