import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting

class AddHolidayScreen extends StatefulWidget {
  @override
  _AddHolidayScreenState createState() => _AddHolidayScreenState();
}

class _AddHolidayScreenState extends State<AddHolidayScreen> {
  DateTime selectedDate = DateTime.now();
  bool isErev = false;
  bool isDelete = false; // Checkbox for delete

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _handleHolidayFirestore() async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

    if (isDelete) {
      // If isDelete is true, delete the document for the selected date
      await db.collection('holidays').doc(formattedDate).delete();
      // Optionally show a confirmation message or handle errors
    } else {
      // If isDelete is false, add or update the holiday document
      await db.collection('holidays').doc(formattedDate).set({
        'date': formattedDate,
        'isErev': isErev,
      });
      // Optionally show a confirmation message or handle errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add/Delete Holiday"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () => _selectDate(context),
              child: Text('Select date'),
            ),
            Text(
              'Selected date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  value: isErev,
                  onChanged: (bool? value) {
                    setState(() {
                      isErev = value!;
                    });
                  },
                ),
                Text("Is Erev Holiday"),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  value: isDelete,
                  onChanged: (bool? value) {
                    setState(() {
                      isDelete = value!;
                    });
                  },
                ),
                Text("Delete Holiday"),
              ],
            ),
            ElevatedButton(
              onPressed: _handleHolidayFirestore,
              child: Text(isDelete ? 'Delete Holiday' : 'Add Holiday'),
            ),
          ],
        ),
      ),
    );
  }
}
