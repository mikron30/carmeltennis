import 'dart:async';
import 'package:flutter/material.dart';

class DateSelector extends StatefulWidget {
  final Function(DateTime)
      onDateSelected; // Callback function to pass the selected date

  DateSelector({required this.onDateSelected, Key? key}) : super(key: key);

  @override
  DateSelectorState createState() => DateSelectorState();
}

class DateSelectorState extends State<DateSelector> {
  DateTime selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2025),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      // Call the callback function to pass the selected date
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
