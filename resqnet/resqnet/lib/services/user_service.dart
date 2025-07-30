import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      // First, try to fetch the document directly using the UID as the document ID
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      
      // If no document found with UID as document ID, try to find by email
      // This is a fallback for users created before the UID-based system
      try {
        // Get the current user's email from Firebase Auth
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.email != null) {
          QuerySnapshot emailQuery = await _db
              .collection('users')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();
          
          if (emailQuery.docs.isNotEmpty) {
            return emailQuery.docs.first.data() as Map<String, dynamic>?;
          }
        }
      } catch (emailError) {
        print('Error searching by email: $emailError');
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
    String? uid, // Optional UID parameter
    double? latitude, // Optional latitude
    double? longitude, // Optional longitude
  }) async {
    // If UID is provided, use it as document ID, otherwise use add() for auto-generated ID
    Map<String, dynamic> userData = {
      'fullName': fullName,
      'username': username,
      'email': email,
      'phone': phone,
      'hardwareContact': hardwareContact,
      'password': password, // Remember: Store hashed passwords in production!
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
      'isOnline': true,
      'currentLocation': {
        'latitude': latitude ?? 0.0,
        'longitude': longitude ?? 0.0,
        'timestamp': FieldValue.serverTimestamp(),
      },
    };

    if (uid != null) {
      // Use the provided UID as the document ID
      await _db.collection('users').doc(uid).set(userData);
      print('User data saved with UID: $uid');
    } else {
      // Use auto-generated document ID (original behavior)
      await _db.collection('users').add(userData);
      print('User data saved with auto-generated ID');
    }
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
