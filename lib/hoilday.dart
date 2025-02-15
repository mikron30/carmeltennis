import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting

class AddHolidayScreen extends StatefulWidget {
  @override
  _AddHolidayScreenState createState() => _AddHolidayScreenState();
}

class _AddHolidayScreenState extends State<AddHolidayScreen> {
  DateTime selectedDate = DateTime.now();
  String holidayType = 'חג'; // Default is 3 courts available
  bool isDelete = false; // Checkbox for delete
  List<DocumentSnapshot> holidays = []; // Holds fetched holidays
  Future<void> fetchHolidays() async {
    try {
      var querySnapshot =
          await FirebaseFirestore.instance.collection('holidays').get();
      setState(() {
        holidays = querySnapshot.docs;
      });
    } catch (e) {
      // Handle the error
    }
  }

  @override
  void initState() {
    super.initState();
    fetchHolidays(); // Fetch holidays when the widget is initialized
  }

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
        'holidayType':
            holidayType, // Stores 'noCourt', 'singleCourt', or 'threeCourts'
      });
      // Optionally show a confirmation message or handle errors
    }
    // Refresh the list of holidays after add/delete operation
    fetchHolidays();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add/Delete Holiday"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () => _selectDate(context),
              child: const Text('Select date'),
            ),
            Text(
              'Selected date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
            ),
// Dropdown for selecting holiday type
            DropdownButton<String>(
              value: holidayType,
              items: [
                DropdownMenuItem(
                  value: 'אין מגרשים',
                  child: Text('אין מגרשים'),
                ),
                DropdownMenuItem(
                  value: 'מגרש אחד',
                  child: Text('מגרש אחד'),
                ),
                DropdownMenuItem(
                  value: 'חג',
                  child: Text('שלושה מגרשים, חג, כמו שבת'),
                ),
                DropdownMenuItem(
                  value: 'ערב חג',
                  child: Text('ערב חג, כמו שישי'),
                ),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  holidayType = newValue!;
                });
              },
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
                const Text("Delete Holiday"),
              ],
            ),
            ElevatedButton(
              onPressed: _handleHolidayFirestore,
              child: Text(isDelete ? 'Delete Holiday' : 'Add Holiday'),
            ),
// List of holidays with their types
            Expanded(
              child: ListView.builder(
                itemCount: holidays.length,
                itemBuilder: (context, index) {
                  final holiday = holidays[index];
                  String holidayStatus;
                  switch (holiday['holidayType']) {
                    case 'אין מגרשים':
                      holidayStatus = 'אין מגרשים';
                      break;
                    case 'מגרש אחד':
                      holidayStatus = 'מגרש אחד';
                      break;
                    case 'ערב חג':
                      holidayStatus = 'ערב חג';
                      break;
                    default:
                      holidayStatus = 'חג';
                  }
                  return ListTile(
                    title: Text(holiday['date']),
                    subtitle: Text(holidayStatus),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
