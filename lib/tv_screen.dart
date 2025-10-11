import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _computeEffectiveDates();
    _scheduleMidnightRoll();
    // Tick every minute to update time-sensitive UI if needed
    _tickTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _computeEffectiveDates();
    });
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

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _tickTimer?.cancel();
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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
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
              child: Text(
                display,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
