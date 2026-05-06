import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, PhoneAuthProvider;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'booking_screen_v31.dart';
import 'booking_tokens.dart';
import 'src/authentication.dart';
import 'user_manager.dart';
import 'hoilday.dart';
import 'users_management.dart';
import 'theme_controller.dart';
import 'dart:async';
import 'tv_screen.dart';
import 'tv_message_editor.dart';
import 'widgets/bouncing_ball_loader.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<HomePage> with WidgetsBindingObserver {
  bool isManager = false;
  List<String> suggestionsList = [];
  List<String> lastSelectedPartners = [];
  String? myUserName;
  bool _managerResolved = false;

  // New variable for email notifications preference
  bool _receiveEmails = false;
  bool _darkMode = false; // persisted user pref (default false)
  late final StreamSubscription<User?> _authSub;
  late final StreamSubscription<User?> _idTokSub;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Always subscribe to auth changes
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) async {
      if (u == null) {
        if (!mounted) return;
        setState(() {
          _managerResolved = true;
          isManager = false;
          myUserName = null;
          lastSelectedPartners = [];
          _receiveEmails = false; // local state cleared
          _darkMode = false;
        });
        return;
      }
      // Logged in:
      if (mounted) setState(() => _managerResolved = false);
      // 1) Load user prefs (dark + emails)
      await _loadUserPrefs();
      // 2) Resolve manager status
      await _refreshManagerFlag(); // sets isManager + _managerResolved=true inside
      if (!mounted) return;
      // 3) Now load username/partners/users
      await fetchMyUserName(); // name only; DO NOT set isManager here
      final partners = await fetchLastFivePartners(u.email!);
      if (!mounted) return;
      setState(() => lastSelectedPartners = partners);
      fetchAllUsers();
    });
    // Token refresh → keep manager fresh
    _idTokSub = FirebaseAuth.instance.idTokenChanges().listen((u) {
      if (u != null) {
        if (mounted) setState(() => _managerResolved = false);
        _refreshManagerFlag();
      }
    });

    // ✅ Cold start: if already logged in, resolve immediately
    if (FirebaseAuth.instance.currentUser != null) {
      _loadUserPrefs();
      setState(() => _managerResolved = false);
      _refreshManagerFlag();
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

  Future<void> _loadUserPrefs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final q = await FirebaseFirestore.instance
        .collection('users_2024')
        .where('מייל', isEqualTo: user.email!)
        .limit(1)
        .get();

    if (!mounted) return;

    bool receive = false;
    bool dark = false;

    if (q.docs.isNotEmpty) {
      final data = q.docs.first.data() as Map<String, dynamic>;
      receive = (data['receiveReservationEmails'] ?? false) as bool;
      dark = (data['darkMode'] ?? false) as bool;
    }

    setState(() {
      _receiveEmails = receive;
      _darkMode = dark;
    });

    // Apply the theme AFTER this frame to avoid rebuild assertions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ThemeController.instance.setDark(dark);
    });
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
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email == null) return;

      String? name = await UserManager.instance.getUsernameByEmail(email);

      // Retry once if mapping wasn’t ready yet
      if (name == null || name.trim().isEmpty) {
        await UserManager.instance.fetchAndStoreUserMappings();
        name = await UserManager.instance.getUsernameByEmail(email);
      }

      final n = (name ?? '').trim();
      final manager = n == "אודי אש" ||
          n == "רני לפלר" ||
          n == "עפר בן ישי" ||
          n == "מיקי זילברשטיין" ||
          n == "מועדון כרמל";

      if (!mounted) return;
      setState(() {
        myUserName = n.isEmpty ? null : n;
        isManager = manager;
        _managerResolved = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _managerResolved = true);
    }
  }

  Future<void> fetchMyUserName() async {
    try {
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email == null) return;
      final name = await UserManager.instance.getUsernameByEmail(email);
      if (!mounted) return;
      setState(() {
        myUserName = name;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final bool loggedIn = user != null;

    // 1) Not logged in → show login immediately (no need to wait)
    if (!loggedIn) {
      return Scaffold(body: _buildLoginScreen());
    }

    // 2) Logged in but manager flag not resolved yet → branded loading
    if (!_managerResolved) {
      return Scaffold(body: _buildAuthLoadingScreen());
    }

    // 3) Logged in and resolved → normal UI
    return Scaffold(
      drawer: _buildDrawer(),
      body: Builder(
        builder: (scaffoldCtx) => BookingScreenV31(
          isManager: isManager,
          myUserName: myUserName,
          lastFivePartners: lastSelectedPartners,
          allUsers: suggestionsList,
          darkMode: _darkMode,
          onDarkModeToggle: _setDarkPreference,
          onMenuTap: () => Scaffold.of(scaffoldCtx).openDrawer(),
        ),
      ),
    );
  }

  Widget _buildAuthLoadingScreen() {
    final tokens = BookingTokens.of(context);
    return Container(
      color: tokens.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'מועדון הכרמל',
              style: TextStyle(
                color: tokens.clay,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 18),
            const BouncingBallLoader(size: 36, showBaseline: true),
            const SizedBox(height: 8),
            Text(
              'טוען…',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: tokens.ink2,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'התחבר.י כדי להמשיך',
            style: TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 20),
          Center(
            child: AuthFunc(
              loggedIn: false,
              signOut: () async {
                await FirebaseAuth.instance.signOut();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDarkPreference(bool newValue) async {
    // Drawer entry point: close drawer first, then persist.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    await _setDarkPreference(newValue);
  }

  Future<void> _setDarkPreference(bool newValue) async {
    // Persist to Firestore + flip theme. Safe to call from anywhere.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email!;
    final users = FirebaseFirestore.instance.collection('users_2024');
    final q = await users.where('מייל', isEqualTo: email).limit(1).get();

    if (q.docs.isNotEmpty) {
      await users.doc(q.docs.first.id).update({'darkMode': newValue});
    }

    if (!mounted) return;
    setState(() => _darkMode = newValue);

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
          // Manager-only: TV display
          if (isManager)
            _themedTile(
              context,
              ListTile(
                leading: Icon(Icons.tv, color: iconTheme.color),
                title: Text('מסך טלוויזיה', style: titleStyle),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TvScreen()),
                  );
                },
              ),
            ),
          // Manager-only: TV marquee editor
          if (isManager)
            _themedTile(
              context,
              ListTile(
                leading: Icon(Icons.message, color: iconTheme.color),
                title: Text('עריכת הודעת טלוויזיה', style: titleStyle),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TvMessageEditor()),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
