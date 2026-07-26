import 'package:cloud_firestore/cloud_firestore.dart';

import 'booking_limits.dart';

/// Raised when a booking loses a race. Carries the Hebrew message to surface.
class BookingConflict implements Exception {
  final String message;
  BookingConflict(this.message);
  @override
  String toString() => message;
}

/// Deterministic id for one (date, court, hour) cell.
String reservationCellId(String date, int courtNumber, int hour) =>
    '${date}_${courtNumber}_$hour';

/// Trimmed, case-folded name — the single way names are compared here, so a
/// lock id and an ownership check can never disagree about who someone is.
String _normName(Object? name) => (name?.toString() ?? '').trim().toLowerCase();

/// Deterministic id for the "this user already has a booking on this date"
/// lock. Matched case-insensitively/trimmed to mirror `_Reservation.involves`.
/// Firestore ids may not contain '/'.
String dayLockId(String date, String userName) =>
    '${date}__${_normName(userName).replaceAll('/', '-')}';

/// A name that stands in for a person (so it can hold a day lock). Manager
/// bookings store a free-text label prefixed with '!' — not a member.
bool _isPerson(String name) =>
    name.trim().isNotEmpty && !name.trim().startsWith('!');

class ReservationManager {
  final FirebaseFirestore _firestore;

