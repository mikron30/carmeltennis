import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, PhoneAuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemNavigator.pop()
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart'; // For GoRouter

import 'app_state.dart';
import 'court_reservation.dart';
import 'date_selection.dart';
import 'src/authentication.dart';
import 'user_manager.dart';
import 'hoilday.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'users_management.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<HomePage> {
  bool isManager = false;
  DateTime? selectedDate;
  String? selectedPartner;
  List<String> suggestionsList = []; // Assuming this is populated elsewhere
  TextEditingController _partnerController = TextEditingController();
  List<String> allUsers = []; // Fetched from your backend
  List<String> lastSelectedPartners =
      []; // Fetched from SharedPreferences or similar
  String? myUserName;

  bool isTodaySelected = true; // Default to "Today" being selected
  bool isTomorrowSelected = false; // Initially, tomorrow is not selected

  // New variable for email notifications preference
  bool _receiveEmails = false;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Load the email preference for the user
      _loadEmailPreference();

      // Fetch the user name before fetching the last 5 partners
      fetchMyUserName().then((_) {
        setState(() {
          // Rebuild the UI after the username is fetched
        });

        // Fetch the last 5 reserved partners after the username has been fetched
        fetchLastFivePartners(user.email!).then((partners) {
          setState(() {
            lastSelectedPartners = partners;
          });
        });
        // Fetch all users
        fetchAllUsers();
      });
    }
  }

  /// Loads the user's email notification preference from Firestore.
  Future<void> _loadEmailPreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String email = user.email!;
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users_2024')
          .where('מייל', isEqualTo: email)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        Map<String, dynamic> data =
            querySnapshot.docs.first.data() as Map<String, dynamic>;
        bool pref = data['receiveReservationEmails'] ?? false;
        setState(() {
          _receiveEmails = pref;
        });
      }
    }
  }

  /// Toggles the email notification preference and updates Firestore.
  Future<void> _toggleEmailPreference(bool newValue) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String userEmail = user.email!;
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users_2024')
          .where('מייל', isEqualTo: userEmail)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        DocumentReference docRef = querySnapshot.docs.first.reference;
        await docRef.update({'receiveReservationEmails': newValue});
        setState(() {
          _receiveEmails = newValue;
        });
      }
    }
  }

  void updateSelectedDate(BuildContext context, DateTime newDate) {
    DateTime today = DateTime.now();
    DateTime normalizedToday = DateTime(today.year, today.month, today.day);
    DateTime normalizedNewDate =
        DateTime(newDate.year, newDate.month, newDate.day);

    setState(() {
      selectedDate = newDate;
      if (normalizedNewDate.isAtSameMomentAs(normalizedToday)) {
        isTodaySelected = true;
        isTomorrowSelected = false;
      } else {
        isTodaySelected = false;
        isTomorrowSelected = true;
      }
    });
  }

  void fetchAllUsers() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        await Future.delayed(Duration(seconds: 1));
        currentUser = FirebaseAuth.instance.currentUser;
      }
      if (currentUser?.email == null) {
        print("User email is null. Unable to fetch users.");
        return;
      }
      String userEmail = currentUser!.email!;
      if (myUserName == null) {
        myUserName = await UserManager.instance.getUsernameByEmail(userEmail);
      }
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('users_2024').get();
      List<String> fetchedUsers = querySnapshot.docs.map((doc) {
        String firstName = doc['שם פרטי'];
        String lastName = doc['שם משפחה'];
        return '$firstName $lastName'.trim();
      }).toList();
      if (!isManager && myUserName != null) {
        fetchedUsers.removeWhere((userName) =>
            userName.trim().toLowerCase() == myUserName?.trim().toLowerCase());
      }
      setState(() {
        suggestionsList = fetchedUsers;
      });
    } catch (e) {
      print("Error fetching users: $e");
    }
  }

  Future<List<String>> fetchLastFivePartners(String userEmail) async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users_2024')
        .where('מייל', isEqualTo: userEmail)
        .get();
    List<String> lastFivePartners = [];
    if (querySnapshot.docs.isNotEmpty) {
      DocumentSnapshot userDoc = querySnapshot.docs.first;
      if (userDoc.exists && userDoc.data() != null) {
        try {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          lastFivePartners = List<String>.from(data['lastFivePartners'] ?? []);
          lastFivePartners = lastFivePartners.map((partner) {
            return partner.startsWith('!') ? partner.substring(1) : partner;
          }).toList();
        } catch (e) {
          lastFivePartners = [];
        }
      }
    }
    if (isManager) {
      lastFivePartners.add("הזמנת מנהל");
    }
    return lastFivePartners;
  }

  Future<void> fetchMyUserName() async {
    try {
      String? userEmail = FirebaseAuth.instance.currentUser?.email;
      if (userEmail != null) {
        myUserName = await UserManager.instance.getUsernameByEmail(userEmail);
        isManager = myUserName == "אודי אש" ||
            myUserName == "רני לפלר" ||
            myUserName == "עפר בן ישי" ||
            myUserName == "מיקי זילברשטיין" ||
            myUserName == "מועדון כרמל";
      }
    } catch (e) {}
  }

  Future<String?> _showCustomMessageDialog(BuildContext context) async {
    TextEditingController messageController = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('הכנס הודעה'),
          content: TextField(
            controller: messageController,
            decoration: const InputDecoration(hintText: 'הודעה עבור ההזמנה'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ביטול'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('אישור'),
              onPressed: () {
                Navigator.of(context).pop('!' + messageController.text);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final bool loggedIn = user != null;

    return Scaffold(
      body: loggedIn ? _buildMainContent() : _buildLoginScreen(),
      drawer: loggedIn ? _buildDrawer() : null,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildMainContent() {
    DateTime today = DateTime.now();
    DateTime tomorrow = today.add(const Duration(days: 1));
    String formattedToday = DateFormat('dd').format(today);
    String formattedTomorrow = DateFormat('dd').format(tomorrow);
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final today = DateTime.now();
        final tomorrow = today.add(const Duration(days: 1));

        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          // Swipe Right → go to tomorrow
          if (_isSameDay(selectedDate ?? today, today)) {
            updateSelectedDate(context, tomorrow);
          }
        } else if (details.primaryVelocity != null &&
            details.primaryVelocity! < 0) {
          // Swipe Left → go to today
          if (_isSameDay(selectedDate ?? today, tomorrow)) {
            updateSelectedDate(context, today);
          }
        }
      },
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Builder(
                  builder: (BuildContext context) {
                    return IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                      color: isManager ? Colors.red : null,
                    );
                  },
                ),
                const SizedBox(width: 8),
                if (isManager) ...[
                  Flexible(
                    flex: 1,
                    child: DateSelector(
                      onDateSelected: (DateTime date) {
                        updateSelectedDate(context, date);
                      },
                    ),
                  ),
                ] else ...[
                  Flexible(
                    flex: 1,
                    child: Row(
                      children: [
                        Flexible(
                          child: ElevatedButton(
                            onPressed: () {
                              updateSelectedDate(context, today);
                            },
                            child: Text(
                              formattedToday,
                              style: TextStyle(
                                fontWeight: isTodaySelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: ElevatedButton(
                            onPressed: () {
                              updateSelectedDate(context, tomorrow);
                            },
                            child: Text(
                              formattedTomorrow,
                              style: TextStyle(
                                fontWeight: isTomorrowSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Flexible(
                  flex: 1,
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
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
                          setState(() {
                            selectedPartner = selection;
                            _partnerController.text = selection;
                          });
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
                              hintText: "שותף",
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.arrow_drop_down),
                                onPressed: () {
                                  showMenu<String>(
                                    context: context,
                                    position:
                                        RelativeRect.fromLTRB(0, 40, 0, 0),
                                    items: lastSelectedPartners
                                        .map((String partner) {
                                      return PopupMenuItem<String>(
                                        value: partner,
                                        child: Text(partner),
                                      );
                                    }).toList(),
                                  ).then((String? newValue) {
                                    if (newValue != null) {
                                      if (newValue == "הזמנת מנהל") {
                                        _showCustomMessageDialog(context)
                                            .then((customMessage) {
                                          if (customMessage != null &&
                                              customMessage.isNotEmpty) {
                                            setState(() {
                                              selectedPartner = customMessage;
                                              _partnerController.text =
                                                  customMessage;
                                            });
                                          }
                                        });
                                      } else {
                                        setState(() {
                                          selectedPartner = newValue;
                                          _partnerController.text = newValue;
                                        });
                                      }
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
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    final String option =
                                        options.elementAt(index);
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer<ApplicationState>(
              builder: (context, appState, _) {
                fetchMyUserName();
                return CourtReservations(
                  selectedDate: selectedDate ?? DateTime.now(),
                  selectedPartner: selectedPartner ?? '',
                  myUserName: myUserName,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Please log in to continue',
            style: TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 20),
          AuthFunc(
            loggedIn: false,
            signOut: () async {
              await FirebaseAuth.instance.signOut();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  /// Build the drawer including the new email notification checkbox.
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Email Notification Preference Checkbox
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(10),
              color: Colors.blue[50],
            ),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: CheckboxListTile(
              value: _receiveEmails,
              title: const Text('אפשר קבלת מייל',
                  style: TextStyle(color: Colors.blue)),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (bool? newValue) {
                if (newValue != null) {
                  _toggleEmailPreference(newValue);
                }
              },
            ),
          ),
          // Sign out option
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(10),
              color: Colors.blue[50],
            ),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.blue),
              title: const Text('התנתק', style: TextStyle(color: Colors.blue)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                setState(() {});
                Navigator.of(context).pop();
              },
            ),
          ),
          // Change Password option
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(10),
              color: Colors.blue[50],
            ),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: const Icon(Icons.lock, color: Colors.blue),
              title:
                  const Text('שנה סיסמא', style: TextStyle(color: Colors.blue)),
              onTap: () {
                GoRouter.of(context).push('/change-password');
              },
            ),
          ),
          if (isManager)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(10),
                color: Colors.blue[50],
              ),
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                leading: const Icon(Icons.lock, color: Colors.blue),
                title: const Text('ניהול חגים',
                    style: TextStyle(color: Colors.blue)),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => AddHolidayScreen()));
                },
              ),
            ),
          if (isManager)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(10),
                color: Colors.blue[50],
              ),
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                leading: const Icon(Icons.group, color: Colors.blue),
                title: const Text('ניהול משתמשים',
                    style: TextStyle(color: Colors.blue)),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => ManageUsersScreen()),
                  );
                },
              ),
            ),
          // Exit option
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(10),
              color: Colors.red[50],
            ),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: const Icon(Icons.close, color: Colors.red),
              title: const Text('יציאה', style: TextStyle(color: Colors.red)),
              onTap: () {
                SystemNavigator.pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}
