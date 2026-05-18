# Handoff: Carmel Tennis booking grid — Young + Senior split

## Overview

Two age-targeted variants of the existing `BookingScreenV31` (Flutter, `lib/booking_screen_v31.dart`). Both share the **exact same structure, flow, data, and visual vocabulary** as the production design — the only difference is the **scale** of type and tap targets. The intent is to let the user (or an admin) pick a density mode that suits their eyesight and dexterity.

* **Young** — compact density. 14 px slot text, 48 px slot height, 13 px partner chips, 32 px icon buttons.
* **Senior** — comfortable density. 20 px slot text, 76 px slot height, 18–19 px chips, 48 px icon buttons. All tap targets ≥ 44 px.

The structure (single hero strip → horizontal partner-chip row → court header → time grid) is identical to the variant-sport-v33 design that was approved earlier; production code already implements very close to this in `lib/widgets/{hero_strip,partner_bar,recents_strip,time_grid,slot_button}.dart`. This handoff is a re-scaling exercise, **not** a structural redesign.

## About the design files

The `.html` and `.jsx` files in this bundle are **design references only**, built with React for in-browser inspection. They are not meant to be shipped or copied into the app. The implementation target is the existing **Flutter codebase** at `github.com/mikron30/carmeltennis`. Reuse the existing widgets in `lib/widgets/` and the `BookingTokens` system in `lib/booking_tokens.dart`; introduce a density flag and let it gate the dimensions described below.

## Fidelity

**High-fidelity.** Exact pixel sizes, hex colors, font weights, gaps, and tap-target dimensions are specified per variant. Match these in Flutter using `TextStyle.fontSize`, `BoxDecoration`, and `EdgeInsets` values that map 1:1 to the px values listed.

---

## Files in this bundle

* `preview.html` — open in a browser to see both variants side-by-side (light + dark).
* `variant-young.jsx` — React reference for the young variant.
* `variant-senior.jsx` — React reference for the senior variant.
* `variant-sport-v33.jsx` — the original v3.3 baseline (kept for diff reference).
* `data.jsx` — shared mock data (partner list, sample bookings, hour range, `NOW_HOUR`).
* `design-canvas.jsx` — preview-only chrome.

---

## Recommended integration approach

1. **Add a density enum** to the app — e.g. `enum BookingDensity { young, senior }`. Persist the choice on the user profile in `users_2024` (mirroring how `darkMode` and `lastFivePartners` are stored). Default to `young` (matches current production scale).

2. **Expose density via a Provider / inherited widget** at the same level `BookingTokens` is provided. Read it inside every widget that has sized constants (hero, partner bar, recents strip, time grid, slot button).

3. **Replace hard-coded sizes** with a per-density lookup. Easiest: create a `BookingDensitySpec` value class alongside `BookingTokens` and inject both:

   ```dart
   @immutable
   class BookingDensitySpec extends ThemeExtension<BookingDensitySpec> {
     final double slotMinHeight;
     final double slotFontSize;
     final double hourFontSize;
     final double chipFontSize;
     final double chipFontSizeActive;
     final double chipMinHeight;
     final double iconButton;
     final double avatarSize;
     final double heroToggleFontSize;
     final double heroMinHeight;
     // ... etc.
   }
   ```

   Provide `young` and `senior` named constructors. Then in widgets, swap every `fontSize: 11` for `fontSize: density.slotFontSize`, etc.

4. **Keep one set of widgets.** Don't fork `BookingScreenV32 Senior`. The widgets already in `lib/widgets/` are correct in structure — they just need their constants parameterised.

5. **Validate the partner row first.** It's the most visible change between the two scales: in the senior version the selected chip is significantly larger (52 px tall vs 34 px) and includes a 30 px avatar circle (vs 20 px). Get that right and the rest follows.

---

## Design tokens (unchanged — reuse current `BookingTokens`)

Both variants share the production token palette. Do **not** create new color constants.

