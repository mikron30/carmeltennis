# Handoff: Tennis Carmel — Booking Grid (B v3.1) + UX Upgrade Mockups

## Overview

This handoff covers the booking-grid screen for **Tennis Carmel**, a tennis-court booking app for a small private club (2 courts, ~12 hours of play per day, ~10 regular members). The screen lets a logged-in member:

1. See when they're playing next, at a glance.
2. Book a free slot for today or tomorrow with a chosen partner.
3. Cancel one of their own bookings (subject to a 3-hour lock).
4. Join a waitlist on a taken slot.

The recommended design is **Variant B v3.1 — Sport / clay (adaptive hero)**. It is delivered with 15 supporting **UX upgrade mockups** that each isolate a single interaction or affordance for independent evaluation, in both **light and dark** themes.

The UI is **right-to-left (Hebrew)**.

---

## About the Design Files

The files in this bundle are **design references created in HTML/JSX** — interactive prototypes showing intended look and behavior. They are **not production code to copy directly**.

The task is to **recreate these designs in the target codebase's existing environment** (React, Vue, SwiftUI, native iOS/Android, etc.) using its established patterns, component library, and design tokens. If no environment exists yet, choose the framework most appropriate for the project (a React + TypeScript + CSS-modules / Tailwind stack is the natural fit given the prototype) and implement there.

The HTML files in this bundle render directly in any modern browser — open `Booking Grid Variants.html` to see the canvas of all options side-by-side.

---

## Fidelity

**High-fidelity (hifi).** Final colors, typography, spacing, radii, shadows, and interactions are pixel-targeted. Hex values, font sizes, and dimensions in this README are exact and should be matched.

The developer should recreate the UI pixel-perfectly using the codebase's existing libraries and patterns. If the codebase has its own tokens that differ slightly from the values here, prefer the codebase tokens but flag any meaningful divergence (e.g. a different clay/orange brand color) before proceeding.

---

## Screens & Components

### Screen — Booking Grid (B v3.1)

A single full-bleed mobile screen, 380×820 design canvas (iPhone-class).

Top-to-bottom anatomy:

```
┌─────────────────────────────────┐
│  Hero (clay gradient, adaptive) │  ~72px when has next-up, ~44px when none
├─────────────────────────────────┤
│  Partner bar                    │  ~44px — avatar · name · cap · actions
├─────────────────────────────────┤
│  Recents strip (chips)          │  ~36px — horizontally scrollable
├─────────────────────────────────┤
│  Court header (מגרש 2 / מגרש 1) │  ~28px — sticky-feeling label row
├─────────────────────────────────┤
│  Time grid (1fr, scrollable)    │  flex:1 — rows of [hour][court2][court1]
└─────────────────────────────────┘
```

#### 1. Hero (adaptive)

The most important design move. Two states:

**Has-next state (~72px, two rows)** — when the user has an upcoming booking on the selected day:
- Padding: `11px 16px 12px`
- Background: `linear-gradient(180deg, #c0532b 0%, #a8431f 100%)` (light theme) — clay gradient
- Texture overlay: horizontal repeating-linear-gradient of faint white lines, 22px stripe + 1px highlight, 6% opacity
- **Row 1 (top, margin-bottom 6px):**
  - Day label `היום`/`מחר` — 24px / weight 800 / letter-spacing -0.02em / line-height 1 / white
  - Date `27.4` — 11px / weight 600 / letter-spacing 0.04em / opacity 0.78
- **Row 2 (bottom):**
  - Next-up line: `[הבא] 18:00 עם נועה ל. · מגרש 2` — eyebrow `הבא` is 10px / weight 700 / uppercase / letter-spacing 0.06em / opacity 0.72; the rest is 12px / weight 500 / opacity 0.96; hour and partner-name are bolded (weight 800).
  - Day toggle on the right: pill with two segments (היום / מחר), each showing day label + tiny weather temp (e.g. `28°`); active segment has white background and clay-d text. Background of pill: `rgba(0,0,0,0.22)`, padding 2px, radius 7px, segment padding `5px 9px`, font 11px weight 700.

