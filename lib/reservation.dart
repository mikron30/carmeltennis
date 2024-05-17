class Reservation {
  Reservation(
      {required this.date,
      required this.time,
      required this.user,
      required this.partner,
      required this.court});

  final String date;
  final int time;
  final String user;
  final int court;
  final String partner;
}
