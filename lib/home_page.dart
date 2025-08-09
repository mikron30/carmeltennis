import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, PhoneAuthProvider;
import 'package:flutter/material.dart';
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
import 'theme_controller.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<HomePage> with WidgetsBindingObserver {
  bool isManager = false;
  DateTime? selectedDate;
  String? selectedPartner;
  List<String> suggestionsList = []; // Assuming this is populated elsewhere
  TextEditingController _partnerController = TextEditingController();
  List<String> allUsers = []; // Fetched from your backend
  List<String> lastSelectedPartners =
      []; // Fetched from SharedPreferences or similar
  String? myUserName;
  bool _managerResolved = false;

  bool isTodaySelected = true; // Default to "Today" being selected
  bool isTomorrowSelected = false; // Initially, tomorrow is not selected

  // New variable for email notifications preference
  bool _receiveEmails = false;
  bool _darkMode = false; // persisted user pref (default false)
  late final StreamSubscription<User?> _authSub;
  late final StreamSubscription<User?> _idTokSub;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Load the email preference for the user
      _loadEmailPreference();
      _loadDarkPreference();
      _refreshManagerFlag();
      // Also refresh whenever Firebase auth state/token changes
      _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
        _refreshManagerFlag();
      });
      _idTokSub = FirebaseAuth.instance.idTokenChanges().listen((_) {
        _refreshManagerFlag();
      });

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshManagerFlag(); // app back from background
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub.cancel();
    _idTokSub.cancel();
    super.dispose();
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
    } catch (e) {}
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

  Future<void> _refreshManagerFlag() async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      if (userEmail == null) return;

      final name = await UserManager.instance.getUsernameByEmail(userEmail);
      final manager = name == "אודי אש" ||
          name == "רני לפלר" ||
          name == "עפר בן ישי" ||
          name == "מיקי זילברשטיין" ||
          name == "מועדון כרמל";

      if (!mounted) return;
      setState(() {
        myUserName = name;
        isManager = manager;
        _managerResolved = true; // mark as loaded
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _managerResolved = true; // still mark as loaded even if failed
      });
    }
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

    // 1) Not logged in → show login immediately (no need to wait)
    if (!loggedIn) {
      return Scaffold(body: _buildLoginScreen());
    }

    // 2) Logged in but manager flag not resolved yet → small spinner
    if (!_managerResolved) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 3) Logged in and resolved → normal UI
    return Scaffold(
      body: _buildMainContent(),
      drawer: _buildDrawer(),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildMainContent() {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final now = DateTime.now();
        final base = DateTime(now.year, now.month, now.day);
        final after2200 = now.hour >= 22;

        final today = after2200 ? base.add(const Duration(days: 1)) : base;
        final tomorrow = after2200
            ? base.add(const Duration(days: 2))
            : base.add(const Duration(days: 1));
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
                    child: ElevatedButton(
                      onPressed: () {
                        // Compute effective "today/tomorrow" (shift after 22:00)
                        final now = DateTime.now();
                        final base = DateTime(now.year, now.month, now.day);
                        final after2200 = now.hour >= 22;

                        final effectiveToday = after2200
                            ? base.add(const Duration(days: 1))
                            : base;
                        final effectiveTomorrow = after2200
                            ? base.add(const Duration(days: 2))
                            : base.add(const Duration(days: 1));

                        final showing = (selectedDate ?? effectiveToday);
                        final bool isShowingToday =
                            _isSameDay(showing, effectiveToday);

                        final DateTime target =
                            isShowingToday ? effectiveTomorrow : effectiveToday;

                        updateSelectedDate(context, target);
                      },
                      child: Builder(builder: (_) {
                        final now = DateTime.now();
                        final base = DateTime(now.year, now.month, now.day);
                        final after2200 = now.hour >= 22;

                        final effectiveToday = after2200
                            ? base.add(const Duration(days: 1))
                            : base;
                        final effectiveTomorrow = after2200
                            ? base.add(const Duration(days: 2))
                            : base.add(const Duration(days: 1));

                        final showing = (selectedDate ?? effectiveToday);
                        final dayNumber = DateFormat('dd').format(showing);

                        String label;
                        if (_isSameDay(showing, effectiveToday)) {
                          label = "היום - $dayNumber";
                        } else if (_isSameDay(showing, effectiveTomorrow)) {
                          label = "מחר - $dayNumber";
                        } else {
                          label = dayNumber; // fallback
                        }

                        return Text(label);
                      }),
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

  Future<void> _loadDarkPreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email!;
    final q = await FirebaseFirestore.instance
        .collection('users_2024')
        .where('מייל', isEqualTo: email)
        .limit(1)
        .get();

    if (!mounted) return; // guard before setState
    final pref = q.docs.isNotEmpty
        ? (q.docs.first.data() as Map<String, dynamic>)['darkMode'] ?? false
        : false;

    setState(() => _darkMode = pref);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ThemeController.instance.setDark(pref); // no context here
    });
  }

  Future<void> _toggleDarkPreference(bool newValue) async {
    // 1) Capture navigator now (no context later)
    final navigator = Navigator.of(context);

    // 2) Close the drawer immediately (prevents rebuild while open)
    if (navigator.canPop()) navigator.pop();

    // 3) Persist to Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email!;
    final users = FirebaseFirestore.instance.collection('users_2024');
    final q = await users.where('מייל', isEqualTo: email).limit(1).get();

    if (q.docs.isNotEmpty) {
      await users.doc(q.docs.first.id).update({'darkMode': newValue});
    }

    // 4) Widget may have been disposed while awaiting
    if (!mounted) return;

    setState(() => _darkMode = newValue);

    // 5) Flip theme on next frame (no context used)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ThemeController.instance.setDark(newValue);
    });
  }

  Widget _themedTile(BuildContext context, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: child,
    );
  }

  Widget _buildDrawer() {
    final scheme = Theme.of(context).colorScheme;

    TextStyle titleStyle = TextStyle(color: scheme.onSurface);
    IconThemeData iconTheme = IconThemeData(color: scheme.primary);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Dark Mode switch
          _themedTile(
            context,
            SwitchListTile(
              title: Text('מצב כהה', style: titleStyle),
              value: _darkMode,
              activeColor: scheme.primary,
              trackColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? scheme.primary.withOpacity(0.45)
                    : scheme.outlineVariant;
              }),
              onChanged: _toggleDarkPreference,
            ),
          ),

          // Email preference
          _themedTile(
            context,
            CheckboxListTile(
              value: _receiveEmails,
              title: Text('אפשר קבלת מייל', style: titleStyle),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: scheme.primary,
              checkColor: scheme.onPrimary,
              onChanged: (bool? v) {
                if (v != null) _toggleEmailPreference(v);
              },
            ),
          ),
