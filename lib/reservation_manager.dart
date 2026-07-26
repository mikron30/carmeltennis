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

/// Deterministic id for the "this user already has a booking on this date"
/// lock. Matched case-insensitively/trimmed to mirror `_Reservation.involves`.
/// Firestore ids may not contain '/'.
String dayLockId(String date, String userName) =>
    '${date}__${userName.trim().toLowerCase().replaceAll('/', '-')}';

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
  /// For evening-quota hours the transaction ALSO re-verifies the weekly quota
  /// from the week's day-lock docs: the quota pre-check query has the same
  /// read-then-write race as the day rule, just across dates ("you book
  /// Tuesday, I'll book Thursday" from two phones). Reading the week's locks
  /// puts them in the transaction's read set, so a racing evening commit on
  /// ANY day of the week forces a retry and gets recounted.
  /// [eveningBaseline] carries each participant's already-committed evening
  /// cells from the pre-check query — it covers lock-less rows (bookings made
  /// before day locks existed, manager-created bookings); the lock scan covers
  /// the race. Union of both, deduped by cell id, is the true count.
  Future<void> createReservation({
    required String date,
    required int courtNumber,
    required int hour,
    required String userName,
    required String partner,
    required bool claimDayLocks,
    Map<String, Set<String>> eveningBaseline = const {},
  }) async {
    final cellId = reservationCellId(date, courtNumber, hour);
    final ref = _firestore.collection('reservations').doc(cellId);

    final lockOwners = claimDayLocks
        ? [userName, partner].where(_isPerson).toList()
        : const <String>[];
    final lockRefs = lockOwners
        .map((n) => _firestore.collection('day_locks').doc(dayLockId(date, n)))
        .toList();
    // Other days of the booking week — the booking date itself is resolved by
    // the day-lock check (its lock is either absent or reclaimed-as-stale).
    final quotaDates = claimDayLocks && isEveningQuotaHour(hour)
        ? _weekDateKeys(date).where((d) => d != date).toList()
        : const <String>[];

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
        // that member from the date forever. Block only while the cell it
        // points at is genuinely occupied.
        final held =
            await tx.get(_firestore.collection('reservations').doc(heldCell));
        if (!held.exists) continue;
        throw BookingConflict('משתמש ${lockOwners[i]} כבר מוזמן');
      }
      for (final owner in lockOwners) {
        if (quotaDates.isEmpty) break;
        final cells = <String>{...(eveningBaseline[owner] ?? const {})};
        for (final d in quotaDates) {
          final lock = await tx
              .get(_firestore.collection('day_locks').doc(dayLockId(d, owner)));
          final data = lock.data();
          final h = data?['hour'];
          final c = data?['cell'];
          if (h is int && c is String && isEveningQuotaHour(h)) cells.add(c);
        }
        if (cells.length >= kWeeklyEveningQuota) {
          throw BookingConflict(
            'ל-$owner כבר יש $kWeeklyEveningQuota הזמנות השבוע בשעות 18:00, 19:00 ו-20:00',
          );
        }
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

  /// The 7 date keys of the booking week containing [date] (a yyyy-MM-dd key).
  List<String> _weekDateKeys(String date) {
    final start = startOfBookingWeek(DateTime.parse(date));
    return [
      for (var i = 0; i < 7; i++)
        bookingDateKey(DateTime(start.year, start.month, start.day + i)),
    ];
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

    // Query for reservations where the current user is the main user
    final mainUserQuery = await _firestore
        .collection('reservations')
        .where('date', isEqualTo: formattedDate)
        .where('userName', isEqualTo: userName)
        .get();

    // Query for reservations where the current user is the partner
    final partnerQuery = await _firestore
        .collection('reservations')
        .where('date', isEqualTo: formattedDate)
        .where('partner', isEqualTo: userName)
        .get();

    // If either query returns any documents, the user has an existing reservation
    return mainUserQuery.docs.isNotEmpty || partnerQuery.docs.isNotEmpty;
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

  int? _readHour(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
