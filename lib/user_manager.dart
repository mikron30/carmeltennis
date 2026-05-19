import 'package:cloud_firestore/cloud_firestore.dart';

class UserManager {
  static final UserManager _instance = UserManager._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Two maps for bidirectional lookup
  Map<String, String>? _emailToUsernameMap;
  Map<String, String>? _usernameToEmailMap;

  // Single shared Future so concurrent callers (e.g. cold-start unawaited
  // prefetch + first booking attempt) await the same fetch instead of either
  // racing to refetch or silently reading half-populated maps.
  Future<void>? _inFlight;

  UserManager._internal();

  static UserManager get instance => _instance;

  Future<void> fetchAndStoreUserMappings() {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _fetch();
    _inFlight = future;
    return future;
  }

  Future<void> _fetch() async {
    try {
      final querySnapshot = await _firestore.collection('users_2024').get();
      final tempEmailToName = <String, String>{};
      final tempNameToEmail = <String, String>{};

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

      _emailToUsernameMap = tempEmailToName;
      _usernameToEmailMap = tempNameToEmail;
    } catch (e) {
      print("Error fetching user mappings: $e");
    } finally {
      _inFlight = null;
    }
  }

  Future<String?> getUsernameByEmail(String email) async {
    if (_emailToUsernameMap == null || _inFlight != null) {
      await fetchAndStoreUserMappings();
    }
    return _emailToUsernameMap?[email];
  }

  /// NEW: Get the email by a user's full name (assuming 'שם פרטי שם משפחה').
  Future<String?> getEmailByUsername(String username) async {
    if (_usernameToEmailMap == null || _inFlight != null) {
      await fetchAndStoreUserMappings();
    }
    return _usernameToEmailMap?[username];
  }
}
