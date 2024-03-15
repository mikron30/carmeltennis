import 'dart:async';
import 'package:flutter/material.dart';

class DateSelector extends StatefulWidget {
  final Function(DateTime)
      onDateSelected; // Callback function to pass the selected date

  const DateSelector({required this.onDateSelected, super.key});

  @override
  DateSelectorState createState() => DateSelectorState();
}

class DateSelectorState extends State<DateSelector> {
  DateTime selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime tomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: today, // Set initial date to today
      firstDate: today, // Only allow today as the earliest selectable date
      lastDate: tomorrow, // Only allow tomorrow as the latest selectable date
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      widget.onDateSelected(selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _selectDate(context),
      child: Text('${selectedDate.toLocal()}'.split(' ')[0]),
    );
  }
}
