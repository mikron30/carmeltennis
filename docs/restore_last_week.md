# Restore-Last-Week Button (`↻`) — Spec

Status: **Not implemented.** Button is commented out in `lib/widgets/partner_bar.dart` and the `_onRestoreLastWeek` handler is commented out in `lib/booking_screen_v31.dart`. The `PartnerBar.onRestoreTap` field is now optional (nullable) so the call site can omit it.

## Goal

One-tap re-create the same booking the member made on the same weekday last week — same partner, same hour, same court when possible. Saves the cycle of "open recents → tap partner → find the time slot → confirm" for the most common case (people who play with the same person at the same time every week).

## What the button currently doesn't do

Before being commented out, `_onRestoreLastWeek` just set `_selectedPartner` to `lastFivePartners.last` (the **oldest** entry in the recents list, not actually the previous week's partner). It didn't query any historical reservation, didn't preselect a time slot, and didn't do anything court-related. The Hebrew tooltip "כמו בשבוע שעבר" was misleading.

## Real behavior

On tap:

1. Compute `lastWeekDate = _selectedDate - 7 days`.
2. Query Firestore for the member's reservation on that date:
   ```dart
   final me = widget.myUserName;
   final dateKey = _fmt(lastWeekDate);
   final snap = await FirebaseFirestore.instance
     .collection('reservations')
     .where('date', isEqualTo: dateKey)
     .where(Filter.or(
       Filter('userName', isEqualTo: me),
       Filter('partner', isEqualTo: me),
     ))
     .limit(1)
     .get();
   ```
3. If no match → toast `אין הזמנה משבוע שעבר` (info), do nothing else.
4. If match found:
   - Read the partner (the field that isn't the member).
   - Set `_selectedPartner = partner`.
   - Compute the target slot `(hour, court)` from the doc.
   - **Validate** the slot is bookable on the *current* `_selectedDate`:
     - Slot is currently `.free` (not taken by someone else).
     - `BookingWindow.isOpenFor(_selectedDate)` passes.
     - `ReservationManager.hasExistingReservation(me, _selectedDate)` is false.
     - 3-evening cap not exceeded.
   - If validation passes → set `_preview` to that cell so the user sees a preview-pulse with the second-tap-to-confirm flow already armed (don't auto-book; one-tap commits without confirmation feel scary).
   - If validation fails → toast the specific reason (`המשבצת תפוסה`, `מחוץ לחלון ההזמנה`, `כבר יש לך הזמנה ביום זה`, `הגעת לתקרת 3 ערבים השבוע`).
5. If multiple matches (member booked twice last week) → take the one closest to `_selectedDate`'s current view (e.g., if user is viewing tomorrow, prefer the future slot). Edge case; unlikely.

## Edge cases

- **Day-of-week shift**: if the user is viewing a day other than today, "last week" should mean "the same weekday a week before _selectedDate", not "today minus 7". Code already does this since it uses `_selectedDate - 7`.
- **Court no longer exists**: last week was a holiday with 3 courts, this week is a normal day with 2. If the historical court number is > current `_numberOfCourts`, fall back to the highest available court.
- **Coach line**: never restore into a `.coach` slot. Skip and warn.
- **Manager mode**: same flow, but skip the cap and existing-reservation gates (consistent with how managers bypass these elsewhere).

## Re-enabling steps

1. In `lib/widgets/partner_bar.dart` line ~102, uncomment:
   ```dart
   _IconBtn(glyph: '↻', tooltip: 'כמו בשבוע שעבר', onTap: onRestoreTap!, tokens: tokens),
   const SizedBox(width: 3),
   ```
2. (Optional) Make `onRestoreTap` non-nullable again in the same file. Or leave it nullable so callers can opt out.
3. In `lib/booking_screen_v31.dart`, replace the commented `_onRestoreLastWeek` stub with the real implementation per the algorithm above. It needs to be `async` since it queries Firestore.
4. In the `PartnerBar(...)` call inside `build()`, pass `onRestoreTap: _onRestoreLastWeek`.
5. Consider gating the button visibility on `widget.myUserName != null` — there's nothing meaningful to restore for an unsigned user.

## Verification (after implementation)

1. Book a slot today with partner X at 19:00 court 1. Wait 7 days.
2. Open the app → tap `↻` → preview-pulse appears at court 1 / 19:00 with partner X preselected.
3. Tap once more to confirm → slot flips to `.mine`, email sent.
4. Tap `↻` on a date where you didn't book last week → info toast `אין הזמנה משבוע שעבר`.
5. Tap `↻` when last week's slot is now taken by someone else → warn toast `המשבצת תפוסה`, but partner is still preselected (so the user can pick a different slot manually).
6. Tap `↻` on a Friday when last week's slot was also a Friday at the coach hour → warn toast, no preview.
