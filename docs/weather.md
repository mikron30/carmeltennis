# Weather in Hero Day-Toggle — Spec

Status: **Not implemented.** Constants are commented out in `lib/booking_screen_v31.dart` (`_weatherToday` / `_weatherTomorrow`); the `HeroStrip` is currently called with `todayTemp: null, tomorrowTemp: null`, which the `_DayToggle._segment` widget already handles by hiding the temperature span.

## Goal

Show today's and tomorrow's forecast high (°C) inside the segmented day-toggle pill in the hero. Color the temp clay/warn when it's hot (>27°C) so members can pick the cooler day at a glance.

## API choice

[Open-Meteo](https://open-meteo.com) — free, no API key, no auth, generous rate limits. Endpoint:

```
https://api.open-meteo.com/v1/forecast
  ?latitude=32.8156&longitude=34.9892        // Haifa / Carmel club coordinates — adjust if there's a more exact spot
  &daily=temperature_2m_max
  &timezone=Asia/Jerusalem
  &forecast_days=2
```

Response `daily.temperature_2m_max` is `[todayHigh, tomorrowHigh]`. Round to int.

## Local cache

Cache the response in `SharedPreferences` (already a project dep, see `pubspec.yaml:46`) for **3 hours**.

```dart
// keys
const _kWeatherTodayKey = 'weather.today_c';
const _kWeatherTomorrowKey = 'weather.tomorrow_c';
const _kWeatherFetchedAtKey = 'weather.fetched_at_ms';
const _kWeatherDateKey = 'weather.date_yyyymmdd';   // tracks which "day-pair" the cache is for
const _kWeatherTtl = Duration(hours: 3);
```

Cache is **invalid** if any of these are true:
- The fetched-at timestamp is older than 3h.
- `weather.date_yyyymmdd` doesn't match today's date (the "today" temp would now belong to "yesterday").

A new file `lib/weather_service.dart`:

```dart
class WeatherSnapshot {
  final int todayC;
  final int tomorrowC;
  final DateTime fetchedAt;
  const WeatherSnapshot(this.todayC, this.tomorrowC, this.fetchedAt);
}

class WeatherService {
  WeatherService._();
  static final instance = WeatherService._();

  Future<WeatherSnapshot?> get() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = _readCache(prefs);
    if (cached != null) return cached;
    try {
      final fresh = await _fetch();
      await _writeCache(prefs, fresh);
      return fresh;
    } catch (_) {
      // On network failure, return the stale cache if we have it (better than nothing).
      return _readCache(prefs, ignoreTtl: true);
    }
  }

  WeatherSnapshot? _readCache(SharedPreferences p, {bool ignoreTtl = false}) { ... }
  Future<void> _writeCache(SharedPreferences p, WeatherSnapshot s) async { ... }
  Future<WeatherSnapshot> _fetch() async {
    final r = await Dio().get('https://api.open-meteo.com/v1/forecast', queryParameters: { ... });
    final highs = (r.data['daily']['temperature_2m_max'] as List).cast<num>();
    return WeatherSnapshot(highs[0].round(), highs[1].round(), DateTime.now());
  }
}
```

Use `dio` (already in `pubspec.yaml:49`) so we don't pull in another HTTP package.

## Wiring into the booking screen

In `_BookingScreenV31State`:
1. Add fields `int? _weatherToday`, `int? _weatherTomorrow`.
2. In `initState`, fire-and-forget `WeatherService.instance.get().then((s) { if (mounted && s != null) setState(...); })`. No need to block initial paint — temps appear when ready.
3. Pass them into `HeroStrip(todayTemp: _weatherToday, tomorrowTemp: _weatherTomorrow, ...)`.

Optional: re-fetch on `AppLifecycleState.resumed` so members who leave the app open for half a day still see fresh temps.

## Display rules (already implemented in `_DayToggle._segment`)

- `temp == null` → no temp glyph rendered.
- `temp > 27` → render in `tokens.warn` (or `tokens.clay` when the segment is the active one).
- `temp <= 27` → render in `tokens.clayD` (active) or `Colors.white.withOpacity(0.8)` (inactive).

These thresholds are in `lib/widgets/hero_strip.dart:_DayToggle._segment` — no changes needed when wiring real data.

## Re-enabling steps

1. Create `lib/weather_service.dart` per the sketch above.
2. Uncomment / replace the constants block in `lib/booking_screen_v31.dart`:
   ```dart
   int? _weatherToday;
   int? _weatherTomorrow;
   ```
3. In `initState()`:
   ```dart
   WeatherService.instance.get().then((s) {
     if (!mounted || s == null) return;
     setState(() { _weatherToday = s.todayC; _weatherTomorrow = s.tomorrowC; });
   });
   ```
4. Update the `HeroStrip` call to pass the fields instead of `null`.

## Out of scope (v2+)

- Hourly forecast inline with the time grid (e.g., gust/rain icons next to specific hours).
- Weather-driven slot warnings (e.g., toast "צפוי גשם" on a booking attempt for a rainy slot).
- Multi-location support (only one club).
