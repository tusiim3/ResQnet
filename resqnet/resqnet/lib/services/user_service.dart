import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get user by phone number
  Future<DocumentSnapshot?> getUserByPhone(String phone) async {
    final query = await _db
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      // Return the first document snapshot found
      return query.docs.first;
    }
    return null;
}

  // Get user data by User ID (UID)
  // This is crucial for fetching the currently logged-in user's profile information.
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      // Fetch the document directly using the UID as the document ID
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Save new user data when a user registers
  Future<void> saveUserDataCustom({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required String hardwareContact,
    required String password,
  }) async {
    // When saving new user data, it's often good practice to use the
    // Firebase Auth UID as the document ID in Firestore for easier retrieval.
    // However, based on your `getUserByPhone` and current `saveUserDataCustom`,
    // it seems you're using `add` which creates an auto-generated ID.
    // If you intend to fetch by UID, you should store the UID as the document ID
    // during registration or link the user's phone to a Firebase Auth user.
    // For now, I'll keep the `add` method as it was, but be aware of this.
    await _db.collection('users').add({
      'fullName': fullName,
      'username': username,
      'email': email,
      'phone': phone,
      'hardwareContact': hardwareContact,
      'password': password, // Remember: Store hashed passwords in production!
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Update existing user data by User ID (UID)
  // This method will be used by the ProfileScreen to save edited information.
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      // Update the document corresponding to the user's UID
      await _db.collection('users').doc(uid).update(data);
      print('User data updated successfully for UID: $uid');
    } catch (e) {
      print('Error updating user data for UID $uid: $e');
      // You might want to throw an exception or return a boolean to indicate success/failure
      rethrow; // Re-throw the error so the calling widget can handle it
    }
  }
}
