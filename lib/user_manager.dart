import 'package:cloud_firestore/cloud_firestore.dart';

class UserManager {
  static final UserManager _instance = UserManager._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Two maps for bidirectional lookup
  Map<String, String>? _emailToUsernameMap;
  Map<String, String>? _usernameToEmailMap;

  bool _isFetching = false;

  UserManager._internal();

  static UserManager get instance => _instance;

  Future<void> fetchAndStoreUserMappings() async {
    if (_isFetching) return; // Prevent multiple simultaneous fetches
    _isFetching = true;
    try {
      final querySnapshot = await _firestore.collection('users_2024').get();
      var tempEmailToName = <String, String>{};
      var tempNameToEmail = <String, String>{};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        // Make sure the fields exist in your Firestore document
        String email = data['מייל'] as String;
        String firstName = data['שם פרטי'] as String;
        String lastName = data['שם משפחה'] as String;

        String fullName = '$firstName $lastName'.trim();

        // email -> username
        tempEmailToName[email] = fullName;
        // username -> email
        tempNameToEmail[fullName] = email;
      }

      // Assign to the class fields once done
      _emailToUsernameMap = tempEmailToName;
      _usernameToEmailMap = tempNameToEmail;
    } catch (e) {
      print("Error fetching user mappings: $e");
    } finally {
      _isFetching = false;
    }
  }

  Future<String?> getUsernameByEmail(String email) async {
    // If map is null or empty, fetch from Firestore
    if (_emailToUsernameMap == null || _emailToUsernameMap!.isEmpty) {
      await fetchAndStoreUserMappings();
    }
    return _emailToUsernameMap?[email];
  }

  /// NEW: Get the email by a user's full name (assuming 'שם פרטי שם משפחה').
  Future<String?> getEmailByUsername(String username) async {
    if (_usernameToEmailMap == null || _usernameToEmailMap!.isEmpty) {
      await fetchAndStoreUserMappings();
    }
    return _usernameToEmailMap?[username];
  }
}