// Sign out
          _themedTile(
            context,
            ListTile(
              leading: Icon(Icons.exit_to_app, color: iconTheme.color),
              title: Text('התנתק', style: titleStyle),
              onTap: () async {
                final navigator = Navigator.of(context);
                final router = GoRouter.of(context);

                // Close drawer first (no context after awaits)
                if (navigator.canPop()) navigator.pop();

                // Navigate to a screen that does NOT touch Firestore
                // (your root shows login when loggedOut, that’s fine)
                router.go('/');
                // Sign out on the next frame (after navigation)
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  try {
                    await FirebaseAuth.instance.signOut();
                  } catch (_) {}
                });
              },
            ),
          ),

          // Change password
          _themedTile(
            context,
            ListTile(
              leading: Icon(Icons.lock, color: iconTheme.color),
              title: Text('שנה סיסמא', style: titleStyle),
              onTap: () => GoRouter.of(context).push('/change-password'),
            ),
          ),

          // Manager-only: Holidays
          if (isManager)
            _themedTile(
              context,
              ListTile(
                leading: Icon(Icons.event_available, color: iconTheme.color),
                title: Text('ניהול חגים', style: titleStyle),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AddHolidayScreen()),
                  );
                },
              ),
            ),

          // Manager-only: Users
          if (isManager)
            _themedTile(
              context,
              ListTile(
                leading: Icon(Icons.group, color: iconTheme.color),
                title: Text('ניהול משתמשים', style: titleStyle),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ManageUsersScreen()),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