**No-next state (~44px, one row)** — when there is no upcoming booking:
- Padding: `9px 16px 10px`
- Same gradient + texture
- Single row: day label (18px / weight 800) + `· אין הזמנה` (11px / weight 500 / opacity 0.78) + day toggle on the right
- This is the V3 collapsed strip — the design rule is **absence doesn't earn pixels**.

The transition between states is `transition: padding 0.18s ease`.

The theme toggle is **not** in the hero (it was in V3 — moved out because settings-tier controls don't belong in a content header).

#### 2. Partner bar

- Padding `8px 16px`, background `--surface` (`#ffffff` light / `#161e1c` dark), border-bottom `1px solid --line`
- Layout: `[avatar][name][cap counter][pips][actions]` flex row, gap 10px
- Avatar: 28×28, radius 8, `--clay-tint` bg, `--clay-ink` text, weight 800 / 12px, single Hebrew initial
- Name: 13px / weight 700 / `--ink`, ellipsizes
- Cap counter: `ערב 2/3` — 10.5px / weight 600 / `--ink-2`, the `2` bolded `--ink`. Counts the user's evening (18–20h) bookings across both days against a cap of 3.
- Pips: three 6×6 dots, gap 2px — filled `--clay` for used, `--line` for empty
- Actions (right side): three 28×28 icon buttons, radius 7, `--clay-tint` bg, `--clay-ink` text. Glyphs:
  - `↻` — "כמו בשבוע שעבר" (same as last week — restores the most recent recurring booking)
  - `↔` — "החלף שותפ.ה" (cycle to next partner in PARTNERS list)
  - **Theme toggle** — 24×24, transparent bg, 1px border `--line-2`, `--ink-2`. Glyph: `☾` in light, `☀` in dark. On hover: clay-tint bg, clay-ink text.

#### 3. Recents strip

- Padding `7px 16px`, gap 5px, background `--surface`, border-bottom `1px solid --line`
- Horizontally scrollable, scrollbar hidden
- Each chip: padding `4px 10px`, radius 5, font 11px / weight 600
  - Default: `--clay-tint` bg, `--clay-ink` text
  - Active (selected partner): `--ink` bg, `--bg` text
  - Available indicator: 5×5 green dot before the name, when partner has no clashing booking on selected day
- Order: ranked by recency × frequency of past games together

#### 4. Court header

- Grid: `36px 1fr 1fr` (gutter for hour column, then court 2 then court 1 — RTL ordering puts court 2 on the right visually)
- Padding `8px 16px 4px`, background `--bg`
- Labels: `מגרש 2`, `מגרש 1` — 10px / weight 800 / uppercase / letter-spacing 0.06em / `--ink`, centered

#### 5. Time grid

- `flex: 1; overflow-y: auto`, padding `0 16px 12px`, position relative
- Each row is a grid `36px 1fr 1fr`, gap 5px, margin-bottom 4px
- Busy rows (hours with high booking density: 13, 18, 19) get a subtle clay gradient ::before overlay (`rgba(192,83,43,0.05) → 0.10` 90deg, `rgba(224,106,62,0.06 → 0.13)` in dark)
- Hour cell: 12px / weight 700 / `--ink-2` / tabular-nums, with a tiny `●` flame icon (7px, `--clay`) inline when the hour is "busy"
- **Slot cell (38px min-height, radius 7, font 11px weight 600, transition transform 0.08s)**:
  - `.free` — `--green` bg, white text, faint diagonal hatching ::before overlay; the actionable state.
  - `.preview` — clay-tint bg, clay-ink text, 2px dashed clay border, 1s ease-in-out pulse animation; shown for 3.5s after first tap.
  - `.pending` — same as free but with a sweeping shimmer ::after overlay (1.2s loop); shown for 700ms after the second tap commits.
  - `.failed` — clay bg, white text, 0.4s shake keyframe animation; shown on simulated rollback (~8% probability).
  - `.taken` — surface bg, `--ink-2` text, 1.5px `--line` border. Hover reveals a 9px clay "wait" hint label (waitlist affordance).
  - `.mine` — clay bg, white text, inset `0 -3px 0 rgba(0,0,0,0.18)` bottom shadow; appends `·שלי` (=mine) at 9px / weight 800 / opacity 0.85.
  - `.mine.locked` — same as `.mine` but appends `·נעול` (=locked) instead. Locks engage when the slot is `now_hour < hour <= now_hour + 3` on today.
  - `.past` — `--past-bg`, `--past-ink`, 1.5px `--line` border, `cursor: not-allowed`. Hours before now on today.
- A `.s31-now` divider spans the full row when the current hour line falls between rows: 9.5px / weight 800 / uppercase / `--clay`, with horizontal 2px `--clay` lines to either side at 50% opacity.

#### 6. Bottom-sheet (cancel / waitlist)

Triggered when tapping `.mine` (cancel) or `.taken` (waitlist).
- Backdrop: `rgba(31,23,21,0.5)`, 2px backdrop-blur, fade-in 0.18s
- Card: white (`--surface`), full width, radius `20px 20px 0 0`, padding `18px 20px 22px`, slide-up 0.22s from `translateY(40px)`
- Title (h3): 18px / weight 800
- Sub: 12px / `--ink-2`, margin-bottom 14px
- Each option row: 10px vertical padding, 1px `--line` top-border (except first); 32×32 icon tile (radius 10, clay-tint bg, clay-ink text, 14px weight 800) + label block (b: 13px/700/--ink; small: 11px/`--ink-2`)

#### 7. Toast

- Position: absolute, `left:16px; right:16px; bottom:14px`
- Padding `10px 14px`, radius 10, font 12px / weight 700, centered
- Variants: `.good` = `--green` bg + white text · `.warn` = `--clay` bg + white text · `.info` = `--ink` bg + `--bg` text
- Animation: 0.2s slide-up + fade in; auto-dismisses after 2.4s

---

### UX Upgrade Mockups (15 tiles)

Each mockup is a 320×280 standalone tile with a small caption (`mux-cap`) and an isolated demonstration of one design move. They are presentation-only — meant to be reviewed individually so each can be shipped or skipped on its own merit.

Tile chrome (shared `MuxTile` component):
- 320×280, radius 18, 1px `--line-2` border, `--bg` background
- Cap row: padding `10px 14px 6px`, border-bottom `1px solid --line`
  - Eyebrow: 9px / weight 800 / uppercase / letter-spacing 0.12em / `--clay-ink`
  - Title (b): 13px / weight 700 / `--ink`
  - Sub (p): 10.5px / `--ink-2` / line-height 1.35
- Body: padding `12px 14px`, flex column gap 8px

The 15 mockups are:

| # | Name | What it shows |
|---|---|---|
| 3 | **Confirm-on-second-tap** | Preview state on first tap; commit on second. No modal. |
| 4 | **Pending + failure** | Shimmer while writing, shake + toast on rollback. Never silent. |
| 13 | **Live cap counter** | Always-visible 0/3 evenings counter so users see the limit before hitting it. |
| 11 | **Busy-hour heat** | Faint clay shading + ● flame on rows that book up — no copy needed. |
| 9 | **Weather strip per day** | Live temp baked into day toggle; warn color (`--warn`) when >27°. |
| 5+8 | **Smart partner picker** | Recents ranked by frequency × recency; green dot = available today. |
| 14 | **3h cancel lock** | Locked slots show a `·נעול` badge; tap reveals the rule instead of silent fail. |
| 15 | **Waitlist** | Tap a taken slot → join waitlist or propose alternative. Auto-books on cancel. |
| 18 | **Recurring bookings** | "Set once, plays every week." Toggle off any time. |
| 2 | **Find-me-a-slot** | Type intent ("evening with נועה") → matching slots highlight. |
| 7 | **Invite — don't pre-confirm** | Slot stays pending until partner accepts. Fixes ghost bookings. |
| 16 | **Pre-game checklist** | 1h-before push: court, partner, weather, water. |
| 17 | **Post-game rating** | 2-tap feedback feeds suggestion algorithm and surfaces bad-fit pairings. |
| 12 | **Friends online** | Tiny presence indicator for spontaneous matches. |
| 20 | **Live next-up hero** | Header-level answer to "when am I playing next?" — no tap required. (This is folded into v3.1's hero.) |

Each tile renders in both **light** and **dark** themes via a `data-theme="dark"` attribute on the root, swapping the CSS variable block. The dark palette is documented in **Design Tokens** below.

---

## Interactions & Behavior

### Booking flow (B v3.1)

1. User taps a `.free` slot → it transitions to `.preview` with a clay dashed border and 1s pulse. A 3.5s timer starts; if it fires, preview clears.
2. User taps the same slot again within 3.5s → preview clears, slot transitions to `.pending` (clay-shimmer overlay), 700ms.
3. With ~92% probability the booking commits → slot becomes `.mine`, toast `הוזמן` (good).
4. With ~8% probability it fails → slot flashes `.failed` (shake), toast `נכשל — נסה שוב` (warn). Slot reverts to `.free`.
5. Partner cap: `book()` does not enforce evening cap directly in this prototype — the cap counter is informational. **In production, enforce the 3-evening cap server-side and return a structured error → toast `הגעת לתקרת 3 ערבים השבוע`.**

### Cancel flow

1. User taps a `.mine` slot.
2. If `now_hour < hour <= now_hour + 3` on today → slot is locked. Toast: `לא ניתן לבטל פחות מ-3 שעות לפני`. No sheet.
3. Otherwise → bottom-sheet opens with options: cancel (calls `book(court, hour)` which toggles), keep, or "find me a replacement slot" (mockup-only).

### Waitlist flow

1. User taps a `.taken` slot.
2. Bottom-sheet opens with options: join waitlist, propose alternative time, dismiss.
3. On confirm → toast `נוספת לרשימת המתנה` (good).
4. **In production:** when the underlying booking is cancelled, auto-book the first waitlist entry and push-notify them.

### Day switch

- `setDay('today' | 'tomorrow')` — instant. The grid re-renders. `myNext` recomputes. Hero may flip between has-next and no-next states.

### Partner switch

- Recents chip tap → `setPartner(id)`.
- Cycle button (`↔`) → next id in `PARTNERS` round-robin.
- Restore button (`↻`) → mockup-only; in production should restore the last-used recurring template.

### Theme toggle

- Persists in `localStorage('booking-theme')` (recommended; not implemented in prototype).
- Flips `data-theme` attribute on `.s31-root`. All visual changes are pure CSS-variable swaps — no re-render.

### Animations & transitions

| Element | Animation |
|---|---|
| Hero state change | `transition: padding 0.18s ease` |
| Slot tap | `transform: scale(0.97)` on `:active`, 0.08s ease |
| Preview slot | `s3pulse` 1s ease-in-out infinite |
| Pending slot | `muxshim` 1.2s linear infinite (sweeping highlight) |
| Failed slot | `s3shake` 0.4s ease-out (4-keyframe horizontal shake ±4px) |
| Toast in | `s3slide` 0.2s ease-out (translateY 8px → 0, opacity 0 → 1) |
| Sheet backdrop | `s3fade` 0.18s |
| Sheet card | `s3up` 0.22s (translateY 40px → 0) |

### Hit targets

All interactive elements ≥ 28px on the short side; slot cells are 38px tall. Recents chips are 24px tall but have ~10px horizontal padding making them comfortable in practice.

---

## State Management

The prototype uses a single hook `useBookingState()` (in `data.jsx`) that returns:

```ts
{
  day: 'today' | 'tomorrow';
  setDay(day): void;
  partner: string;          // id from PARTNERS
  setPartner(id): void;
  bookings: {               // nested map
    [day]: { [court: 1|2]: { [hour: number]: { a: id, b: id } } }
  };
  slotAt(court, hour): Booking | null;
  isMine(slot): boolean;
  isPast(hour): boolean;    // true only when day==='today' && hour < NOW_HOUR
  book(court, hour): void;  // toggles: free → mine, mine → free, taken → warn
  toast: { msg, kind, id } | null;
  showToast(msg, kind): void;
  partnerObj(id): Partner;
  HOURS: number[];          // [10..21]
  NOW_HOUR: 13;
  NOW_MINUTE: 42;
  PARTNERS: Partner[];
  ME: Partner;
}
```

The `VariantSportV31` component additionally manages local UI state:
- `theme` — 'light' | 'dark', initialized from `initialTheme` prop
- `preview` — `{ key, court, hour } | null`
- `pending` — slot key string | null
- `failed` — slot key string | null
- `sheet` — `{ kind: 'cancel'|'waitlist', court, hour, slot } | null`

**For production**, replace the in-memory `bookings` state with:
- Realtime subscription (Firestore / Supabase / WebSocket) so other members' bookings appear without refresh.
- Optimistic updates: render `.pending` immediately, reconcile with server response. Match the simulated rollback behavior (shake + toast) on real failures.
- Server-enforced rules: 3-evening cap, 3-hour cancel lock, can't double-book yourself, can't book past hours.

---

## Design Tokens

### Colors — Light theme

| Token | Hex | Use |
|---|---|---|
| `--bg` | `#fff8f3` | Page background (warm off-white) |
| `--surface` | `#ffffff` | Card / bar surfaces |
| `--ink` | `#1f1715` | Primary text |
| `--ink-2` | `#7a5447` | Secondary text |
| `--line` | `#f0e3d4` | Hairline borders |
| `--line-2` | `#e9d8c8` | Slightly stronger borders (frame, taken slots) |
| `--clay` | `#c0532b` | Brand primary |
| `--clay-d` | `#a8431f` | Brand primary deep (gradient bottom) |
| `--clay-tint` | `#fbeadb` | Brand tinted surface (chips, avatar bg) |
| `--clay-ink` | `#a8431f` | Text/icon on clay-tint |
| `--green` | `#1f6f4a` | Free / success |
| `--green-tint` | `#e2f1e9` | Success tinted surface |
| `--past-bg` | `#f7efe7` | Past-hour slot bg |
| `--past-ink` | `#c8b8ac` | Past-hour slot text |
| `--warn` | `#ffd6a8` | Heat warning (weather >27°) |

### Colors — Dark theme

| Token | Hex | Use |
|---|---|---|
| `--bg` | `#0e1413` | Page background (deep teal-black) |
| `--surface` | `#161e1c` | Card / bar surfaces |
| `--ink` | `#f1ebe4` | Primary text |
| `--ink-2` | `#9a8a7e` | Secondary text |
| `--line` | `#22302c` | Hairline borders |
| `--line-2` | `#1a2422` | Frame border |
| `--clay` | `#e06a3e` | Brand primary (lifted for contrast) |
| `--clay-d` | `#c0532b` | Brand primary deep |
| `--clay-tint` | `#2a1a13` | Brand tinted surface (dark variant) |
| `--clay-ink` | `#f5a884` | Text on clay-tint |
| `--green` | `#3aa674` | Free / success (lifted) |
| `--green-tint` | `#0f2a1f` | Success tinted surface |
| `--past-bg` | `#141a19` | Past-hour slot bg |
| `--past-ink` | `#3a4744` | Past-hour slot text |
| `--warn` | `#ffb877` | Heat warning |

Shadow tokens:
- Light `--shadow-mine`: `inset 0 -3px 0 rgba(0,0,0,0.18)`
- Dark `--shadow-mine`: `inset 0 -3px 0 rgba(0,0,0,0.35)`

### Typography

- **Family:** Heebo (Google Fonts), weights 300, 400, 500, 600, 700, 800. Fallback `system-ui, sans-serif`.
- **Direction:** RTL throughout (`<html dir="rtl">`).
- **Size scale used:**
  - 9px — eyebrow microtext, mine/locked badge, weather temp
  - 9.5px — now-line label
  - 10px — court header, "next-up" eyebrow
  - 10.5px — sub-text, cap counter
  - 11px — most secondary text (chips, recents, slots, toggle)
  - 12px — slot/sheet body, hour labels, next-up content
  - 13px — partner name, sheet option title
  - 18px — collapsed-hero day, sheet h3
  - 24px — expanded-hero day
- **Letter-spacing:** -0.02em on big day labels; +0.04–0.12em (uppercase eyebrows).
- **Line-height:** 1 for big labels, 1.2 for slot text, 1.35 for sub-paragraphs.

### Spacing

The prototype uses ad-hoc spacing rather than a strict scale. Common values: 2, 3, 4, 5, 6, 8, 10, 12, 14, 16, 18, 20, 22 px.
For a production scale, **4px base, with steps at 4, 8, 12, 16, 20, 24** maps cleanly onto everything except the few odd values (5, 6, 7, 11) which can be rounded to nearest 4 without visible damage.

### Radii

- 5px — recents chips, toggle inner segment
- 6px — theme toggle
- 7px — slots, day toggle outer pill, action icon buttons
- 8px — partner-bar avatar
- 10px — toast, sheet option icon
- 18px — UX mockup tiles
- `20px 20px 0 0` — bottom-sheet card top corners
- 28px — full screen frame
- 50% — pips, theme toggle in V3 (deprecated)

### Borders

- Hairlines: 1px solid `--line`
- Slot borders: 1.5px solid `--line` (taken/past) or 2px dashed `--clay` (preview)
- Frame: 1px solid `--line-2`

---

## Assets

- **Fonts:** Heebo (Google Fonts) — already loaded via `<link>` in the host HTML.
- **Icons:** Used inline as Unicode glyphs / Hebrew text in this prototype. For production, replace with the codebase's icon library:
  - `↻` → `restore`/`refresh` icon
  - `↔` → `swap`/`shuffle` icon
  - `☾` / `☀` → `moon`/`sun` icons
  - `●` (busy-hour flame) → `fire`/`trending-up` icon at small scale, or keep as a styled dot
- **Images:** None. Avatars are letterforms only.

---

## Files in This Bundle

- `Booking Grid Variants.html` — host page that renders the design canvas with all variants
- `design-canvas.jsx` — the canvas component (`DCSection`, `DCArtboard`) used to lay out side-by-side options. Not part of the deliverable; demo chrome only.
- `data.jsx` — `useBookingState` hook + sample data (PARTNERS, ME, HOURS, initial bookings). **The shape here is the contract for production.**
- `variant-sport-v31.jsx` — **the recommended design (B v3.1).** This is the primary file to recreate.
- `variant-sport-v3.jsx` — earlier version with the over-collapsed ~44px hero, kept for diff context.
- `variant-sport-v2.jsx` — earlier version with the over-large ~150px hero, kept for diff context.
- `upgrade-mockups.jsx` — all 15 UX upgrade mockup tiles + `MuxTile` chrome + shared `muxStyles`.

You can ignore: `variant-sport.jsx`, `variant-editorial.jsx`, `variant-quiet.jsx`, `variant-dark.jsx`, `Audit.html`, `Booking Grid V2.html`, `data-v2.jsx` — these are earlier explorations not selected for production.

## Implementation order (suggested)

1. Stand up the data model from `data.jsx` against your backend.
2. Build `VariantSportV31` shell: hero, partner bar, recents, court header, time grid.
3. Wire booking flow with optimistic updates (preview → pending → mine).
4. Add bottom-sheet for cancel + waitlist.
5. Add theme switch with `data-theme` and persist in localStorage.
6. Layer in upgrade-mockup features in priority order: **#13 cap counter** and **#14 cancel lock** are highest-value and lowest-risk; **#4 pending/failure** is required for any networked implementation; **#15 waitlist** and **#18 recurring** are server-side heavy; **#2 find-me-a-slot**, **#16 checklist**, **#17 rating**, **#12 online**, **#11 busy heat**, **#9 weather** can be sequenced after launch.
