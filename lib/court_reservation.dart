import 'package:flutter/material.dart';

class CourtReservations extends StatefulWidget {
  const CourtReservations({super.key});

  @override
  CourtReservationsState createState() => CourtReservationsState();
}

class CourtReservationsState extends State<CourtReservations> {
  DateTime selectedDate = DateTime.now();
  // A list of maps for each court's reservations
  List<Map<int, bool>> courtsReservations = List.generate(3, (_) => {});

  @override
  void initState() {
    super.initState();
    _initializeReservations();
  }

  dynamic _initializeReservations() {
    for (var court in courtsReservations) {
      for (var i = 7; i <= 21; i++) {
        court[i] = false;
      }
    }
  }

  void reserve(int courtNumber, int hour) {
    setState(() {
      courtsReservations[courtNumber][hour] = true;
    });
  }

  Widget _buildCourtReservations(int courtNumber) {
    Map<int, bool> reservations = courtsReservations[courtNumber];
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reservations.length,
      itemBuilder: (context, index) {
        int hour = reservations.keys.elementAt(index);
        String displayHour = hour > 12 ? '${hour - 12} PM' : '$hour AM';
        bool isReserved =
            reservations[hour] ?? false; // Use the null-aware operator

        return ListTile(
          title: Text('Court ${courtNumber + 1} - $displayHour'),
          trailing: isReserved
              ? const Icon(Icons.check, color: Colors.green)
              : const Icon(Icons.close, color: Colors.red),
          onTap: () => reserve(courtNumber, hour),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('מועדון הכרמל')),
      body: Column(
        children: <Widget>[
          Text('Date: ${selectedDate.toLocal()}'),
          for (int i = 0; i < courtsReservations.length; i++)
            Expanded(
              child: _buildCourtReservations(i),
            ),
        ],
      ),
    );
  }
}
