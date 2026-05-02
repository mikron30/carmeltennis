# Waitlist Feature — Spec

Status: **Not implemented.** UI scaffolding exists but is commented out in `lib/booking_screen_v31.dart` (`_openWaitlistSheet` and the corresponding tap handler under the non-manager branch). Re-enable both when implementing.

## Goal

When a member taps a slot that is already booked by someone else (`.taken` state), let them join a waitlist for that exact (date, hour, court). When the original booking is cancelled, the first person on the waitlist is auto-promoted to the booking and notified.

This avoids the current dead-end on taken slots and recovers value from late cancellations (which today just free the slot for whoever happens to refresh first).

## User flow

1. Member taps a `.taken` slot. Bottom sheet opens with title `המשבצת תפוסה`, subtitle showing the two players, and one primary option:
   - `⏱  הוסף לרשימת המתנה  · נודיע אם מתפנה`
   - `✕  סגור`
2. On confirm:
   - Write a waitlist entry to Firestore.
   - Toast `נוספת לרשימת המתנה` (good).
   - The slot's `.taken` tile shows a tiny clay subscript `· ממתין` (pending) in the corner so the member can see they're queued. Counter form: `· ממתינים N` if there's more than one and the viewer is one of them.
3. When the underlying reservation is cancelled (by the booker or by a manager):
   - Auto-promote the first waitlist entry into a real reservation (insert into `reservations`, delete the waitlist entry).
   - Email the promoted member via the existing `sendReservationEmails` path with a new `isPromotion: true` flag (subject prefix `מ"רשימת המתנה" – `).
   - Optionally also email the rest of the waitlist that the slot is no longer available (so they can rebook elsewhere). Defer to v2.

## Data model

New collection: **`waitlists`**, one doc per waitlist entry.

```
waitlists/{auto-id}
  date: '2026-05-08'                         // yyyy-MM-dd, same format as reservations
  hour: 19                                   // int
  court: 1                                   // db court number (not UI index)
  userName: 'נועה לוי'                        // Hebrew display name (matches reservations.userName)
  partner: 'אודי אש'                          // partner name (must be paired at queue time)
  email: 'noa@example.com'                   // for notification — denormalised, avoids a UserManager lookup at promote-time
  partnerEmail: 'udi@example.com'            // promoted partner also needs to be notified
  position: 1                                // 1-based, recomputed on enqueue/dequeue (or just use createdAt for ordering)
  createdAt: Timestamp.now()
```

Index: composite on `(date asc, hour asc, court asc, createdAt asc)` — required for the "first in queue" query.

## Validation rules at enqueue time

Reuse the existing booking validators from `lib/reservation_manager.dart` and `lib/booking_screen_v31.dart::_validateSync`:
- `BookingWindow.isOpenFor(date)` — same D-2 22:00 gate as a normal booking.
- `ReservationManager.hasExistingReservation(userName, date)` — can't waitlist on a date you're already booked.
- `kEveningHours.contains(hour) && _usedEvenings >= 3` — can't waitlist on an evening slot if you've hit the 3-evening cap.
- Partner is selected (`_selectedPartner != null`) — same as a normal booking.
- No duplicate waitlist entry for the same `(date, hour, court, userName)`.
- The slot must currently be in `.taken` state at enqueue time (sanity check against the live snapshot).

If any check fails, throw `_BookingValidationError` and surface as a warn toast. Same pattern as `_commitBooking`.

## Promotion logic

Trigger: when a `reservations` doc is **deleted** for a `(date, hour, court)` combo.

Two implementation options:

### A. Cloud Function (recommended)

```typescript
// functions/src/promoteWaitlist.ts
export const onReservationDeleted = onDocumentDeleted(
  'reservations/{id}',
  async (event) => {
    const { date, hour, court } = event.data!.data();
    const queue = await db.collection('waitlists')
      .where('date', '==', date)
      .where('hour', '==', hour)
      .where('court', '==', court)
      .orderBy('createdAt', 'asc')
      .limit(1)
      .get();
    if (queue.empty) return;
    const entry = queue.docs[0];
    const e = entry.data();

    // Re-validate at promote-time (the cap might have filled in the meantime).
    // ... reuse the same checks via Admin SDK ...

    await db.runTransaction(async (tx) => {
      tx.set(db.collection('reservations').doc(), {
        date: e.date, hour: e.hour, court: e.court,
        userName: e.userName, partner: e.partner,
      });
      tx.delete(entry.ref);
    });

    // Email both parties via the existing template, with isPromotion: true.
  });
```

