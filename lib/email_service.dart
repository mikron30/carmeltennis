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

Future<void> sendReservationEmail({
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

  final data = {
    "to": originatorEmail,
    "cc": partnerEmail,
    "bcc": "mikron30@gmail.com;beni@cohensys.com",
    "subject": subject,
    "html": message,
  };

  String url =
      "https://email-service-496722208859.us-central1.run.app/sendMail";

  Dio dio = Dio(BaseOptions(
    baseUrl: url,
    receiveDataWhenStatusError: true,
    connectTimeout: const Duration(seconds: 120),
    receiveTimeout: const Duration(seconds: 120),
    headers: {
      HttpHeaders.contentTypeHeader: "application/json",
    },
  ));

  try {
    await dio.post(url, data: data);
  } on DioException catch (e) {
    print("❌ Failed to send email: ${e.message}");
  }
}
