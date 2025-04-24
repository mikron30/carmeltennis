import 'dart:io';
import 'package:dio/dio.dart';

BaseOptions options = BaseOptions(
  receiveDataWhenStatusError: true,
  connectTimeout: const Duration(seconds: 120),
  receiveTimeout: const Duration(seconds: 120),
);

String buildReservationEmailHtml({
  required String originatorName,
  required String partnerName,
  required String formattedDate,
  required String formattedHour,
  required int courtNumber,
  required bool isCancellation,
}) {
  final title = isCancellation ? "ביטול הזמנה" : "אישור הזמנה";
  final status = isCancellation ? "בוטלה" : "אושרה";
  final byLabel = isCancellation ? "המבטל" : "המזמין";
  final headerColor = isCancellation ? "#d9534f" : "#333";

  return '''
<html dir="rtl" lang="he">
  <head>
    <meta charset="utf-8">
    <style>
      body {
        font-family: Arial, sans-serif;
        background-color: #f2f2f2;
        margin: 0;
        padding: 0;
        direction: rtl;
      }
      .container {
        background-color: #fff;
        margin: 30px auto;
        padding: 20px;
        max-width: 600px;
        border: 1px solid #ddd;
        box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        text-align: right;
      }
      .header {
        text-align: center;
        padding-bottom: 20px;
      }
      .header h1 {
        color: $headerColor;
        margin: 0;
      }
      .content {
        font-size: 16px;
        color: #333;
        line-height: 1.6;
      }
      .content p {
        margin: 10px 0;
      }
      .footer {
        text-align: center;
        font-size: 16px;
        color: #333;
        margin-top: 20px;
        font-weight: bold;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <h1>$title</h1>
      </div>
      <div class="content">
        <p>שלום <strong>$originatorName</strong> ו-<strong>$partnerName</strong></p>
        <p>ההזמנה שלכם <strong>$status</strong></p>
        <p><strong>תאריך:</strong> $formattedDate</p>
        <p><strong>שעה:</strong> $formattedHour:00</p>
        <p><strong>מספר מגרש:</strong> $courtNumber</p>
        <hr>
        <p><strong>$byLabel:</strong> $originatorName</p>
        <p><strong>שותף:</strong> $partnerName</p>
      </div>
      <div class="footer">
        <p>בברכה<br><strong style="font-size:18px;">מועדון טניס כרמל</strong></p>
      </div>
    </div>
  </body>
</html>
''';
}

Future<void> sendReservationEmails({
  required String originatorEmail,
  required String originatorName,
  required bool originatorWantsEmail,
  required String? partnerEmail,
  required String partnerName,
  required bool partnerWantsEmail,
  required DateTime date,
  required int hour,
  required int courtNumber,
  required bool isCancellation,
}) async {
  final formattedDate = "${date.day}-${date.month}-${date.year}";
  final formattedHour = hour.toString().padLeft(2, '0');

  final subjectPrefix = isCancellation ? "ביטול הזמנה" : "אישור הזמנה";
  final subject =
      "$subjectPrefix - $originatorName, $partnerName - $formattedDate $formattedHour:00 - מגרש $courtNumber";

  final html = buildReservationEmailHtml(
    originatorName: originatorName,
    partnerName: partnerName,
    formattedDate: formattedDate,
    formattedHour: formattedHour,
    courtNumber: courtNumber,
    isCancellation: isCancellation,
  );

  final dio = Dio(BaseOptions(
    baseUrl: "https://email-service-496722208859.us-central1.run.app/sendMail",
    receiveDataWhenStatusError: true,
    connectTimeout: const Duration(seconds: 120),
    receiveTimeout: const Duration(seconds: 120),
    headers: {
      HttpHeaders.contentTypeHeader: "application/json",
    },
  ));

// שלח ליוזם אם הוא רוצה
  if (originatorWantsEmail) {
    try {
      await dio.post("", data: {
        "to": originatorEmail,
        "subject": subject,
        "html": html,
      });
    } catch (e) {
      print("❌ Failed to send to originator: $e");
    }
  }

// שלח לשותף אם הוא רוצה
  if (partnerWantsEmail && partnerEmail != null && partnerEmail.isNotEmpty) {
    try {
      await dio.post("", data: {
        "to": partnerEmail,
        "subject": subject,
        "html": html,
      });
    } catch (e) {
      print("❌ Failed to send to partner: $e");
    }
  }

// אם אף אחד מהם לא רצה – שלח רק אליך
  if (!originatorWantsEmail && !partnerWantsEmail) {
    try {
      await dio.post("", data: {
        "to": "mikron30@gmail.com",
        "subject": subject,
        "html": html,
      });
    } catch (e) {
      print("❌ Failed to send to mikron30 (fallback only): $e");
    }
  } else {
    // תמיד שלח גם אליך בנוסף
    try {
      await dio.post("", data: {
        "to": "mikron30@gmail.com",
        "subject": subject,
        "html": html,
      });
    } catch (e) {
      print("❌ Failed to send to mikron30 (in addition): $e");
    }
  }
}

Future<void> notifyUsersByEmail({
  required bool toOriginator,
  required bool toPartner,
  required String originatorEmail,
  required String originatorName,
  required String partnerEmail,
  required String partnerName,
  required DateTime date,
  required int hour,
  required int courtNumber,
  required bool isCancellation,
}) async {
  final formattedDate = "${date.day}-${date.month}-${date.year}";
  final formattedHour = hour.toString().padLeft(2, '0');

  final titlePrefix = isCancellation ? "ביטול הזמנה" : "אישור הזמנה";
  final subject =
      "$titlePrefix - $originatorName, $partnerName - $formattedDate $formattedHour:00 - מגרש $courtNumber";

  final message = buildReservationEmailHtml(
    originatorName: originatorName,
    partnerName: partnerName,
    formattedDate: formattedDate,
    formattedHour: formattedHour,
    courtNumber: courtNumber,
    isCancellation: isCancellation,
  );

  const String serviceUrl =
      "https://email-service-496722208859.us-central1.run.app/sendMail";

  Dio dio = Dio(BaseOptions(
    baseUrl: serviceUrl,
    receiveDataWhenStatusError: true,
    connectTimeout: const Duration(seconds: 120),
    receiveTimeout: const Duration(seconds: 120),
    headers: {
      HttpHeaders.contentTypeHeader: "application/json",
    },
  ));

  Future<void> send(String email) async {
    final data = {
      "to": email,
      "subject": subject,
      "html": message,
    };

    try {
      await dio.post(serviceUrl, data: data);
    } catch (e) {
      print("❌ Failed to send email to $email: $e");
    }
  }

  // שלח לפי ההעדפות
  if (toOriginator) await send(originatorEmail);
  if (toPartner) await send(partnerEmail);

  // אם אף אחד מהם לא רצה, שלח למיקי
  if (!toOriginator && !toPartner) {
    await send("mikron30@gmail.com");
  }
}
