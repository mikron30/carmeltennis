import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'user_manager.dart'; // Import the UserManager class

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  bool _isRemoving = false;

  // Default password for new users
  final String _defaultPassword = 'carmeltennis';

  Future<void> _addUser() async {
    try {
      // Create user in Firebase Authentication with default password
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _defaultPassword,
      );

      // Add user to Firestore
      await FirebaseFirestore.instance
          .collection('users_2024')
          .doc(userCredential.user?.uid)
          .set({
        'מייל': _emailController.text,
        'שם פרטי': _firstNameController.text,
        'שם משפחה': _lastNameController.text,
        'טלפון': _phoneNumberController.text,
        'isFirstLogin': true,
      });

      if (!mounted) return;
      _showMessage('User added successfully');
      _clearFields();
    } catch (e) {
      if (mounted) _showMessage('Failed to add user: $e');
    }
  }

  Future<void> _removeUser() async {
    final email = _emailController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phoneNumber = _phoneNumberController.text.trim();

    if ([email, firstName, lastName, phoneNumber]
        .every((value) => value.isEmpty)) {
      _showMessage('יש להזין לפחות פרט אחד לחיפוש');
      return;
    }

    setState(() => _isRemoving = true);

    try {
      // Read once and filter locally so combining optional fields does not
      // require a separate Firestore composite index for every combination.
      final snapshot =
          await FirebaseFirestore.instance.collection('users_2024').get();
      final matches = snapshot.docs.where((document) {
        final data = document.data();
        return _matchesText(data['מייל'], email, ignoreCase: true) &&
            _matchesText(data['שם פרטי'], firstName, ignoreCase: true) &&
            _matchesText(data['שם משפחה'], lastName, ignoreCase: true) &&
            _matchesPhone(data['טלפון'], phoneNumber);
      }).toList();

      String matchedEmail;
      if (matches.isEmpty) {
        final searchingOnlyByEmail = email.isNotEmpty &&
            firstName.isEmpty &&
            lastName.isEmpty &&
            phoneNumber.isEmpty;
        if (!searchingOnlyByEmail) {
          _showMessage('לא נמצא משתמש התואם לפרטים שהוזנו');
          return;
        }

        // This also handles an Authentication account whose Firestore record
        // was removed by an older version of the management screen.
        matchedEmail = email;
      } else if (matches.length > 1) {
        _showMessage(
          'נמצאו ${matches.length} משתמשים. יש להזין פרט נוסף כדי לזהות משתמש יחיד',
        );
        return;
      } else {
        matchedEmail = (matches.single.data()['מייל'] ?? '').toString().trim();
        if (matchedEmail.isEmpty) {
          _showMessage('למשתמש שנמצא אין כתובת מייל, ולכן הוא לא נמחק');
          return;
        }
      }

      // Authentication users can only be deleted with the Admin SDK. The
      // callable function verifies the manager and deletes both records.
      final deleteUserAccount = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('deleteUserAccount');
      await deleteUserAccount.call({'email': matchedEmail});
      await UserManager.instance.fetchAndStoreUserMappings();

      if (!mounted) return;
      _showMessage('המשתמש $matchedEmail נמחק בהצלחה');
      _clearFields();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        _showMessage(e.message ?? 'מחיקת המשתמש נכשלה בצד השרת');
      }
    } catch (e) {
      if (mounted) _showMessage('מחיקת המשתמש נכשלה: $e');
    } finally {
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  bool _matchesText(Object? storedValue, String searchValue,
      {required bool ignoreCase}) {
    if (searchValue.isEmpty) return true;

    var stored = _normalizeText(storedValue?.toString() ?? '');
    var searched = _normalizeText(searchValue);
    if (ignoreCase) {
      stored = stored.toLowerCase();
      searched = searched.toLowerCase();
    }
    return stored == searched;
  }

  String _normalizeText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _matchesPhone(Object? storedValue, String searchValue) {
    if (searchValue.isEmpty) return true;

    final storedDigits =
        (storedValue?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
    final searchedDigits = searchValue.replaceAll(RegExp(r'\D'), '');
    return storedDigits == searchedDigits;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _clearFields() {
    _emailController.clear();
    _firstNameController.clear();
    _lastNameController.clear();
    _phoneNumberController.clear();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: 'First Name'),
            ),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: 'Last Name'),
            ),
            TextField(
              controller: _phoneNumberController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _addUser,
                  child: const Text('Add User'),
                ),
                ElevatedButton(
                  onPressed: _isRemoving ? null : _removeUser,
                  child: _isRemoving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Remove User'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