Why a Cloud Function: avoids race conditions (two clients seeing the cancelled slot simultaneously), runs even if no client is currently listening, and keeps the promotion atomic.

### B. Client-side fallback (only if no Cloud Functions)

In `_BookingScreenV31State`, listen to `reservations.snapshots()` for `documentChanges` of type `removed`. The first client to react acquires a `waitlist_locks/{date}_{hour}_{court}` doc via a transaction (TTL ~10s) and runs the promotion. Brittle — if no one has the app open, nothing happens. Treat as a stopgap only.

## Email integration

Add to `lib/email_service.dart::sendReservationEmails`:
- New optional bool parameter `isPromotion`.
- New subject prefix: `מ"רשימת המתנה" – אישור הזמנה`.
- New HTML body block that explains "התפנתה משבצת שהיית ברשימת ההמתנה שלה והוזמנה אוטומטית".

If we add the "no-longer-available" notification for non-promoted waitlisters, that's a third template variant (`isWaitlistCancelled: true`).

## Firestore rules additions

Append to whatever rules the project uses:

```
match /waitlists/{id} {
  allow read: if request.auth != null;
  allow create: if request.auth != null
                 && request.resource.data.email == request.auth.token.email;
  allow delete: if request.auth != null
                 && (resource.data.email == request.auth.token.email
                     || /* manager check */);
  // No update — entries are immutable.
}
```

Cloud Function runs as admin and bypasses rules.

## UI changes when re-enabling

1. Uncomment the `_openWaitlistSheet` call site in `lib/booking_screen_v31.dart` (currently inside the `else` branch under `if (mine) { … } else { … }` for non-manager taps on `.taken`).
2. Uncomment the `_openWaitlistSheet` method body further down in the same file.
3. Replace the toast-only `onTap` with a real enqueue:
   ```dart
   onTap: () async {
     Navigator.of(context).pop();
     try {
       await _enqueueWaitlist(r);
       _toast.show(context, 'נוספת לרשימת המתנה', kind: ToastKind.good);
     } on _BookingValidationError catch (e) {
       _toast.show(context, e.message, kind: ToastKind.warn);
     } catch (_) {
       _toast.show(context, 'נכשל — נסה שוב', kind: ToastKind.warn);
     }
   },
   ```
4. Add a new `kWaiting` decoration variant to `lib/widgets/slot_button.dart` (or pass a `secondaryLabel` to the existing `.taken` state) so the queue indicator `· ממתין` / `· ממתינים N` shows on slots the viewer is queued for.
5. Subscribe to `waitlists` for the selected day in `_BookingScreenV31State` so the queue indicator updates live without a refresh — same pattern as `_selectedDaySub`.

## Out of scope (v2+)

- Propose-alternative-time flow (suggest a nearby free slot instead of waiting).
- Push notifications (no mobile push wiring exists in the project today; email is the only notifier).
- Per-user waitlist quota.
- "Notify me if anyone cancels in this date range" — looser, calendar-wide watch.

## Verification (after implementation)

1. Tap a taken slot as a non-manager → sheet appears → confirm → Firestore `waitlists/<id>` exists → slot tile shows `· ממתין`.
2. Have the original booker cancel → within seconds, the waitlisted user becomes the booker (their slot flips to `.mine`) and they receive a promotion email.
3. Try waitlisting on a slot for a date you already have a booking on → warn toast, no doc created.
4. Try waitlisting on an evening slot when `_usedEvenings == 3` → warn toast, no doc created.
5. Try double-enqueueing the same slot → warn toast, no duplicate doc.
6. Manager cancels someone else's slot → still triggers promotion.