### Light theme
| Token | Hex |
|---|---|
| `bg` | `#FFF8F3` |
| `surface` | `#FFFFFF` |
| `ink` | `#1F1715` |
| `ink2` | `#7A5447` |
| `line` | `#F0E3D4` |
| `line2` | `#E9D8C8` |
| `clay` | `#C0532B` *(taken-slot fill, selected-chip fill)* |
| `clayD` | `#A8431F` |
| `clayTint` | `#FBEADB` *(chip resting fill, preview fill)* |
| `clayInk` | `#A8431F` *(text on `clayTint`)* |
| `green` | `#1F6F4A` *(free slot fill)* |
| `greenTint` | `#E2F1E9` |
| `mine` | `#2F6473` *(teal — your booking)* |
| `mineInk` | `#FFFFFF` |
| `pastBg` | `#F7EFE7` |
| `pastInk` | `#C8B8AC` |

### Dark theme
| Token | Hex |
|---|---|
| `bg` | `#0E1413` |
| `surface` | `#161E1C` |
| `ink` | `#F1EBE4` |
| `ink2` | `#9A8A7E` (young) / `#BDAEA0` (senior — slightly brighter for legibility) |
| `line` | `#22302C` |
| `line2` | `#1A2422` (young) / `#314642` (senior) |
| `clay` | `#E06A3E` (young) / `#FF8A5C` (senior — brighter for contrast) |
| `clayD` | `#C0532B` / `#E06A3E` |
| `clayTint` | `#2A1A13` / `#3A2017` |
| `clayInk` | `#F5A884` / `#FFC8A8` |
| `green` | `#3AA674` / `#54C98C` |
| `mine` | `#2E7C86` / `#5FB5C2` *(senior uses a lighter teal so the body text on it stays readable)* |
| `mineInk` | `#FFFFFF` / `#0E1413` *(senior inverts to ink-on-light-teal)* |
| `pastBg` | `#141A19` |
| `pastInk` | `#3A4744` / `#7A8A85` |

If only one set of dark tokens is acceptable, pick the **senior** set — it has better contrast at every size.

---

## Per-widget specs

Below, every numeric value is `young / senior`. All paddings use the format `(top/bottom, left/right)` or single value if symmetric. Border radii are in px. RTL throughout.

### 1. Hero strip — `lib/widgets/hero_strip.dart`

**Strip out the `nextUp` mode and the day-of-month chip on the toggle.** The strip is now a single row: day toggle (fills available width) + ערב N/3 counter + theme button + hamburger menu.

| Property | Young | Senior |
|---|---|---|
| Min height | 44 | 64 |
| Padding | 6, 12 | 10, 16 |
| Background | `linear-gradient(180deg, clay, clayD)` | same |
| Texture overlay | horizontal lines every 23 px @ 0.06 white opacity | same |
| Gap between children | 8 | 10 |

**Day toggle** (`_DayToggle` widget):

| | Young | Senior |
|---|---|---|
| Outer bg | `rgba(0,0,0,0.22)`, radius 8 | radius 11 |
| Inner padding | 2 | 3 |
| Button font size | 13 | 18 |
| Button font weight | 700 | 800 |
| Button padding | 6×9 | 10×12 |
| Button min height | 30 | 44 |
| Active button bg | `#FFFFFF` | same |
| Active button text | `clayD` | same |
| Day-of-month sub-label | **removed** | **removed** |

Drop the day-of-month/date entirely — the toggle is just `היום` / `מחר`.

**ערב counter** (`_Cap`):

| | Young | Senior |
|---|---|---|
| Text font size | 11 | 14 |
| Text font weight | 700 | 800 |
| Text color | `#FFFFFF` | same |
| Text format | `ערב {n}/3` | same |
| Pip diameter | 6 | 9 |
| Pip gap | 3 | 5 |
| Pip color (off / on) | `rgba(255,255,255,0.28)` / `#FFFFFF` | same |
| Gap between text and pips | 5 | 7 |

**Theme button & hamburger menu** — two separate `_IconBtn` widgets next to each other:

| | Young | Senior |
|---|---|---|
| Size (square) | 32 | 48 |
| Border radius | 8 | 12 |
| Background | `rgba(0,0,0,0.22)` | same |
| Glyph font size | 14 | 22 |
| Theme glyph | `☾` (light mode) / `☀` (dark mode) | same |
| Hamburger glyph | `☰` | same |
| Theme button onTap | `onDarkModeToggle(!darkMode)` | same |
| Hamburger onTap | `onMenuTap` | same |

