import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_manager.dart'; // Import the UserManager class

class ManageUsersScreen extends StatefulWidget {
  @override
  _ManageUsersScreenState createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User added successfully')),
      );
      _clearFields();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add user: $e')),
      );
    }
  }

  Future<void> _removeUser() async {
    try {
      String email = _emailController.text;

      // Use getUsernameByEmail to check if the user exists
      String? username = await UserManager.instance.getUsernameByEmail(email);

      if (username != null) {
        // Fetch the user UID from Firestore based on email
        QuerySnapshot userSnapshot = await FirebaseFirestore.instance
            .collection('users_2024')
            .where('מייל', isEqualTo: email)
            .get();

        if (userSnapshot.docs.isNotEmpty) {
          String uid = userSnapshot.docs.first.id;

          // Delete user from Firebase Authentication
          User? user = await FirebaseAuth.instance.currentUser;
          if (user != null && user.email == email) {
            await user.delete();
          }

          // Remove user from Firestore
          await FirebaseFirestore.instance
              .collection('users_2024')
              .doc(uid)
              .delete();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User removed successfully')),
          );
          _clearFields();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found in database')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove user: $e')),
      );
    }
  }

  void _clearFields() {
    _emailController.clear();
    _firstNameController.clear();
    _lastNameController.clear();
    _phoneNumberController.clear();
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
                  onPressed: _removeUser,
                  child: const Text('Remove User'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
