import 'package:flutter/material.dart';

class CourtReservations extends StatefulWidget {
  const CourtReservations({super.key});

  @override
  CourtReservationsState createState() => CourtReservationsState();
}

class CourtReservationsState extends State<CourtReservations> {
  DateTime selectedDate = DateTime.now();
  // Sample data for two courts
  Map<int, bool> court1Reservations = {for (var i = 7; i <= 21; i++) i: false};
  Map<int, bool> court2Reservations = {for (var i = 7; i <= 21; i++) i: false};

  @override
  void initState() {
    super.initState();
    _initializeReservations();
  }

  void _initializeReservations() {
    for (var i = 7; i <= 21; i++) {
      court1Reservations[i] = false;
      court2Reservations[i] = false;
    }
  }

  void reserve(int courtNumber, int hour) {
    setState(() {
      if (courtNumber == 1) {
        // Use the null-aware operator to provide a default value (false)
        court1Reservations[hour] = !(court1Reservations[hour] ?? false);
      } else if (courtNumber == 2) {
        // Use the null-aware operator to provide a default value (false)
        court2Reservations[hour] = !(court2Reservations[hour] ?? false);
      }
    });
  }

  Widget buildCourt(int courtNumber, Map<int, bool> reservations) {
    return Column(
      children: reservations.entries.map((entry) {
        return ListTile(
          title: Text('Court $courtNumber - ${entry.key}:00'),
          trailing: entry.value
              ? Icon(Icons.check, color: Colors.green)
              : Icon(Icons.close, color: Colors.red),
          onTap: () => reserve(courtNumber, entry.key),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            children: <Widget>[
              buildCourt(1, court1Reservations),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: <Widget>[
              buildCourt(2, court2Reservations),
            ],
          ),
        ),
      ],
    );
  }
}