### 2. Partner row — `lib/widgets/recents_strip.dart`

**This replaces the existing `PartnerBar` + `RecentsStrip` pair.** The selected chip is the partner indicator — there is **no separate partner bar**. Delete `PartnerBar` from the booking screen entirely; the recents strip becomes the single source of truth.

| Property | Young | Senior |
|---|---|---|
| Container bg | `surface` | same |
| Bottom border | `1 px line` | same |
| Padding | 8, 12 | 14, 16 |
| Gap between chips | 6 | 10 |
| Horizontally scrollable | yes (hide scrollbar) | yes |
| Leading label | `עם:` 11 px 800 `ink2` | 15 px 800 `ink2` |

**Resting chip** (any partner that is not selected):

| | Young | Senior |
|---|---|---|
| Padding | 6×10 | 12×16 |
| Border radius | 8 | 12 |
| Background | `clayTint` | same |
| Text color | `clayInk` | same |
| Font size | 13 | 18 |
| Font weight | 700 | 700 |
| Min height | 34 | 52 |
| Border | `1.5 px transparent` | same |
| **Label** | first name only (e.g. `נועה` not `נועה לוי`) | same |
| Online dot (when available) | 6 px circle, color = `green`, gap to label 6 | 10 px, gap 9 |

**Active chip** (the selected partner — this IS the partner display):

| | Young | Senior |
|---|---|---|
| Background | `clay` | same |
| Border | `1.5 px clayD` | same |
| Text color | `#FFFFFF` | same |
| Font size | 14 | 19 |
| Font weight | 800 | 800 |
| Padding | 7×12 | 13×18 |
| Inner shadow | `inset 0 -2px 0 rgba(0,0,0,0.22)` | `inset 0 -3px 0 rgba(0,0,0,0.22)` |
| Avatar | 20 × 20, radius 6, bg `rgba(0,0,0,0.22)`, white initial 11 px 800 | 30 × 30, radius 9, white initial 16 px 800 |
| Gap (avatar → label) | 6 | 9 |

**Add chip (`+`)** — at the end of the scrollable row:

| | Young | Senior |
|---|---|---|
| Size (square) | 34 × 34 | 52 × 52 |
| Background | transparent | transparent |
| Border | `1.5 px dashed line2` | `2 px dashed line2` |
| Glyph | `+` centered, 18 px 700, `ink2` | 28 px 600, `ink2` |
| onTap | open existing add-partner autocomplete dialog | same |

### 3. Court header

Simple grid row with a fixed leading spacer and two centred labels (`מגרש 2`, `מגרש 1`).

| | Young | Senior |
|---|---|---|
| Grid template | `38px 1fr 1fr` | `54px 1fr 1fr` |
| Gap | 6 | 10 |
| Padding | 8, 12; bottom 4 | 12, 16; bottom 6 |
| Font size | 11 | 14 |
| Font weight | 800 | 800 |
| Letter spacing | 0.06em | 0.08em |
| Text transform | UPPERCASE | UPPERCASE |
| Color | `ink` | `ink` |

### 4. Time grid — `lib/widgets/time_grid.dart`

* Hours: **7 → 21** (15 rows). Already correct in production.
* Past hours render `סגור` (already correct).
* Busy hours (18, 19, 20) get the subtle gradient overlay already implemented (`_HourRow.busy`).

Row sizing:

| | Young | Senior |
|---|---|---|
| Grid template | `38px 1fr 1fr` | `54px 1fr 1fr` |
| Gap (court / slot) | 6 | 10 |
| Row bottom margin | 6 | 10 |
| Hour label font size | 15 | 22 |
| Hour label font weight | 800 | 800 |
| Hour label color | `ink` | `ink` |

### 5. Slot button — `lib/widgets/slot_button.dart`

| Property | Young | Senior |
|---|---|---|
| Min height | 48 | 76 |
| Border radius | 9 | 14 |
| Padding | 6×8 | 10×12 |
| Base font size | 14 | 20 |
| Base font weight | 700 | 800 |

