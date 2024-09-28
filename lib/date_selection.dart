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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          selectedDate, // Set the initial date to the currently selected date or today
      firstDate: DateTime(2000), // Allow any date from the year 2000
      lastDate: DateTime(2100), // Allow any date up to the year 2100
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
