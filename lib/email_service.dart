import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Sends ONE email to BOTH the originator and the partner.
Future<void> sendEmailToBoth({
  required String originatorEmail,
  required String originatorName,
  required String partnerEmail,
  required String partnerName,
  required DateTime date,
  required int hour,
}) async {
  // 1) Set up your SMTP server
  final smtpServer = gmail('carmelclub55@gmail.com', 'aBcD12345678');

  // 2) Format date and hour as strings
  final formattedDate = "${date.day}-${date.month}-${date.year}";
  final formattedHour = hour.toString().padLeft(2, '0');

  // 3) Create your message
  final message = Message()
    // The 'from' field
    ..from = Address('carmelclub55@gmail.com', 'Carmel Club')
    // Add BOTH recipients (they will each receive the same email)
    ..recipients.add(originatorEmail)
    ..recipients.add(partnerEmail)
    // Set your subject
    ..subject = 'Reservation Confirmation - $formattedDate, $formattedHour:00'
    // Use text or HTML
    ..text = '''
Hello $originatorName and $partnerName,

Your reservation is confirmed!

Date: $formattedDate
Time: $formattedHour:00

- Originator: $originatorName
- Partner: $partnerName

Thank you,
Carmel Club
''';

  // 4) Send it
  try {
    final sendReport = await send(message, smtpServer);
    print('Email sent: $sendReport');
  } on MailerException catch (e) {
    print('Email not sent: $e');
    for (var p in e.problems) {
      print('Problem: ${p.code}: ${p.msg}');
    }
  }
}
