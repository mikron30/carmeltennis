import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'booking_limits.dart';
import 'booking_tokens.dart';
import 'booking_window.dart';
import 'email_service.dart';
import 'holiday_courts.dart';
import 'israel_time.dart';
import 'reservation_manager.dart';
import 'user_manager.dart';
import 'widgets/booking_sheet.dart';
import 'widgets/hero_strip.dart';
import 'widgets/recents_strip.dart';
import 'widgets/slot_button.dart';
import 'widgets/time_grid.dart';
import 'widgets/toast.dart';

const String _adminBookingLabel = 'הזמנת מנהל';

class BookingScreenV31 extends StatefulWidget {
  final bool isManager;
  final String? myUserName;
  final List<String> lastFivePartners;
  final List<String> allUsers;
  final bool darkMode;
  final ValueChanged<bool> onDarkModeToggle;
  final VoidCallback onMenuTap;

  const BookingScreenV31({
    super.key,
    required this.isManager,
    required this.myUserName,
    required this.lastFivePartners,
    required this.allUsers,
    required this.darkMode,
    required this.onDarkModeToggle,
    required this.onMenuTap,
  });

  @override
  State<BookingScreenV31> createState() => _BookingScreenV31State();
}

class _BookingScreenV31State extends State<BookingScreenV31> {
  late DateTime _selectedDate;
  String? _selectedPartner;
  int _numberOfCourts = 2;
  String _holidayType = 'רגיל';

  StreamSubscription<QuerySnapshot>? _selectedDaySub;
  StreamSubscription<QuerySnapshot>? _weekEveningSub;
  DateTime? _subscribedWeekStart;
  List<_Reservation> _selectedDayReservations = [];
  Map<int, Map<int, _Reservation>> _selectedDayByCell = {};
  int _myWeeklyEveningCount = 0;

  String? _pendingKey;
  String? _failedKey;
  bool _loadingDay = false;

  final _toast = ToastController();
  final _resManager = ReservationManager();

  @override
  void initState() {
    super.initState();
    final now = IsraelTime.now();
    _selectedDate = _effectiveToday(now);
    _selectedPartner = _firstSelectablePartner(widget.lastFivePartners);
    _refreshCourtsThenLoad();
  }

  @override
  void didUpdateWidget(covariant BookingScreenV31 oldWidget) {
    super.didUpdateWidget(oldWidget);
    final initialPartner = _firstSelectablePartner(widget.lastFivePartners);
    if (oldWidget.lastFivePartners != widget.lastFivePartners &&
        _selectedPartner == null &&
        initialPartner != null) {
      setState(() => _selectedPartner = initialPartner);
    }
  }

  @override
  void dispose() {
    _selectedDaySub?.cancel();
    _weekEveningSub?.cancel();
    _toast.dismiss();
    super.dispose();
  }

  DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
  DateTime _effectiveToday(DateTime now) {
    final base = _midnight(now);
    return now.hour >= 22 ? _addDays(base, 1) : base;
  }

