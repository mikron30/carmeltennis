import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeatherSnapshot {
  final int todayC;
  final int tomorrowC;
  final DateTime fetchedAt;
  const WeatherSnapshot(this.todayC, this.tomorrowC, this.fetchedAt);
}

class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  static const _kTodayKey = 'weather.today_c';
  static const _kTomorrowKey = 'weather.tomorrow_c';
  static const _kFetchedAtKey = 'weather.fetched_at_ms';
  static const _kDateKey = 'weather.date_yyyymmdd';
  static const _ttl = Duration(hours: 3);

  // Carmel Tennis Club — Haifa coordinates.
  static const _lat = 32.8156;
  static const _lon = 34.9892;

  Future<WeatherSnapshot?> get() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = _readCache(prefs);
    if (cached != null) return cached;
    try {
      final fresh = await _fetch();
      await _writeCache(prefs, fresh);
      return fresh;
    } catch (_) {
      return _readCache(prefs, ignoreTtl: true);
    }
  }

  WeatherSnapshot? _readCache(SharedPreferences p, {bool ignoreTtl = false}) {
    final today = p.getInt(_kTodayKey);
    final tomorrow = p.getInt(_kTomorrowKey);
    final fetchedAtMs = p.getInt(_kFetchedAtKey);
    final dateKey = p.getString(_kDateKey);
    if (today == null || tomorrow == null || fetchedAtMs == null || dateKey == null) {
      return null;
    }
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (dateKey != todayKey) return null;
    final fetchedAt = DateTime.fromMillisecondsSinceEpoch(fetchedAtMs);
    if (!ignoreTtl && DateTime.now().difference(fetchedAt) > _ttl) return null;
    return WeatherSnapshot(today, tomorrow, fetchedAt);
  }

  Future<void> _writeCache(SharedPreferences p, WeatherSnapshot s) async {
    final todayKey = DateFormat('yyyy-MM-dd').format(s.fetchedAt);
    await p.setInt(_kTodayKey, s.todayC);
    await p.setInt(_kTomorrowKey, s.tomorrowC);
    await p.setInt(_kFetchedAtKey, s.fetchedAt.millisecondsSinceEpoch);
    await p.setString(_kDateKey, todayKey);
  }

  Future<WeatherSnapshot> _fetch() async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
    final r = await dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': _lat,
        'longitude': _lon,
        'daily': 'temperature_2m_max',
        'timezone': 'Asia/Jerusalem',
        'forecast_days': 2,
      },
    );
    final highs = (r.data['daily']['temperature_2m_max'] as List).cast<num>();
    return WeatherSnapshot(highs[0].round(), highs[1].round(), DateTime.now());
  }
}
