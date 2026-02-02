import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'court_reservation.dart';

class TvScreen extends StatefulWidget {
  const TvScreen({super.key});

  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  late DateTime _effectiveToday;
  late DateTime _effectiveTomorrow;
  Timer? _midnightTimer;
  Timer? _refreshTimer;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _computeEffectiveDates();
    _scheduleMidnightRoll();
    _scheduleHourlyRefresh();
  }

  void _computeEffectiveDates() {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final after2200 = now.hour >= 22;
    final today = after2200 ? base.add(const Duration(days: 1)) : base;
    final tomorrow = after2200
        ? base.add(const Duration(days: 2))
        : base.add(const Duration(days: 1));
    setState(() {
      _effectiveToday = today;
      _effectiveTomorrow = tomorrow;
    });
  }

  void _scheduleMidnightRoll() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    // Roll at 22:00 to the next logical day, matching app logic
    DateTime nextRoll = DateTime(now.year, now.month, now.day, 22);
    if (now.isAfter(nextRoll)) {
      nextRoll = nextRoll.add(const Duration(days: 1));
    }
    final duration = nextRoll.difference(now);
    _midnightTimer = Timer(duration, () {
      _computeEffectiveDates();
      _scheduleMidnightRoll();
    });
  }

  void _scheduleHourlyRefresh() {
    _refreshTimer?.cancel();
    final now = DateTime.now();
    // Schedule refresh at the top of the next hour
    DateTime nextHour =
        DateTime(now.year, now.month, now.day, now.hour + 1, 0, 0);
    final duration = nextHour.difference(now);
    _refreshTimer = Timer(duration, () {
      setState(() {
        _refreshKey++;
      });
      _scheduleHourlyRefresh();
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _formatDateHebrew(DateTime d) {
    // Basic Hebrew-like formatting without intl locale dependency changes
    // Dart weekday: 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday, 7=Sunday
    const weekdays = [
      '', // index 0 - not used
      'יום שני', // 1
      'יום שלישי', // 2
      'יום רביעי', // 3
      'יום חמישי', // 4
      'יום שישי', // 5
      'יום שבת', // 6
      'יום ראשון', // 7
    ];
    final weekday = weekdays[d.weekday];
    return '$weekday ${d.day}.${d.month}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _formatDateHebrew(_effectiveToday),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                textTheme: Theme.of(context).textTheme.apply(
                                      bodyColor: Colors.white,
                                      displayColor: Colors.white,
                                    ),
                              ),
                              child: Directionality(
                                textDirection: TextDirection.rtl,
                                child: CourtReservations(
                                  key: ValueKey('today_$_refreshKey'),
                                  selectedDate: _effectiveToday,
                                  selectedPartner: '',
                                  myUserName: null,
                                  useFullNames: true,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(width: 2, color: Colors.white24),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _formatDateHebrew(_effectiveTomorrow),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                textTheme: Theme.of(context).textTheme.apply(
                                      bodyColor: Colors.white,
                                      displayColor: Colors.white,
                                    ),
                              ),
                              child: Directionality(
                                textDirection: TextDirection.rtl,
                                child: CourtReservations(
                                  key: ValueKey('tomorrow_$_refreshKey'),
                                  selectedDate: _effectiveTomorrow,
                                  selectedPartner: '',
                                  myUserName: null,
                                  useFullNames: true,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const _TvMarquee(),
          ],
        ),
      ),
    );
  }
}

class _TvMarquee extends StatefulWidget {
  const _TvMarquee();

  @override
  State<_TvMarquee> createState() => _TvMarqueeState();
}

class _TvMarqueeState extends State<_TvMarquee> {
  String _text = '';
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
      final nextHourProb = _nextHourPrecipProbability(
        data,
        currentTime,
      );
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
      final hiRounded = hiC.round();
      final windDirText = _windDirectionHebrew(windDir);
      final windRounded = windSpeed.round();
      final rainProbRounded = nextHourProb.round();
      _setHeatText(
        'עומס חום: ${hiRounded}° – $label | סיכוי לגשם בשעה הקרובה: ${rainProbRounded}% | רוח: ${windRounded} קמ״ש $windDirText',
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
    if (tempF < 80) {
      return tempC;
    }
    final t = tempF;
    final r = rh;
    double hi = -42.379 +
        2.04901523 * t +
        10.14333127 * r +
        -0.22475541 * t * r +
        -0.00683783 * t * t +
        -0.05481717 * r * r +
        0.00122874 * t * t * r +
        0.00085282 * t * r * r +
        -0.00000199 * t * t * r * r;
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
    return Container(
      height: _heatText == null ? 120 : 160,
      color: Colors.white10,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('tv')
            .doc('marquee')
            .snapshots(),
        builder: (context, snap) {
          _text = (snap.data?.data()?['text'] as String?) ?? '';
          final display =
              _text.trim().isEmpty ? 'ברוכים הבאים למועדון כרמל' : _text.trim();
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_heatText != null)
                    Text(
                      _heatText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  Text(
                    display,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 80,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