  // firestore is injectable so the Firestore logic here is unit-testable
  // (e.g. with fake_cloud_firestore); defaults to the live instance.
  ReservationManager({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Books one cell and claims a day lock per participant, atomically.
  ///
  /// The day lock is what actually enforces "one booking per member per date".
  /// [hasExistingReservation] alone cannot: it is a read, and the write that
  /// follows it lands on a *different* cell, so the deterministic cell id never
  /// collides. Two overlapping commits — one member double-tapping two free
  /// slots, or both partners booking at the same moment from two phones — each
  /// read "nothing booked yet" and each then wrote a different cell. That is
  /// the double-booking seen on 2026-07-21 (07:00 court 1 + 10:00 court 2).
  /// A transaction spanning the cell doc *and* both lock docs does collide, so
  /// exactly one of the two commits survives.
  ///
  /// [claimDayLocks] is false for manager bookings, which are allowed to
  /// override the one-per-day rule (unchanged behaviour).
  ///
  /// Deliberately NOT re-verified here: the weekly evening quota. It has the
  /// same read-then-write race, but across dates, and closing it means reading
  /// the week's locks — 6 extra transaction round trips per participant on
  /// exactly the busiest slots. The failure it prevents is one member getting
  /// a 4th evening in a week; the failure it causes is every evening booking
  /// taking ~3x longer. The pre-check query still catches every sequential
  /// case, which is how the quota has always worked.
  Future<void> createReservation({
    required String date,
    required int courtNumber,
    required int hour,
    required String userName,
    required String partner,
    required bool claimDayLocks,
  }) async {
    final cellId = reservationCellId(date, courtNumber, hour);
    final ref = _firestore.collection('reservations').doc(cellId);

    final lockOwners = claimDayLocks
        ? [userName, partner].where(_isPerson).toList()
        : const <String>[];
    final lockRefs = lockOwners
        .map((n) => _firestore.collection('day_locks').doc(dayLockId(date, n)))
        .toList();

    await _firestore.runTransaction((tx) async {
      // Firestore requires every read before every write.
      if ((await tx.get(ref)).exists) {
        throw BookingConflict('המשבצת נתפסה כרגע — נסה שוב');
      }
      for (var i = 0; i < lockRefs.length; i++) {
        final lock = await tx.get(lockRefs[i]);
        if (!lock.exists) continue;
        final heldCell = lock.data()?['cell'];
        // Malformed, or pointing at this very cell — which the check above
        // just proved free: stale either way, reclaim instead of blocking.
        if (heldCell is! String || heldCell == cellId) continue;
        // Self-heal: a lock whose reservation was removed outside the app
        // (admin console, delete_all_reservations.py) would otherwise bar
        // that member from the date forever. A lock only speaks for its owner
        // while the cell it points at still has that owner on it — if the cell
        // was wiped externally and then rebooked by somebody else, the lock is
        // stale and must be reclaimed, not enforced. Checking existence alone
        // would leave the member unable to book that date, permanently.
        final held =
            await tx.get(_firestore.collection('reservations').doc(heldCell));
        if (!held.exists) continue;
        final heldData = held.data();
        final owner = _normName(lockOwners[i]);
        final stillOnIt = _normName(heldData?['userName']) == owner ||
            _normName(heldData?['partner']) == owner;
        if (!stillOnIt) continue;
        throw BookingConflict('משתמש ${lockOwners[i]} כבר מוזמן');
      }
      tx.set(ref, {
        'date': date,
        'courtNumber': courtNumber,
        'hour': hour,
        'isReserved': true,
        'userName': userName.trim(),
        'partner': partner.trim(),
      });
      for (final lock in lockRefs) {
        tx.set(lock, {'cell': cellId, 'date': date, 'hour': hour});
      }
    });
  }

  /// Deletes every reservation doc occupying one cell (date+court+hour) and
  /// returns how many were removed. A cell is one logical booking, but a legacy
  /// timestamp-id doc can duplicate the deterministic date_court_hour doc on the
  /// same slot — deleting a single id would leave the straggler holding the
  /// slot. This is the authoritative half of a cancellation: it must succeed
  /// before any cancellation email goes out.
  Future<int> deleteReservationCell({
    required String date,
    required int courtNumber,
    required int hour,
  }) async {
    final cell = await _firestore
        .collection('reservations')
        .where('date', isEqualTo: date)
        .where('courtNumber', isEqualTo: courtNumber)
        .where('hour', isEqualTo: hour)
        .get();
    // Release the participants' day locks — but ONLY locks that point at this
    // cell. A participant can appear in a second (manager-created) booking on
    // the same date; deleting their lock by name alone would disarm the guard
    // on the booking they still hold.
    final cellId = reservationCellId(date, courtNumber, hour);
    final lockIds = <String>{};
    for (final d in cell.docs) {
      final data = d.data();
      for (final name in [data['userName'], data['partner']]) {
        if (name is String && _isPerson(name)) {
          lockIds.add(dayLockId(date, name));
        }
      }
    }
    final lockSnaps = await Future.wait(lockIds
        .map((id) => _firestore.collection('day_locks').doc(id).get()));
    final batch = _firestore.batch();
    for (final d in cell.docs) {
      batch.delete(d.reference);
    }
    for (final snap in lockSnaps) {
      if (snap.exists && snap.data()?['cell'] == cellId) {
        batch.delete(snap.reference);
      }
    }
    await batch.commit();
    return cell.docs.length;
  }

  Future<bool> hasExistingReservation(String userName, DateTime date) async {
    final String formattedDate = bookingDateKey(date);

    // Both roles count as a booking, and the two queries are independent —
    // awaiting them in sequence cost a needless round trip on every booking.
    final queries = await Future.wait([
      // ...where the member is the main user
      _firestore
          .collection('reservations')
          .where('date', isEqualTo: formattedDate)
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get(),
      // ...and where they are the partner
      _firestore
          .collection('reservations')
          .where('date', isEqualTo: formattedDate)
          .where('partner', isEqualTo: userName)
          .limit(1)
          .get(),
    ]);

    return queries.any((q) => q.docs.isNotEmpty);
  }

  Future<int> countWeeklyEveningReservations(
    String userName,
    DateTime date,
  ) async =>
      (await weeklyEveningCells(userName, date)).length;

  /// The cell ids (date_court_hour) of [userName]'s evening bookings in the
  /// booking week of [date] — as user or partner, deduped by cell.
  Future<Set<String>> weeklyEveningCells(
    String userName,
    DateTime date,
  ) async {
    final normalizedName = userName.trim();
    if (normalizedName.isEmpty) return {};

    final startKey = bookingDateKey(startOfBookingWeek(date));
    final endKey = bookingDateKey(endOfBookingWeek(date));
    // Dedup by cell (date_court_hour), not doc.id: a legacy timestamp-id doc and
    // the deterministic doc can both occupy one slot with different ids, and
    // counting both would over-count the quota and wrongly block a booking.
    final countedCells = <String>{};

    final snapshots = await Future.wait([
      _firestore
          .collection('reservations')
          .where('userName', isEqualTo: normalizedName)
          .get(),
      _firestore
          .collection('reservations')
          .where('partner', isEqualTo: normalizedName)
          .get(),
    ]);

    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dateValue = data['date'];
        final hour = _readHour(data['hour']);
        if (dateValue is! String || hour == null) continue;
        final inWeek = dateValue.compareTo(startKey) >= 0 &&
            dateValue.compareTo(endKey) <= 0;
        if (inWeek && isEveningQuotaHour(hour)) {
          countedCells.add('${dateValue}_${data['courtNumber']}_$hour');
        }
      }
    }

    return countedCells;
  }

  int? _readHour(Object? value) => readIntField(value);
}

/// Coerces a Firestore int field that may have drifted to String or double.
///
/// `hour` and `courtNumber` have drifted to String on some docs — enough that
/// inspect_dupes.py scans for it. A hard `as int` cast on one of those throws
/// inside the snapshot listener, which kills the stream: setState never runs,
/// `_loadingDay` never clears, and the whole grid sits on its loader. One bad
/// doc would brick booking for every member at once, so parse defensively.
int? readIntField(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