**`SlotState.free`**

| | Young | Senior |
|---|---|---|
| Background | `green` | same |
| Text color | `#FFFFFF` | same |
| Primary label | `פנוי`, 14 px 800 | 20 px 800 |
| Diagonal hatch | white @ 0.07, 6 px stripes (keep production hatch) | same |
| Border | `1.5 px transparent` | `2 px transparent` |

**`SlotState.taken`** — *changed from production*. **Was** `surface` + `ink2` text + dashed border; **is now** clay-filled with white text, matching the production design:

| | Young | Senior |
|---|---|---|
| Background | `clay` | same |
| Text color | `#FFFFFF` | same |
| Border | none | none |
| Name format | `{a.short} · {b.short}` | same |
| Name font size | 12 | 16 |
| Name font weight | 700 | 700 |

**`SlotState.mine` / `SlotState.mineLocked`** — show the **user's own first name** prominently with the partner below. Production currently shows partner name + `·שלי` badge — replace with the two-line layout below:

| | Young | Senior |
|---|---|---|
| Background | `mine` (teal) | same |
| Text color | `mineInk` | same |
| Border | `1.5 px color-mix(mine 70% / black)` | `2 px color-mix(mine 75% / black)` |
| Inner shadow | `inset 0 -2px 0 rgba(0,0,0,0.22)` | `inset 0 -3px 0 rgba(0,0,0,0.22)` |
| Layout | column, 1 px gap | column, 2 px gap |
| Primary line | user's first name (e.g. `מיכאל`), 13 px 800 | 18 px 800 |
| Secondary line | `עם {partner.short}`, 11 px 600 @ 0.88 opacity | 14 px 600 @ 0.88 opacity |
| `mineLocked` only | add a small lock glyph after the partner name | same |

**`SlotState.preview`** — first tap on an empty slot opens this state; second tap commits the booking.

| | Young | Senior |
|---|---|---|
| Background | `clayTint` | same |
| Border | `1.5 px clay` | `2.5 px clay` |
| Text color | `clayInk` | same |
| Layout | column, 1 px gap | column, 2 px gap |
| Primary | `{hour}:00`, 14 px 800 | 20 px 800 |
| Secondary CTA | `לחצ.י שוב`, 9.5 px 800 uppercase, 0.85 opacity | `לחצ.י שוב`, 12 px 800 uppercase |
| Pulse animation | 0.9 s ease-in-out infinite; box-shadow expands 0 → 5 px @ rgba(192,83,43,0.4) → 0 | same expansion to 8 px |

**`SlotState.past`**

| | Young | Senior |
|---|---|---|
| Background | `pastBg` | same |
| Text color | `pastInk` | same |
| Border | `1.5 px dashed line2` | `2 px dashed line2` |
| Label | `סגור` | same |
| Cursor / interaction | disabled | disabled |
| Font size | 13 | 17 |

**`SlotState.pending`** — keep the production shimmer overlay, no size change beyond inheriting slot dims.

**`SlotState.failed`** — keep the production shake animation.

**`SlotState.coach`** — keep production behaviour and `מאמן` label; sizes scale with the slot dims above.

### 6. Confirm banner (replaces preview's second-tap-to-confirm shortcut UI)

Floats at the bottom of the screen, above the grid, when there is a previewed slot.

