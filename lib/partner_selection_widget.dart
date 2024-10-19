import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PartnerSelection extends StatefulWidget {
  final Function(String) onPartnerSelected;

  PartnerSelection({required this.onPartnerSelected});

  @override
  _PartnerSelectionState createState() => _PartnerSelectionState();
}

class _PartnerSelectionState extends State<PartnerSelection> {
  TextEditingController _partnerController = TextEditingController();
  List<String> suggestionsList = []; // For autocomplete suggestions
  List<String> lastSelectedPartners = []; // Last selected partners for dropdown
  String? myUserName;

  @override
  void initState() {
    super.initState();
    fetchUsers(); // Fetch users when the widget is initialized
  }

  Future<void> fetchUsers() async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      if (userEmail == null) return;

      myUserName = await getUserName(userEmail);

      final querySnapshot =
          await FirebaseFirestore.instance.collection('users_2024').get();

      List<String> fetchedUsers = querySnapshot.docs.map((doc) {
        final firstName = doc['שם פרטי'];
        final lastName = doc['שם משפחה'];
        return '$firstName $lastName'.trim();
      }).toList();

      if (myUserName != "מועדון כרמל") {
        fetchedUsers.removeWhere((userName) =>
            userName.trim().toLowerCase() == myUserName?.trim().toLowerCase() ||
            userName == "מועדון כרמל");
      }

      setState(() {
        suggestionsList = fetchedUsers;
      });

      // Fetch last 5 partners (you might want to make this a separate function if needed)
      final lastFivePartners = await fetchLastFivePartners(userEmail);
      setState(() {
        lastSelectedPartners = lastFivePartners;
      });
    } catch (e) {
      print("Error fetching users: $e");
    }
  }

  Future<String> getUserName(String email) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users_2024')
        .where('מייל', isEqualTo: email)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first['שם פרטי'] ?? '';
    }
    return '';
  }

  Future<List<String>> fetchLastFivePartners(String userEmail) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users_2024')
        .where('מייל', isEqualTo: userEmail)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final userDoc = querySnapshot.docs.first;
      try {
        return List<String>.from(userDoc['lastFivePartners'] ?? []);
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        // Autocomplete text box
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return suggestionsList.where((String option) {
              return option
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            widget.onPartnerSelected(selection);
            _partnerController.text = selection; // Update the text box
          },
          fieldViewBuilder: (BuildContext context,
              TextEditingController fieldTextEditingController,
              FocusNode fieldFocusNode,
              VoidCallback onFieldSubmitted) {
            _partnerController = fieldTextEditingController;
            return TextField(
              controller: _partnerController,
              focusNode: fieldFocusNode,
              decoration: InputDecoration(
                hintText: "הכנס שם שותף",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_drop_down),
                  onPressed: () {
                    showMenu<String>(
                      context: context,
                      position: RelativeRect.fromLTRB(0, 40, 0, 0),
                      items: lastSelectedPartners.map((String partner) {
                        return PopupMenuItem<String>(
                          value: partner,
                          child: Text(partner),
                        );
                      }).toList(),
                    ).then((String? newValue) {
                      if (newValue != null) {
                        widget.onPartnerSelected(newValue);
                        _partnerController.text = newValue;
                      }
                    });
                  },
                ),
              ),
            );
          },
          optionsViewBuilder: (BuildContext context,
              AutocompleteOnSelected<String> onSelected,
              Iterable<String> options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                child: Container(
                  width: 300,
                  height: 200,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10.0),
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return GestureDetector(
                        onTap: () {
                          onSelected(option);
                        },
                        child: ListTile(
                          title: Text(option),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
