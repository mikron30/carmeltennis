import 'package:cloud_firestore/cloud_firestore.dart';

class UserManager {
  static final UserManager _instance = UserManager._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, String>? _emailToUsernameMap;
  bool _isFetching = false;

  UserManager._internal();

  static UserManager get instance => _instance;

  Future<void> fetchAndStoreUserMappings() async {
    if (_isFetching) return; // Prevent multiple simultaneous fetches
    _isFetching = true;
    try {
      final querySnapshot = await _firestore.collection('users_2024').get();
      var tempMap = <String, String>{};
      for (var doc in querySnapshot.docs) {
        String email = doc.data()['מייל'] as String;
        String firstName = doc.data()['שם פרטי'] as String;
        String lastName = doc.data()['שם משפחה'] as String;
        tempMap[email] = '$firstName $lastName'.trim();
      }
      _emailToUsernameMap = tempMap;
    } catch (e) {
      print("Error fetching user mappings: $e");
    } finally {
      _isFetching = false;
    }
  }

  Future<String?> getUsernameByEmail(String email) async {
    if (_emailToUsernameMap == null || _emailToUsernameMap!.isEmpty) {
      await fetchAndStoreUserMappings(); // Fetch if map is null or empty
    }
    return _emailToUsernameMap?[email];
  }
}