| Property | Young | Senior |
|---|---|---|
| Inset | 12 from each side & bottom | 14 |
| Background | `surface` | same |
| Border | `2 px clay` | `2.5 px clay` |
| Border radius | 14 | 18 |
| Padding | 11×13 | 16 |
| Drop shadow | `0 10px 28px rgba(0,0,0,0.22)` | `0 14px 36px rgba(0,0,0,0.22)` |
| Enter animation | slide-up 40 → 0 px + fade, 0.22 s ease-out | same |
| Info row gap | 10 | 12 |
| Avatar | 36 × 36 radius 10, clay bg, white initial 15 px 800 | 48 × 48 radius 14, 22 px 800 |
| Section label | `אישור הזמנה` 9.5 px 800 UPPERCASE `clayInk` | 11 px 800 UPPERCASE |
| Title | `{HH}:00 · מגרש {n} עם {partner.short}` 15 px 800 `ink` (the `עם …` segment is `clay`-coloured) | 18 px 800 `ink` |
| Button row gap | 8 | 10 |
| Confirm button | `אשר הזמנה`, flex 1, padding 11, radius 10, bg `clay`, text white 14 px 800, inset shadow `0 -3px 0 rgba(0,0,0,0.18)`, min-height 44 | padding 16, radius 13, 17 px 800, shadow `0 -4px 0`, min-height 56 |
| Cancel button | `בטל` (young) / `ביטול` (senior), flex 0, padding 11×16, border `1.5 px line2`, text `ink2` 14 px 800 | padding 16×22, border `2 px line2`, 17 px 800 |

### 7. Bottom sheet — cancel / taken sheet

Triggered when the user taps their own booking (cancel) or someone else's (taken — info only). Sizes:

| | Young | Senior |
|---|---|---|
| Card padding | 18 | 22, 20, 24 (top/sides/bottom) |
| Card radius | 20 (top corners) | 22 |
| Title | 18 px 800 `ink` | 22 px 800 |
| Sub | 13 px `ink2`, line-height 1.4, margin-bottom 14 | 15 px, margin-bottom 18 |
| Primary button | 13 px padding, radius 11, 15 px 800, min-height 48, bg `clay`, text white | 16 px padding, radius 13, 17 px 800, min-height 58 |
| Secondary button | same dims as primary, transparent fg `ink`, `1.5 px line2` border | same |

---

## Interactions & behavior

The behaviour is **identical** to the v31 production design. Specifically:

* **Day toggle** — switches between today and tomorrow (production already handles the after-22:00 rollover and 365-day forward window for admins; preserve all of that).
* **Partner chip tap** — `setSelectedPartner(value)`; the chip you just tapped grows and fills with clay. No separate "selected partner" display anywhere else.
* **`+` chip tap** — open the existing add-partner autocomplete dialog (`_onAddPartnerTap` in `BookingScreenV31`).
* **Free-slot first tap** — show preview state (clay-tinted slot with pulsing border + `לחצ.י שוב` CTA) AND raise the confirm banner. Preview auto-clears after 3.5 s (keep the existing `_previewTimer`).
* **Free-slot second tap on the same key** — commit the booking. Equivalent to tapping `אשר הזמנה` in the banner.
* **Banner `אשר הזמנה`** — commit the booking immediately.
* **Banner `בטל` / `ביטול`** — discard the preview, close the banner.
* **Own-slot tap** — open the cancel sheet (existing behaviour; honour the 3-hour cancel lock).
* **Someone-else's-slot tap** — open the "taken" sheet (info only for regular users; admins still get cancel).
* **Theme button** — toggle dark mode (existing `onDarkModeToggle`).
* **Hamburger menu** — open the existing app menu (existing `onMenuTap`).
* **Hour 7→21 listing**, **busy-hour gradient on 18-20**, **now-line at the current time**, and **pending/failed slot states** — all keep the production behaviour.

## State management

No new state is needed beyond what `BookingScreenV31` already has. Add:

* `BookingDensity density` — read from user profile; default `young`.

Persist alongside `darkMode` in the `users_2024` document. The `ChangeNotifier` in `app_state.dart` already handles per-user prefs; add a getter/setter following the existing pattern.

## Assets

No new assets. Glyphs (`☾`, `☀`, `☰`, `+`, `·`) are typed Unicode — render with the existing `Heebo` family.

## Open questions for the dev

1. Where should the density preference live in the menu — under the existing dark-mode toggle, as a profile-screen radio? Suggest the latter, with a short copy line: *"בחר/י את גודל הכפתורים והטקסט"*.
2. Should the density choice be exposed in the hero (next to the theme button) for quick switching, or only in the settings menu? Recommend settings-only — the hero is already dense.
3. The senior dark-mode palette diverges slightly from the production dark tokens (brighter clays, brighter mine teal). Confirm with design before shipping if you want a single shared dark palette.
