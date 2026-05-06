import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import 'booking_tokens.dart';
import 'holiday_courts.dart';
import 'israel_time.dart';
import 'widgets/slot_button.dart';
import 'widgets/time_grid.dart';

class TvScreen extends StatefulWidget {
  const TvScreen({super.key});

  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  late DateTime _effectiveToday;
  late DateTime _effectiveTomorrow;
  Timer? _rollTimer;
  Timer? _refreshTimer;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _setEffectiveDates();
    _scheduleRoll();
    _scheduleHourlyRefresh();
  }

  @override
  void dispose() {
    _rollTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _setEffectiveDates() {
    final now = IsraelTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final afterTen = now.hour >= 22;
    _effectiveToday = afterTen ? base.add(const Duration(days: 1)) : base;
    _effectiveTomorrow = afterTen
        ? base.add(const Duration(days: 2))
        : base.add(const Duration(days: 1));
  }

  void _scheduleRoll() {
    _rollTimer?.cancel();
    final now = IsraelTime.now();
    var nextRoll = DateTime(now.year, now.month, now.day, 22);
    if (!nextRoll.isAfter(now)) {
      nextRoll = nextRoll.add(const Duration(days: 1));
    }
    _rollTimer = Timer(nextRoll.difference(now), () {
      setState(() {
        _setEffectiveDates();
        _refreshKey++;
      });
      _scheduleRoll();
    });
  }

  void _scheduleHourlyRefresh() {
    _refreshTimer?.cancel();
    final now = DateTime.now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    _refreshTimer = Timer(nextHour.difference(now), () {
      setState(() => _refreshKey++);
      _scheduleHourlyRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: BookingTokens.dark.bg,
        extensions: const [BookingTokens.dark],
      ),
      child: Builder(
        builder: (context) {
          final tokens = BookingTokens.of(context);
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: tokens.bg,
              body: SafeArea(
                child: Column(
                  children: [
                    _TvHeader(refreshKey: _refreshKey),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _TvDayBoard(
                                key: ValueKey('today_$_refreshKey'),
                                date: _effectiveToday,
                                label: 'היום',
                                refreshKey: _refreshKey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TvDayBoard(
                                key: ValueKey('tomorrow_$_refreshKey'),
                                date: _effectiveTomorrow,
                                label: 'מחר',
                                refreshKey: _refreshKey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const _TvMarquee(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TvHeader extends StatelessWidget {
  final int refreshKey;
  const _TvHeader({required this.refreshKey});

  @override
  Widget build(BuildContext context) {
    final tokens = BookingTokens.of(context);
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tokens.clay, tokens.clayD],
        ),
      ),
      child: Row(
        children: [
          const Text(
            'מועדון הכרמל',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'לוח מגרשים',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _TvDayBoard extends StatefulWidget {
  final DateTime date;
  final String label;
  final int refreshKey;

  const _TvDayBoard({
    super.key,
    required this.date,
    required this.label,
    required this.refreshKey,
  });

  @override
  State<_TvDayBoard> createState() => _TvDayBoardState();
}

class _TvDayBoardState extends State<_TvDayBoard> {
  String _holidayType = 'רגיל';
  int _numberOfCourts = 2;
  bool _loadingCourts = true;

  @override
  void initState() {
    super.initState();
    _loadCourtState();
  }

  @override
  void didUpdateWidget(covariant _TvDayBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(widget.date, oldWidget.date) ||
        widget.refreshKey != oldWidget.refreshKey) {
      _loadCourtState();
    }
  }

  String get _dateKey => intl.DateFormat('yyyy-MM-dd').format(widget.date);

  Future<void> _loadCourtState() async {
    setState(() => _loadingCourts = true);
    final type = await getHolidayType(widget.date);
    final courts = numberOfCourtsFor(widget.date, type);
    if (!mounted) return;
    setState(() {
      _holidayType = type;
      _numberOfCourts = courts;
      _loadingCourts = false;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int? _nowHourFor(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, now) ? now.hour : null;
  }

  SlotData _slotFor(
    Map<int, Map<int, _TvReservation>> reservations,
    int courtUiIndex,
    int hour,
  ) {
    if (isCoachSlot(
      date: widget.date,
      hour: hour,
      courtUiIndex: courtUiIndex,
      holidayType: _holidayType,
    )) {
      return const SlotData(state: SlotState.coach, primaryLabel: 'מאמן');
    }

    final dbCourtNumber = _numberOfCourts - courtUiIndex;
    final reservation = reservations[dbCourtNumber]?[hour];
    if (reservation == null) {
      return const SlotData(state: SlotState.free, primaryLabel: 'פנוי');
    }

    final customLabel = _customBookingLabel(reservation.partner);
    if (customLabel != null) {
      return SlotData(state: SlotState.taken, primaryLabel: customLabel);
    }

    return SlotData(
      state: SlotState.taken,
      primaryLabel:
          '${_displayName(reservation.userName)}\n${_displayName(reservation.partner)}',
    );
  }

  String _displayName(String raw) {
    if (raw.startsWith('!')) return raw.substring(1).trim();
    return raw.trim();
  }

  String? _customBookingLabel(String raw) {
    if (!raw.startsWith('!')) return null;
    final label = raw.substring(1).trim();
    return label.isEmpty ? 'הזמנת מנהל' : label;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = BookingTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.line, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _TvBoardHeader(date: widget.date, label: widget.label),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('reservations')
                  .where('date', isEqualTo: _dateKey)
                  .snapshots(),
              builder: (context, snapshot) {
                final reservations = <int, Map<int, _TvReservation>>{};
                for (final doc in snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                  final reservation = _TvReservation.fromDoc(doc);
                  (reservations[reservation.courtNumber] ??=
                      {})[reservation.hour] = reservation;
                }

                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.12),
                  ),
                  child: TimeGrid(
                    numberOfCourts: _numberOfCourts,
                    nowHour: _nowHourFor(widget.date),
                    loading: _loadingCourts ||
                        snapshot.connectionState == ConnectionState.waiting,
                    slotBuilder: (courtUiIndex, hour) =>
                        _slotFor(reservations, courtUiIndex, hour),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TvBoardHeader extends StatelessWidget {
  final DateTime date;
  final String label;

  const _TvBoardHeader({
    required this.date,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = BookingTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
      decoration: BoxDecoration(
        color: tokens.bg,
        border: Border(bottom: BorderSide(color: tokens.line, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.clayInk,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatDateHebrew(date),
            style: TextStyle(
              color: tokens.ink2,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateHebrew(DateTime d) {
    const weekdays = [
      '',
      'יום שני',
      'יום שלישי',
      'יום רביעי',
      'יום חמישי',
      'יום שישי',
      'שבת',
      'יום ראשון',
    ];
    return '${weekdays[d.weekday]} ${d.day}.${d.month}.${d.year}';
  }
}

class _TvReservation {
  final int courtNumber;
  final int hour;
  final String userName;
  final String partner;

  const _TvReservation({
    required this.courtNumber,
    required this.hour,
    required this.userName,
    required this.partner,
  });

  factory _TvReservation.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _TvReservation(
      courtNumber: (data['courtNumber'] ?? 0) as int,
      hour: (data['hour'] ?? 0) as int,
      userName: (data['userName'] ?? '') as String,
      partner: (data['partner'] ?? '') as String,
    );
  }
}

class _TvMarquee extends StatefulWidget {
  const _TvMarquee();

  @override
  State<_TvMarquee> createState() => _TvMarqueeState();
}

class _TvMarqueeState extends State<_TvMarquee> {
  String? _heatText;
  Timer? _heatTimer;
  final Dio _dio = Dio();
  static const _heatRefreshInterval = Duration(minutes: 7);
  static const double _clubLat = 32.7940;
  static const double _clubLon = 34.9896;

  @override
  void initState() {
    super.initState();
    _fetchHeatIndex();
    _heatTimer = Timer.periodic(_heatRefreshInterval, (_) => _fetchHeatIndex());
  }

  @override
  void dispose() {
    _heatTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchHeatIndex() async {
    try {
      final response = await _dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': _clubLat,
          'longitude': _clubLon,
          'current':
              'temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m',
          'hourly': 'precipitation_probability',
          'timezone': 'auto',
        },
      );
      final data = response.data;
      final current = data is Map ? data['current'] as Map? : null;
      if (current == null) {
        _setHeatText(null);
        return;
      }
      final tempC = (current['temperature_2m'] as num?)?.toDouble();
      final rh = (current['relative_humidity_2m'] as num?)?.toDouble();
      final windSpeed = (current['wind_speed_10m'] as num?)?.toDouble();
      final windDir = (current['wind_direction_10m'] as num?)?.toDouble();
      final currentTime = current['time'] as String?;
      final nextHourProb = _nextHourPrecipProbability(data, currentTime);
      if (tempC == null ||
          rh == null ||
          windSpeed == null ||
          windDir == null ||
          nextHourProb == null) {
        _setHeatText(null);
        return;
      }
      final hiC = _computeHeatIndexC(tempC, rh);
      final label = _heatLevelLabel(hiC);
      _setHeatText(
        'עומס חום: ${hiC.round()}° - $label   |   סיכוי לגשם בשעה הקרובה: ${nextHourProb.round()}%   |   רוח: ${windSpeed.round()} קמ״ש ${_windDirectionHebrew(windDir)}',
      );
    } catch (_) {
      _setHeatText(null);
    }
  }

  void _setHeatText(String? value) {
    if (!mounted) return;
    setState(() {
      _heatText = value;
    });
  }

  double _computeHeatIndexC(double tempC, double rh) {
    final tempF = tempC * 9 / 5 + 32;
    if (tempF < 80) return tempC;
    final t = tempF;
    final r = rh;
    double hi = -42.379 +
        2.04901523 * t +
        10.14333127 * r -
        0.22475541 * t * r -
        0.00683783 * t * t -
        0.05481717 * r * r +
        0.00122874 * t * t * r +
        0.00085282 * t * r * r -
        0.00000199 * t * t * r * r;
    if (r < 13 && t >= 80 && t <= 112) {
      final adj = ((13 - r) / 4) * sqrt((17 - (t - 95).abs()) / 17);
      hi -= adj;
    } else if (r > 85 && t >= 80 && t <= 87) {
      final adj = ((r - 85) / 10) * ((87 - t) / 5);
      hi += adj;
    }
    return (hi - 32) * 5 / 9;
  }

  String _heatLevelLabel(double hiC) {
    if (hiC < 27) return 'נוח';
    if (hiC < 32) return 'זהירות';
    if (hiC < 41) return 'זהירות מוגברת';
    if (hiC < 54) return 'סכנה';
    return 'סכנה חמורה';
  }

  double? _nextHourPrecipProbability(Object? data, String? currentTime) {
    if (data is! Map || currentTime == null) return null;
    final hourly = data['hourly'] as Map?;
    if (hourly == null) return null;
    final times = hourly['time'] as List?;
    final probs = hourly['precipitation_probability'] as List?;
    if (times == null || probs == null || times.length != probs.length) {
      return null;
    }
    final now = DateTime.tryParse(currentTime);
    if (now == null) return null;
    for (var i = 0; i < times.length; i++) {
      final timeString = times[i] as String?;
      final time = timeString == null ? null : DateTime.tryParse(timeString);
      if (time == null) continue;
      if (time.isAfter(now)) {
        final value = probs[i];
        if (value is num) return value.toDouble();
      }
    }
    return null;
  }

  String _windDirectionHebrew(double degrees) {
    final d = degrees % 360;
    if (d >= 337.5 || d < 22.5) return 'צפון';
    if (d < 67.5) return 'צפון-מזרח';
    if (d < 112.5) return 'מזרח';
    if (d < 157.5) return 'דרום-מזרח';
    if (d < 202.5) return 'דרום';
    if (d < 247.5) return 'דרום-מערב';
    if (d < 292.5) return 'מערב';
    return 'צפון-מערב';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = BookingTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 9, 18, 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.line, width: 1)),
      ),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('tv')
            .doc('marquee')
            .snapshots(),
        builder: (context, snap) {
          final text = (snap.data?.data()?['text'] as String?)?.trim();
          final display =
              text == null || text.isEmpty ? 'ברוכים הבאים למועדון כרמל' : text;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_heatText != null) ...[
                Text(
                  _heatText!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.ink2,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                display,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.clayInk,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
