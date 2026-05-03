import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'booking_tokens.dart';
import 'booking_window.dart';
import 'email_service.dart';
import 'holiday_courts.dart';
import 'israel_time.dart';
import 'reservation_manager.dart';
import 'user_manager.dart';
import 'weather_service.dart';
import 'widgets/booking_sheet.dart';
import 'widgets/hero_strip.dart';
import 'widgets/partner_bar.dart';
import 'widgets/recents_strip.dart';
import 'widgets/slot_button.dart';
import 'widgets/time_grid.dart';
import 'widgets/toast.dart';

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
  StreamSubscription<QuerySnapshot>? _companionDaySub;
  StreamSubscription<QuerySnapshot>? _myUpcomingSub;
  List<_Reservation> _selectedDayReservations = [];
  Map<int, Map<int, _Reservation>> _selectedDayByCell = {};
  List<_Reservation> _myUpcoming = [];
  int _companionEveningCount = 0;

  String? _preview;
  Timer? _previewTimer;
  String? _pendingKey;
  String? _failedKey;
  bool _loadingDay = false;

  final _toast = ToastController();
  final _resManager = ReservationManager();

  int? _weatherToday;
  int? _weatherTomorrow;

  @override
  void initState() {
    super.initState();
    final now = IsraelTime.now();
    _selectedDate = _effectiveToday(now);
    _refreshCourtsThenLoad();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    final s = await WeatherService.instance.get();
    if (!mounted || s == null) return;
    setState(() {
      _weatherToday = s.todayC;
      _weatherTomorrow = s.tomorrowC;
    });
  }

  @override
  void didUpdateWidget(covariant BookingScreenV31 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastFivePartners != widget.lastFivePartners &&
        _selectedPartner == null &&
        widget.lastFivePartners.isNotEmpty) {
      setState(() => _selectedPartner = widget.lastFivePartners.first);
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _selectedDaySub?.cancel();
    _companionDaySub?.cancel();
    _myUpcomingSub?.cancel();
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
    setState(() => _loadingDay = true);
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
    _companionDaySub?.cancel();
    _myUpcomingSub?.cancel();

    final selectedKey = _fmt(_selectedDate);
    _selectedDaySub = FirebaseFirestore.instance
        .collection('reservations')
        .where('date', isEqualTo: selectedKey)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final list = snap.docs.map(_Reservation.fromDoc).toList();
      final byCell = <int, Map<int, _Reservation>>{};
      for (final r in list) {
        (byCell[r.courtNumber] ??= {})[r.hour] = r;
      }
      setState(() {
        _selectedDayReservations = list;
        _selectedDayByCell = byCell;
        _loadingDay = false;
      });
    });

    final now = IsraelTime.now();
    final today = _effectiveToday(now);
    final tomorrow = _effectiveTomorrow(now);
    final companion =
        _isSameDay(_selectedDate, today) ? tomorrow : today;
    final compKey = _fmt(companion);
    final me = widget.myUserName ?? '';
    _companionDaySub = FirebaseFirestore.instance
        .collection('reservations')
        .where('date', isEqualTo: compKey)
        .where('hour', whereIn: kEveningHours.toList())
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      int n = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final user = (data['userName'] ?? '') as String;
        final partner = (data['partner'] ?? '') as String;
        if (user.trim().toLowerCase() == me.trim().toLowerCase() ||
            partner.trim().toLowerCase() == me.trim().toLowerCase()) {
          n++;
        }
      }
      setState(() => _companionEveningCount = n);
    });

    if (me.isNotEmpty) {
      final todayKey = _fmt(today);
      final tomorrowKey = _fmt(tomorrow);
      _myUpcomingSub = FirebaseFirestore.instance
          .collection('reservations')
          .where('date', whereIn: [todayKey, tomorrowKey])
          .snapshots()
          .listen((snap) {
        if (!mounted) return;
        final list = <_Reservation>[];
        for (final doc in snap.docs) {
          final r = _Reservation.fromDoc(doc);
          if (r.involves(me)) list.add(r);
        }
        list.sort((a, b) {
          final cmp = a.date.compareTo(b.date);
          return cmp != 0 ? cmp : a.hour.compareTo(b.hour);
        });
        setState(() => _myUpcoming = list);
      });
    } else {
      _myUpcoming = [];
    }
  }

  HeroDay get _heroDay {
    final today = _effectiveToday(IsraelTime.now());
    return _isSameDay(_selectedDate, today) ? HeroDay.today : HeroDay.tomorrow;
  }

  NextUpInfo? get _myNextUp {
    if (widget.myUserName == null) return null;
    final now = IsraelTime.now();
    final todayKey = _fmt(_effectiveToday(now));
    for (final r in _myUpcoming) {
      if (r.date == todayKey && r.hour < now.hour) continue;
      final partner = r.userName == widget.myUserName ? r.partner : r.userName;
      return NextUpInfo(
        hour: r.hour,
        courtNumber: r.courtNumber,
        partnerShort: _shortName(partner),
        dateLabel: r.date == todayKey ? null : 'מחר',
      );
    }
    return null;
  }

  int get _usedEvenings {
    final me = widget.myUserName ?? '';
    if (me.isEmpty) return 0;
    int n = _companionEveningCount;
    for (final r in _selectedDayReservations) {
      if (kEveningHours.contains(r.hour) && r.involves(me)) n++;
    }
    return n.clamp(0, 3);
  }

  bool _partnerHasReservationOnSelectedDay(String name) {
    return _selectedDayReservations.any((r) => r.involves(name));
  }

  bool _isLocked(int hour) {
    final now = IsraelTime.now();
    final viewingToday = _isSameDay(_selectedDate, _effectiveToday(now));
    if (!viewingToday) return false;
    final delta = hour - now.hour;
    return delta > 0 && delta <= 3;
  }

  bool _isPast(int hour) {
    final now = IsraelTime.now();
    final viewingToday = _isSameDay(_selectedDate, _effectiveToday(now));
    if (!viewingToday) return false;
    final reservationDt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
    );
    return reservationDt.isBefore(now) ||
        reservationDt.difference(now).inMinutes < 60;
  }

  SlotData _resolveSlot(int courtUiIndex, int hour) {
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
    final isPreview = _preview == key;
    final isPending = _pendingKey == key;
    final isFailed = _failedKey == key;

    if (reservation.hour >= 0) {
      final mine = widget.myUserName != null && reservation.involves(widget.myUserName!);
      if (mine) {
        final state = _isLocked(hour) ? SlotState.mineLocked : SlotState.mine;
        final partner = reservation.userName == widget.myUserName
            ? reservation.partner
            : reservation.userName;
        return SlotData(
          state: state,
          primaryLabel: _shortName(_displayPartner(partner)),
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

    if (isPending) return SlotData(state: SlotState.pending, primaryLabel: 'פנוי');
    if (isFailed) {
      return SlotData(
        state: SlotState.failed,
        primaryLabel: 'פנוי',
        onTap: () => _handleTap(courtUiIndex, hour),
      );
    }
    if (isPreview) {
      return SlotData(
        state: SlotState.preview,
        primaryLabel: 'פנוי',
        onTap: () => _handleTap(courtUiIndex, hour),
      );
    }
    if (_isPast(hour) && !widget.isManager) {
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

  String _shortName(String fullName) {
    final n = fullName.trim();
    if (n.isEmpty) return n;
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last.characters.first}.';
  }

  void _handleTap(int courtUiIndex, int hour) async {
    final dbCourtNumber = _numberOfCourts - courtUiIndex;
    final reservation =
        _selectedDayByCell[dbCourtNumber]?[hour] ?? _Reservation.empty();

    if (reservation.hour >= 0) {
      final mine = widget.myUserName != null && reservation.involves(widget.myUserName!);
      if (mine) {
        if (!widget.isManager && _isLocked(hour)) {
          _toast.show(context, 'לא ניתן לבטל פחות מ-3 שעות לפני', kind: ToastKind.warn);
          return;
        }
        _openCancelSheet(reservation, courtUiIndex, hour);
      } else {
        if (widget.isManager) {
          _openCancelSheet(reservation, courtUiIndex, hour);
        }
        // Waitlist disabled — see docs/waitlist.md for the planned feature.
        // } else {
        //   _openWaitlistSheet(reservation);
        // }
      }
      return;
    }

    if (_isPast(hour) && !widget.isManager) return;

    // Cheap sync validations before even showing preview.
    if (!_validateSync()) return;

    final key = '$courtUiIndex-$hour';
    if (_preview == key) {
      _previewTimer?.cancel();
      setState(() {
        _preview = null;
        _pendingKey = key;
      });
      try {
        await _commitBooking(courtUiIndex, hour);
        if (!mounted) return;
        setState(() => _pendingKey = null);
        _toast.show(context, 'הוזמן', kind: ToastKind.good);
      } on _BookingValidationError catch (e) {
        // Async validation rejected the booking — toast + revert silently.
        if (!mounted) return;
        setState(() => _pendingKey = null);
        _toast.show(context, e.message, kind: ToastKind.warn);
      } catch (_) {
        // Real network/write failure — shake + warn.
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
      return;
    }

    setState(() => _preview = key);
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      setState(() {
        if (_preview == key) _preview = null;
      });
    });
  }

  bool _validateSync() {
    if (FirebaseAuth.instance.currentUser == null) return false;
    final myName = widget.myUserName;
    if (myName == null || myName.isEmpty) return false;
    final partner = _selectedPartner?.trim() ?? '';
    if (partner.isEmpty) {
      _toast.show(context, 'בחר/י שותפ.ה לפני ההזמנה', kind: ToastKind.warn);
      return false;
    }
    if (!widget.isManager && partner == myName) {
      _toast.show(context, 'לא ניתן להזמין לעצמך', kind: ToastKind.warn);
      return false;
    }
    if (!widget.isManager && !BookingWindow.isOpenFor(_selectedDate)) {
      _toast.show(context, 'ההזמנות לתאריך זה עדיין לא נפתחו', kind: ToastKind.warn);
      return false;
    }
    return true;
  }

  Future<void> _commitBooking(int courtUiIndex, int hour) async {
    final user = FirebaseAuth.instance.currentUser!;
    final myName = widget.myUserName!;
    final partner = _selectedPartner!.trim();

    if (!widget.isManager) {
      final results = await Future.wait([
        _resManager.hasExistingReservation(myName, _selectedDate),
        _resManager.hasExistingReservation(partner, _selectedDate),
      ]);
      if (results[0] || results[1]) {
        final blocking = results[0] ? myName : partner;
        throw _BookingValidationError('משתמש $blocking כבר מוזמן');
      }
    }

    if (!widget.isManager && kEveningHours.contains(hour)) {
      if (_usedEvenings >= 3) {
        throw _BookingValidationError('הגעת לתקרת 3 ערבים השבוע');
      }
    }

    final dbCourtNumber = _numberOfCourts - courtUiIndex;
    final formattedDate = _fmt(_selectedDate);
    final reservationData = {
      'date': formattedDate,
      'courtNumber': dbCourtNumber,
      'hour': hour,
      'isReserved': true,
      'userName': myName.trim(),
      'partner': partner.trim(),
    };
    final reservationId = DateTime.now().toUtc().toIso8601String();
    await FirebaseFirestore.instance
        .collection('reservations')
        .doc(reservationId)
        .set(reservationData);

    await _updateLastFivePartners(user.email!, partner.trim());

    final partnerEmail = await UserManager.instance.getEmailByUsername(partner);
    final prefs = await Future.wait([
      _doesUserWantEmails(user.email!),
      partnerEmail != null ? _doesUserWantEmails(partnerEmail) : Future.value(false),
    ]);
    await sendReservationEmails(
      originatorEmail: user.email!,
      originatorName: myName,
      originatorWantsEmail: prefs[0],
      partnerEmail: partnerEmail,
      partnerName: partner,
      partnerWantsEmail: prefs[1],
      courtNumber: dbCourtNumber,
      date: _selectedDate,
      hour: hour,
      isCancellation: false,
    );
  }

  Future<void> _cancelReservation(_Reservation r) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final partnerName = (r.userName == widget.myUserName) ? r.partner : r.userName;
    final partnerEmail = await UserManager.instance.getEmailByUsername(partnerName);
    final prefs = await Future.wait([
      _doesUserWantEmails(user.email!),
      partnerEmail != null ? _doesUserWantEmails(partnerEmail) : Future.value(false),
    ]);
    await sendReservationEmails(
      originatorEmail: user.email!,
      originatorName: widget.myUserName ?? '',
      originatorWantsEmail: prefs[0],
      partnerEmail: partnerEmail,
      partnerName: partnerName,
      partnerWantsEmail: prefs[1],
      courtNumber: r.courtNumber,
      date: _selectedDate,
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

  Future<void> _updateLastFivePartners(String userEmail, String newPartner) async {
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
            try {
              await _cancelReservation(r);
              if (!mounted) return;
              _toast.show(context, 'ההזמנה בוטלה', kind: ToastKind.info);
            } catch (_) {
              if (!mounted) return;
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
    final target = day == HeroDay.today ? _effectiveToday(now) : _effectiveTomorrow(now);
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
    setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
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
      setState(() => _selectedPartner = picked);
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
        name: _shortName(name),
        available: !_partnerHasReservationOnSelectedDay(name),
      );
    }).toList();
    final selectedShort = _selectedPartner == null ? null : _shortName(_selectedPartner!);

    return Container(
      color: tokens.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HeroStrip(
              day: _heroDay,
              date: _selectedDate,
              nextUp: _myNextUp,
              todayTemp: _weatherToday,
              tomorrowTemp: _weatherTomorrow,
              onDayChanged: _onDayChanged,
              onMenuTap: widget.onMenuTap,
              afterRollover: israelNow.hour >= 22,
            ),
            PartnerBar(
              partnerName: _selectedPartner,
              partnerAvailable: _selectedPartner != null &&
                  !_partnerHasReservationOnSelectedDay(_selectedPartner!),
              usedEvenings: _usedEvenings,
              darkMode: widget.darkMode,
              onRefreshTap: _refreshCourtsThenLoad,
              onThemeToggle: () => widget.onDarkModeToggle(!widget.darkMode),
            ),
            RecentsStrip(
              recents: recents,
              selected: selectedShort,
              onSelect: (shortName) {
                final match = widget.lastFivePartners.firstWhere(
                  (n) => _shortName(n) == shortName,
                  orElse: () => shortName,
                );
                setState(() => _selectedPartner = match);
              },
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
                      style: TextStyle(color: tokens.ink2, fontSize: 11, fontWeight: FontWeight.w600),
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
              slotBuilder: _resolveSlot,
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

  factory _Reservation.empty() =>
      const _Reservation(docId: '', date: '', courtNumber: -1, hour: -1, userName: '', partner: '');

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
