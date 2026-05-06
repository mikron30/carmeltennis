// Server-anchored UTC clock.
//
// Primary source: Firestore `serverTimestamp` (Google-backed, the app already
// uses Firebase). Falls back to public time APIs (worldtimeapi / timeapi.io
// JSON) and HTTP `Date` headers for the unauthenticated boot window before
// sign-in completes. The anchored UTC value is then ticked forward using a
// [Stopwatch] — the device's monotonic counter, unaffected by manual wall-
// clock changes. Falls back to device time only if every sync source fails;
// once any sync succeeds the device's wall clock is never read for time.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ServerTime {
  ServerTime._();

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    sendTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  static DateTime? _anchorUtc;
  static final Stopwatch _stopwatch = Stopwatch();
  static bool _syncing = false;
  static DateTime? _lastFailedAttempt;

  // Cool-down between failed sync attempts when called from [utcNow].
  // Prevents pounding endpoints on every UI rebuild while offline.
  static const Duration _failureBackoff = Duration(seconds: 30);

  // Reject server responses more than this far from the device clock.
  // Captive portals or compromised endpoints occasionally serve garbage; a
  // year is loose enough to tolerate a wrong device clock while catching
  // obviously bogus values.
  static const Duration _maxAcceptableSkew = Duration(days: 365);

  /// Whether the clock has been successfully synced with a server at least
  /// once. Until this is true, [utcNow] falls back to the device clock.
  static bool get isSynced => _anchorUtc != null;

  /// Synchronize once. Safe to call multiple times — concurrent calls are
  /// coalesced. Errors are swallowed so app boot is never blocked by network
  /// failure; the next [refresh] will catch up.
  static Future<void> init() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final serverUtc = await _fetchServerUtc();
      if (serverUtc != null && _isPlausible(serverUtc)) {
        _anchorUtc = serverUtc;
        _stopwatch
          ..reset()
          ..start();
        _lastFailedAttempt = null;
      } else {
        _lastFailedAttempt = DateTime.now();
      }
    } finally {
      _syncing = false;
    }
  }

  /// Re-sync. Call periodically to correct for monotonic-clock drift over
  /// long sessions, and on app-resume to recover from a backgrounded tab
  /// where the [Stopwatch] froze.
  static Future<void> refresh() async {
    _lastFailedAttempt = null;
    await init();
  }

  /// Current UTC moment from the server-anchored clock. If a sync has never
  /// succeeded, falls back to the device clock and triggers a background
  /// sync (with a cool-down so we don't hammer endpoints).
  static DateTime utcNow() {
    final anchor = _anchorUtc;
    if (anchor == null) {
      _maybeRetryInBackground();
      return DateTime.now().toUtc();
    }
    return anchor.add(_stopwatch.elapsed);
  }

  static void _maybeRetryInBackground() {
    if (_syncing) return;
    final last = _lastFailedAttempt;
    if (last != null &&
        DateTime.now().difference(last) < _failureBackoff) {
      return;
    }
    // ignore: discarded_futures
    init();
  }

  static bool _isPlausible(DateTime serverUtc) {
    final delta = serverUtc.difference(DateTime.now().toUtc()).abs();
    return delta <= _maxAcceptableSkew;
  }

  /// Try Firestore first (Google-backed, no third-party uptime), then a
  /// CORS-friendly JSON endpoint (works on web), then HTTP `Date` headers
  /// from common always-on endpoints.
  static Future<DateTime?> _fetchServerUtc() async {
    final fs = await _fetchFirestoreTime();
    if (fs != null) return fs;
    final jsonTime = await _fetchJsonTime();
    if (jsonTime != null) return jsonTime;
    return _fetchDateHeader();
  }

  /// Round-trips a `FieldValue.serverTimestamp()` write through the user's
  /// Firestore doc. Returns `null` (so callers fall through) if the user is
  /// not yet authenticated or any error occurs.
  static Future<DateTime?> _fetchFirestoreTime() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      final ref = FirebaseFirestore.instance
          .collection('users_2024')
          .doc(uid)
          .collection('_meta')
          .doc('time_ping');
      await ref.set(
        {'t': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      final snap = await ref.get();
      final t = snap.data()?['t'];
      if (t is Timestamp) return t.toDate().toUtc();
    } catch (e) {
      // Most likely permission-denied (rules) or transient network error.
      // Visible in dev logs; quiet in prod.
      // ignore: avoid_print
      assert(() {
        // ignore: avoid_print
        print('ServerTime: Firestore source unavailable ($e)');
        return true;
      }());
    }
    return null;
  }

  static Future<DateTime?> _fetchJsonTime() async {
    const endpoints = <String>[
      'https://worldtimeapi.org/api/timezone/Etc/UTC',
      'https://timeapi.io/api/Time/current/zone?timeZone=UTC',
    ];
    for (final url in endpoints) {
      try {
        final res = await _dio.get<Map<String, dynamic>>(
          url,
          options: Options(
            responseType: ResponseType.json,
            validateStatus: (s) => s != null && s < 500,
          ),
        );
        final data = res.data;
        if (data == null) continue;
        // worldtimeapi: utc_datetime / unixtime
        final utcStr = data['utc_datetime'] as String?;
        if (utcStr != null) {
          final parsed = DateTime.tryParse(utcStr);
          if (parsed != null) return parsed.toUtc();
        }
        final unix = data['unixtime'];
        if (unix is int) {
          return DateTime.fromMillisecondsSinceEpoch(unix * 1000, isUtc: true);
        }
        // timeapi.io: dateTime "2026-05-03T14:21:30.123" (UTC because we asked for it)
        final dt = data['dateTime'] as String?;
        if (dt != null) {
          final parsed = DateTime.tryParse(dt);
          if (parsed != null) {
            return DateTime.utc(parsed.year, parsed.month, parsed.day,
                parsed.hour, parsed.minute, parsed.second);
          }
        }
      } catch (_) {
        // try next endpoint
      }
    }
    return null;
  }

  static Future<DateTime?> _fetchDateHeader() async {
    const endpoints = <String>[
      'https://www.google.com/generate_204',
      'https://cloudflare.com/cdn-cgi/trace',
      'https://www.apple.com/library/test/success.html',
    ];
    for (final url in endpoints) {
      try {
        final res = await _dio.head<void>(
          url,
          options: Options(
            followRedirects: true,
            validateStatus: (s) => s != null && s < 500,
          ),
        );
        final dateHeader = res.headers.value('date');
        if (dateHeader == null) continue;
        final parsed = HttpDateParser.parse(dateHeader);
        if (parsed != null) return parsed;
      } catch (_) {
        // try next endpoint
      }
    }
    return null;
  }
}

/// Parses RFC 7231 IMF-fixdate / RFC 850 / asctime HTTP `Date` headers.
/// Mirrors `HttpDate.parse` from `dart:io` so this works on web too.
class HttpDateParser {
  static const _months = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };

  /// Returns the UTC moment encoded in [header], or `null` if it can't parse.
  static DateTime? parse(String header) {
    try {
      // IMF-fixdate: "Sun, 06 Nov 1994 08:49:37 GMT"
      final imf = RegExp(
        r'^[A-Z][a-z]{2}, (\d{2}) ([A-Z][a-z]{2}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
      );
      final m = imf.firstMatch(header.trim());
      if (m != null) {
        final day = int.parse(m.group(1)!);
        final month = _months[m.group(2)!];
        final year = int.parse(m.group(3)!);
        final hour = int.parse(m.group(4)!);
        final minute = int.parse(m.group(5)!);
        final second = int.parse(m.group(6)!);
        if (month == null) return null;
        return DateTime.utc(year, month, day, hour, minute, second);
      }
    } catch (_) {/* fall through */}
    // Last resort: try Dart's built-in parser (handles ISO 8601 etc.).
    return DateTime.tryParse(header)?.toUtc();
  }
}