  DateTime _effectiveTomorrow(DateTime now) {
    final base = _midnight(now);
    return now.hour >= 22 ? _addDays(base, 2) : _addDays(base, 1);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  String _fmt(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<void> _refreshCourtsThenLoad() async {
    if (!mounted) return;
    // Drop the stream and stale cell data immediately so taps during the
    // holiday-fetch window can't operate on the previous day's reservations.
    _selectedDaySub?.cancel();
    _selectedDaySub = null;
    setState(() {
      _loadingDay = true;
      _selectedDayReservations = <_Reservation>[];
      _selectedDayByCell = <int, Map<int, _Reservation>>{};
      _pendingKey = null;
      _failedKey = null;
    });
    final type = await getHolidayType(_selectedDate);
    final courts = numberOfCourtsFor(_selectedDate, type);
    if (!mounted) return;
    setState(() {
      _holidayType = type;
      _numberOfCourts = courts;
    });
    _resubscribe();
  }

  void _resubscribe() {
    _selectedDaySub?.cancel();

    final selectedKey = _fmt(_selectedDate);
    _selectedDaySub = FirebaseFirestore.instance
        .collection('reservations')
        .where('date', isEqualTo: selectedKey)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final list = snap.docs.map(_Reservation.fromDoc).toList();
      setState(() {
        _selectedDayReservations = list;
        _selectedDayByCell = _buildByCell(list);
        _loadingDay = false;
      });
    });

    final me = widget.myUserName ?? '';
    if (me.isEmpty) {
      _weekEveningSub?.cancel();
      _weekEveningSub = null;
      _subscribedWeekStart = null;
      _myWeeklyEveningCount = 0;
      return;
    }

    // Today↔tomorrow toggles within the same booking week shouldn't recycle
    // the week-evening listener — keep the live subscription if the week
    // boundaries haven't moved.
    final weekStart = startOfBookingWeek(_selectedDate);
    final existingWeek = _subscribedWeekStart;
    if (_weekEveningSub != null &&
        existingWeek != null &&
        _isSameDay(existingWeek, weekStart)) {
      return;
    }
    _weekEveningSub?.cancel();
    _subscribedWeekStart = weekStart;
    final weekStartKey = bookingDateKey(weekStart);
    final weekEndKey = bookingDateKey(endOfBookingWeek(_selectedDate));
    _weekEveningSub = FirebaseFirestore.instance
        .collection('reservations')
        .where('date', isGreaterThanOrEqualTo: weekStartKey)
        .where('date', isLessThanOrEqualTo: weekEndKey)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final counted = <String>{};
      for (final doc in snap.docs) {
        final r = _Reservation.fromDoc(doc);
        if (isEveningQuotaHour(r.hour) && r.involves(me)) {
          counted.add(r.docId);
        }
      }
      setState(() => _myWeeklyEveningCount = counted.length);
    });
  }

  HeroDay get _heroDay {
    final today = _effectiveToday(IsraelTime.now());
    return _isSameDay(_selectedDate, today) ? HeroDay.today : HeroDay.tomorrow;
  }

  int get _usedEvenings {
    final me = widget.myUserName ?? '';
    if (me.isEmpty) return 0;
    return _myWeeklyEveningCount.clamp(0, kWeeklyEveningQuota);
  }

  Map<int, Map<int, _Reservation>> _buildByCell(List<_Reservation> list) {
    final byCell = <int, Map<int, _Reservation>>{};
    for (final r in list) {
      (byCell[r.courtNumber] ??= {})[r.hour] = r;
    }
    return byCell;
  }

  bool _partnerHasReservationOnSelectedDay(String name) {
    return _selectedDayReservations.any((r) => r.involves(name));
  }

  bool _isLocked(int hour, DateTime now) {
    final viewingToday = _isSameDay(_selectedDate, _effectiveToday(now));
    if (!viewingToday) return false;
    final reservationDt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
    );
    return reservationDt.difference(now).inMinutes < 180;
  }

  bool _isPast(int hour, DateTime now) {
    final viewingToday = _isSameDay(_selectedDate, _effectiveToday(now));
    if (!viewingToday) return false;
    final reservationDt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
    );
    return reservationDt.difference(now).inMinutes < 30;
  }

  SlotData _resolveSlot(int courtUiIndex, int hour, DateTime now) {
    // courtUiIndex 0 = leftmost = highest court number = numberOfCourts.
    final dbCourtNumber = _numberOfCourts - courtUiIndex;
    final reservation =
        _selectedDayByCell[dbCourtNumber]?[hour] ?? _Reservation.empty();

    final isCoach = isCoachSlot(
      date: _selectedDate,
      hour: hour,
      courtUiIndex: courtUiIndex,
      holidayType: _holidayType,
    );
    if (isCoach) {
      return const SlotData(state: SlotState.coach, primaryLabel: 'מאמן');
    }

    final key = '$courtUiIndex-$hour';
    final isPending = _pendingKey == key;
    final isFailed = _failedKey == key;

    if (reservation.hour >= 0) {
      final mine =
          widget.myUserName != null && reservation.involves(widget.myUserName!);
      final customLabel = _customBookingLabel(reservation.partner);
      if (customLabel != null) {
        return SlotData(
          state: mine
              ? (_isLocked(hour, now) ? SlotState.mineLocked : SlotState.mine)
              : SlotState.taken,
          primaryLabel: customLabel,
          onTap: () => _handleTap(courtUiIndex, hour),
        );
      }
      if (mine) {
        final state =
            _isLocked(hour, now) ? SlotState.mineLocked : SlotState.mine;
        final partner = reservation.userName == widget.myUserName
            ? reservation.partner
            : reservation.userName;
        return SlotData(
          state: state,
          primaryLabel: _firstName(widget.myUserName!),
          secondaryLabel: _shortName(_displayPartner(partner)),
          onTap: () => _handleTap(courtUiIndex, hour),
        );
      }
      final pa = _shortName(_displayPartner(reservation.userName));
      final pb = _shortName(_displayPartner(reservation.partner));
      return SlotData(
        state: SlotState.taken,
        primaryLabel: '$pa · $pb',
        onTap: () => _handleTap(courtUiIndex, hour),
      );
    }

    if (isPending) {
      return SlotData(state: SlotState.pending, primaryLabel: 'פנוי');
    }
    if (isFailed) {
      return SlotData(
        state: SlotState.failed,
        primaryLabel: 'פנוי',
        onTap: () => _handleTap(courtUiIndex, hour),
      );
    }
    if (_isPast(hour, now) && !widget.isManager) {
      return const SlotData(state: SlotState.past, primaryLabel: 'סגור');
    }
    return SlotData(
      state: SlotState.free,
      primaryLabel: 'פנוי',
      onTap: () => _handleTap(courtUiIndex, hour),
    );
  }

  String _displayPartner(String raw) {
    if (raw.startsWith('!')) return raw.substring(1);
    return raw;
  }

  String? _customBookingLabel(String raw) {
    if (!raw.startsWith('!')) return null;
    final label = raw.substring(1).trim();
    return label.isEmpty ? _adminBookingLabel : label;
  }

  String _partnerChipLabel(String name) {
    final trimmed = name.trim();
    if (trimmed == _adminBookingLabel) return 'מנהל';
    final parts = _displayPartner(trimmed)
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final firstName = parts.isEmpty ? trimmed : parts.first;
    return firstName.characters.take(4).toString();
  }

  bool _isAdminBookingSelection(String value) {
    return widget.isManager && value.trim() == _adminBookingLabel;
  }

  String? _firstSelectablePartner(Iterable<String> partners) {
    for (final partner in partners) {
      final trimmed = partner.trim();
      if (trimmed.isEmpty) continue;
      if (_isAdminBookingSelection(trimmed)) continue;
      return partner;
    }
    return null;
  }

  bool _hasPartnerForBooking(String partner) {
    final trimmed = partner.trim();
    return trimmed.isNotEmpty && !_isAdminBookingSelection(trimmed);
  }

  String _shortName(String fullName) {
    final n = fullName.trim();
    if (n.isEmpty) return n;
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last.characters.first}.';
  }

  String _firstName(String fullName) {
    final n = fullName.trim();
    if (n.isEmpty) return n;
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? n : parts.first;
  }

  Future<String?> _showAdminBookingDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('הזמנת מנהל'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'תיאור ההזמנה'),
            onSubmitted: (_) {
              Navigator.of(ctx).pop(controller.text.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ביטול'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('אישור'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    final description = result?.trim();
    if (description == null || description.isEmpty) return null;
    return '!$description';
  }

  Future<void> _selectPartner(String value) async {
    if (_isAdminBookingSelection(value)) {
      final customMessage = await _showAdminBookingDialog();
      if (!mounted || customMessage == null) return;
      setState(() => _selectedPartner = customMessage);
      return;
    }
    setState(() => _selectedPartner = value);
  }

  void _handleTap(int courtUiIndex, int hour) async {
    // Day switch hasn't finished loading the new day's reservations yet —
    // ignore taps so we don't act on the previous day's cached data.
    if (_loadingDay) return;
    final dbCourtNumber = _numberOfCourts - courtUiIndex;
    final reservation =
        _selectedDayByCell[dbCourtNumber]?[hour] ?? _Reservation.empty();

    final now = IsraelTime.now();
    if (reservation.hour >= 0) {
      final mine =
          widget.myUserName != null && reservation.involves(widget.myUserName!);
      if (mine) {
        if (!widget.isManager && _isLocked(hour, now)) {
          _toast.show(context, 'לא ניתן לבטל פחות מ-3 שעות לפני',
              kind: ToastKind.warn);
          return;
        }
        _openCancelSheet(reservation, courtUiIndex, hour);
      } else {
        if (widget.isManager) {
          _openCancelSheet(reservation, courtUiIndex, hour);
        }
        // Waitlist disabled — see docs/waitlist.md for the planned feature.
      }
      return;
    }

    if (_isPast(hour, now) && !widget.isManager) return;

    if (!_validateSync()) return;

    await _commit(courtUiIndex, hour);
  }

  Future<void> _commit(int courtUiIndex, int hour) async {
    final key = '$courtUiIndex-$hour';
    setState(() => _pendingKey = key);
    try {
      await _commitBooking(courtUiIndex, hour);
      if (!mounted) return;
      setState(() => _pendingKey = null);
      _toast.show(context, 'הוזמן', kind: ToastKind.good);
    } on _BookingValidationError catch (e) {
      if (!mounted) return;
      setState(() => _pendingKey = null);
      _toast.show(context, e.message, kind: ToastKind.warn);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pendingKey = null;
        _failedKey = key;
      });
      _toast.show(context, 'נכשל — נסה שוב', kind: ToastKind.warn);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _failedKey = null);
      });
    }
  }

  bool _validateSync() {
    if (FirebaseAuth.instance.currentUser == null) return false;
    final myName = widget.myUserName;
    if (myName == null || myName.isEmpty) return false;
    final partner = _selectedPartner?.trim() ?? '';
    if (!_hasPartnerForBooking(partner)) {
      _toast.show(context, 'בחר/י שותפ.ה לפני ההזמנה', kind: ToastKind.warn);
      return false;
    }
    if (!widget.isManager && partner == myName) {
      _toast.show(context, 'לא ניתן להזמין לעצמך', kind: ToastKind.warn);
      return false;
    }
    if (!widget.isManager && !BookingWindow.isOpenFor(_selectedDate)) {
      _toast.show(context, 'ההזמנות לתאריך זה עדיין לא נפתחו',
          kind: ToastKind.warn);
      return false;
    }
    if (!widget.isManager) {
      if (_partnerHasReservationOnSelectedDay(myName)) {
        _toast.show(context, 'משתמש $myName כבר מוזמן',
            kind: ToastKind.warn);
        return false;
      }
      if (_partnerHasReservationOnSelectedDay(partner)) {
        final partnerDisplay = _displayPartner(partner);
        _toast.show(context, 'משתמש $partnerDisplay כבר מוזמן',
            kind: ToastKind.warn);
        return false;
      }
    }
    return true;
  }

  Future<void> _commitBooking(int courtUiIndex, int hour) async {
    final user = FirebaseAuth.instance.currentUser!;
    final myName = widget.myUserName!;
    // Snapshot the day AND its court count up front. _selectedDate and
    // _numberOfCourts are mutable and the day switchers (hero strip / date
    // picker) stay live during the booking's async window. courtUiIndex was
    // captured at tap time against the then-current court count, so re-reading
    // _numberOfCourts after the awaits below could yield a stale-vs-live mix —
    // e.g. switching from a 3-court day to a 2-court day mid-commit made
    // (newCount - oldIndex) underflow to court 0 (seen on evening bookings,
    // whose extra quota await widens the window).
    final bookingDate = _selectedDate;
    final dbCourtNumber = _numberOfCourts - courtUiIndex;
    if (dbCourtNumber < 1 || dbCourtNumber > _numberOfCourts) {
      // The day changed under us; the tapped cell no longer maps to a real
      // court. Bail instead of writing/emailing an invalid court number.
      throw _BookingValidationError('המגרש כבר לא זמין — נסה שוב');
    }
    final partner = _selectedPartner?.trim() ?? '';
    if (!_hasPartnerForBooking(partner)) {
      throw _BookingValidationError('בחר/י שותפ.ה לפני ההזמנה');
    }
    final partnerDisplayName = _displayPartner(partner);

    if (!widget.isManager) {
      final results = await Future.wait([
        _resManager.hasExistingReservation(myName, bookingDate),
        _resManager.hasExistingReservation(partner, bookingDate),
      ]);
      if (results[0] || results[1]) {
        final blocking = results[0] ? myName : partner;
        throw _BookingValidationError('משתמש $blocking כבר מוזמן');
      }
    }

    if (!widget.isManager && isEveningQuotaHour(hour)) {
      final counts = await Future.wait([
        _resManager.countWeeklyEveningReservations(myName, bookingDate),
        _resManager.countWeeklyEveningReservations(partner, bookingDate),
      ]);
      if (counts[0] >= kWeeklyEveningQuota ||
          counts[1] >= kWeeklyEveningQuota) {
        final blocking = counts[0] >= kWeeklyEveningQuota ? myName : partner;
        throw _BookingValidationError(
          'ל-$blocking כבר יש 3 הזמנות השבוע בשעות 18:00, 19:00 ו-20:00',
        );
      }
    }

    final formattedDate = _fmt(bookingDate);
    final reservationData = {
      'date': formattedDate,
      'courtNumber': dbCourtNumber,
      'hour': hour,
      'isReserved': true,
      'userName': myName.trim(),
      'partner': partner.trim(),
    };

    // Deterministic doc id locks one reservation per cell. Legacy docs use a
    // timestamp id and collide on the same (date, court, hour) without sharing
    // an id — a pre-check covers them until backfill normalizes the collection.
    final docId = '${formattedDate}_${dbCourtNumber}_$hour';
    final ref =
        FirebaseFirestore.instance.collection('reservations').doc(docId);
    final legacy = await FirebaseFirestore.instance
        .collection('reservations')
        .where('date', isEqualTo: formattedDate)
        .where('courtNumber', isEqualTo: dbCourtNumber)
        .where('hour', isEqualTo: hour)
        .limit(1)
        .get();
    if (legacy.docs.isNotEmpty) {
      throw _BookingValidationError('המשבצת נתפסה כרגע — נסה שוב');
    }
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        throw _BookingValidationError('המשבצת נתפסה כרגע — נסה שוב');
      }
      tx.set(ref, reservationData);
    });

    await _updateLastFivePartners(user.email!, partner.trim());

    final partnerEmail = partner.startsWith('!')
        ? null
        : await UserManager.instance.getEmailByUsername(partner);
    final prefs = await Future.wait([
      _doesUserWantEmails(user.email!),
      partnerEmail != null
          ? _doesUserWantEmails(partnerEmail)
          : Future.value(false),
    ]);
    await sendReservationEmails(
      originatorEmail: user.email!,
      originatorName: myName,
      originatorWantsEmail: prefs[0],
      partnerEmail: partnerEmail,
      partnerName: partnerDisplayName,
      partnerWantsEmail: prefs[1],
      courtNumber: dbCourtNumber,
      date: bookingDate,
      hour: hour,
      isCancellation: false,
    );
  }

  Future<void> _cancelReservation(_Reservation r) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final rawPartnerName =
        (r.userName == widget.myUserName) ? r.partner : r.userName;
    final partnerName = _displayPartner(rawPartnerName);
    final partnerEmail = rawPartnerName.startsWith('!')
        ? null
        : await UserManager.instance.getEmailByUsername(partnerName);
    final prefs = await Future.wait([
      _doesUserWantEmails(user.email!),
      partnerEmail != null
          ? _doesUserWantEmails(partnerEmail)
          : Future.value(false),
    ]);
    await sendReservationEmails(
      originatorEmail: user.email!,
      originatorName: widget.myUserName ?? '',
      originatorWantsEmail: prefs[0],
      partnerEmail: partnerEmail,
      partnerName: partnerName,
      partnerWantsEmail: prefs[1],
      courtNumber: r.courtNumber,
      // Use the cancelled row's own stored date, not the live _selectedDate —
      // the latter can change mid-flight and would mis-report the cancellation.
      date: DateTime.parse(r.date),
      hour: r.hour,
      isCancellation: true,
    );
    await FirebaseFirestore.instance
        .collection('reservations')
        .doc(r.docId)
        .delete();
  }

  Future<bool> _doesUserWantEmails(String email) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users_2024')
          .where('מייל', isEqualTo: email)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return (data['receiveReservationEmails'] ?? false) as bool;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _updateLastFivePartners(
      String userEmail, String newPartner) async {
    if (newPartner.startsWith('!')) return;
    final query = await FirebaseFirestore.instance
        .collection('users_2024')
        .where('מייל', isEqualTo: userEmail)
        .get();
    if (query.docs.isEmpty) return;
    final ref = query.docs.first.reference;
    final snap = await ref.get();
    List<String> list = [];
    try {
      list = List<String>.from(snap['lastFivePartners'] ?? []);
    } catch (_) {}
    if (!list.contains(newPartner)) {
      list.add(newPartner);
      while (list.length > 5) {
        list.removeAt(0);
      }
      await ref.update({'lastFivePartners': list});
    }
  }

  void _openCancelSheet(_Reservation r, int courtUiIndex, int hour) {
    showBookingSheet(
      context: context,
      title: 'לבטל את ההזמנה?',
      subtitle: '${hour.toString().padLeft(2, '0')}:00 · מגרש ${r.courtNumber}',
      options: [
        SheetOption(
          glyph: '✕',
          title: 'בטל הזמנה',
          subtitle: 'תישלח התראה לשותפ.ה',
          onTap: () async {
            Navigator.of(context).pop();
            // Optimistic UI: remove locally first, then confirm with Firestore.
            final prevReservations = _selectedDayReservations;
            final prevByCell = _selectedDayByCell;
            final nextReservations =
                prevReservations.where((x) => x.docId != r.docId).toList();
            setState(() {
              _selectedDayReservations = nextReservations;
              _selectedDayByCell = _buildByCell(nextReservations);
            });
            _toast.show(context, 'ההזמנה בוטלה', kind: ToastKind.info);
            try {
              await _cancelReservation(r);
            } catch (_) {
              if (!mounted) return;
              setState(() {
                _selectedDayReservations = prevReservations;
                _selectedDayByCell = prevByCell;
              });
              _toast.show(context, 'הביטול נכשל', kind: ToastKind.warn);
            }
          },
        ),
        SheetOption(
          glyph: '↺',
          title: 'השאר',
          subtitle: 'אל תשנה כלום',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // Waitlist sheet — disabled. See docs/waitlist.md for the planned feature.
  // void _openWaitlistSheet(_Reservation r) {
  //   final pa = _shortName(_displayPartner(r.userName));
  //   final pb = _shortName(_displayPartner(r.partner));
  //   showBookingSheet(
  //     context: context,
  //     title: 'המשבצת תפוסה',
  //     subtitle: '$pa · $pb',
  //     options: [
  //       SheetOption(
  //         glyph: '⏱',
  //         title: 'הוסף לרשימת המתנה',
  //         subtitle: 'נודיע אם מתפנה',
  //         onTap: () {
  //           Navigator.of(context).pop();
  //           _toast.show(context, 'נוספת לרשימת המתנה', kind: ToastKind.good);
  //         },
  //       ),
  //       SheetOption(
  //         glyph: '✕',
  //         title: 'סגור',
  //         subtitle: '',
  //         onTap: () => Navigator.of(context).pop(),
  //       ),
  //     ],
  //   );
  // }

  // Cycle-partner removed — see docs/.. (the recents strip already covers this).
  // void _onCyclePartner() {
  //   if (widget.lastFivePartners.isEmpty) return;
  //   final idx = widget.lastFivePartners.indexOf(_selectedPartner ?? '');
  //   final next = widget.lastFivePartners[(idx + 1) % widget.lastFivePartners.length];
  //   setState(() => _selectedPartner = next);
  // }

  // Restore-last-week disabled — see docs/restore_last_week.md.
  // void _onRestoreLastWeek() {
  //   if (widget.lastFivePartners.isEmpty) {
  //     _toast.show(context, 'אין שותפ.ה אחרונ.ה', kind: ToastKind.info);
  //     return;
  //   }
  //   final last = widget.lastFivePartners.last;
  //   setState(() => _selectedPartner = last);
  //   _toast.show(context, 'שוחזר: $last', kind: ToastKind.info);
  // }

  void _onDayChanged(HeroDay day) {
    final now = IsraelTime.now();
    final target =
        day == HeroDay.today ? _effectiveToday(now) : _effectiveTomorrow(now);
    if (_isSameDay(target, _selectedDate)) return;
    setState(() => _selectedDate = target);
    _refreshCourtsThenLoad();
  }

  Future<void> _onPickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(
        () => _selectedDate = DateTime(picked.year, picked.month, picked.day));
    _refreshCourtsThenLoad();
  }

  void _onAddPartnerTap() async {
    final controller = TextEditingController();
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('בחר שותפ.ה'),
          content: Autocomplete<String>(
            optionsBuilder: (text) {
              if (text.text.isEmpty) return const Iterable<String>.empty();
              return widget.allUsers.where(
                  (u) => u.toLowerCase().contains(text.text.toLowerCase()));
            },
            onSelected: (v) {
              controller.text = v;
              Navigator.of(ctx).pop(v);
            },
            fieldViewBuilder: (ctx, ctl, focus, _) {
              return TextField(
                controller: ctl,
                focusNode: focus,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'שם שותפ.ה'),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ביטול'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('אישור'),
            ),
          ],
        );
      },
    );
    if (picked != null && picked.isNotEmpty) {
      await _selectPartner(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = BookingTokens.of(context);
    final israelNow = IsraelTime.now();
    final viewingToday = _heroDay == HeroDay.today;
    final nowHour = viewingToday ? israelNow.hour : null;

    final recents = widget.lastFivePartners.map((name) {
      return RecentPartner(
        label: _partnerChipLabel(name),
        value: name,
        available: !_partnerHasReservationOnSelectedDay(name),
      );
    }).toList();
    // Selected partner picked from the add-partner autocomplete isn't in
    // `lastFivePartners` yet — prepend them so the active chip is visible.
    final sel = _selectedPartner;
    if (sel != null &&
        sel.trim().isNotEmpty &&
        !widget.lastFivePartners.contains(sel)) {
      recents.insert(
        0,
        RecentPartner(
          label: _partnerChipLabel(sel),
          value: sel,
          available: !_partnerHasReservationOnSelectedDay(sel),
        ),
      );
    }

    return Container(
      color: tokens.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HeroStrip(
              day: _heroDay,
              onDayChanged: _onDayChanged,
              usedEvenings: _usedEvenings,
              darkMode: widget.darkMode,
              onThemeToggle: () => widget.onDarkModeToggle(!widget.darkMode),
              onMenuTap: widget.onMenuTap,
              afterRollover: israelNow.hour >= 22,
            ),
            RecentsStrip(
              recents: recents,
              selected: _selectedPartner,
              onSelect: _selectPartner,
              onAddTap: _onAddPartnerTap,
            ),
            if (widget.isManager)
              Container(
                color: tokens.surface,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: tokens.ink2),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('d.M.yyyy').format(_selectedDate),
                      style: TextStyle(
                          color: tokens.ink2,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _onPickDate,
                      child: const Text('בחר תאריך'),
                    ),
                  ],
                ),
              ),
            TimeGrid(
              numberOfCourts: _numberOfCourts,
              nowHour: nowHour,
              slotBuilder: (courtUiIndex, hour) =>
                  _resolveSlot(courtUiIndex, hour, israelNow),
              loading: _loadingDay,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingValidationError implements Exception {
  final String message;
  _BookingValidationError(this.message);
}

class _Reservation {
  final String docId;
  final String date;
  final int courtNumber;
  final int hour;
  final String userName;
  final String partner;

  const _Reservation({
    required this.docId,
    required this.date,
    required this.courtNumber,
    required this.hour,
    required this.userName,
    required this.partner,
  });

  factory _Reservation.empty() => const _Reservation(
      docId: '',
      date: '',
      courtNumber: -1,
      hour: -1,
      userName: '',
      partner: '');

  factory _Reservation.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return _Reservation(
      docId: doc.id,
      date: (data['date'] ?? '') as String,
      courtNumber: (data['courtNumber'] ?? 0) as int,
      hour: (data['hour'] ?? 0) as int,
      userName: (data['userName'] ?? '') as String,
      partner: (data['partner'] ?? '') as String,
    );
  }

  bool involves(String name) {
    final n = name.trim().toLowerCase();
    return userName.trim().toLowerCase() == n ||
        partner.trim().toLowerCase() == n;
  }
}
