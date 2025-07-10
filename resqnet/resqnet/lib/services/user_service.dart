import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get user by phone number
  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    final query = await _db
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return query.docs.first.data();
    }
    return null;
  }

  // Save new user data
  Future<void> saveUserDataCustom({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required String password,
  }) async {
    await _db.collection('users').add({
      'fullName': fullName,
      'username': username,
      'email': email,
      'phone': phone,
      'password': password,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
