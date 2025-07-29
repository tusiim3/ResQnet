// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class UserService {
//   final FirebaseFirestore _db = FirebaseFirestore.instance;

//   // Get user by phone number
//   Future<DocumentSnapshot?> getUserByPhone(String phone) async {
//     final query = await _db
//         .collection('users')
//         .where('phone', isEqualTo: phone)
//         .limit(1)
//         .get();
//     if (query.docs.isNotEmpty) {
//       // Return the first document snapshot found
//       return query.docs.first;
//     }
//     return null;
// }

//   // Get user data by User ID (UID)
//   // This is crucial for fetching the currently logged-in user's profile information.
//   Future<Map<String, dynamic>?> getUserData(String uid) async {
//     try {
//       // Fetch the document directly using the UID as the document ID
//       DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
//       if (doc.exists) {
//         return doc.data() as Map<String, dynamic>?;
//       }
//       return null;
//     } catch (e) {
//       print('Error getting user data: $e');
//       return null;
//     }
//   }

//   // Save new user data when a user registers
//   Future<void> saveUserDataCustom({
//     required String fullName,
//     required String username,
//     required String email,
//     required String phone,
//     required String hardwareContact,
//     required String password,
//   }) async {
//     // When saving new user data, it's often good practice to use the
//     // Firebase Auth UID as the document ID in Firestore for easier retrieval.
//     // However, based on your `getUserByPhone` and current `saveUserDataCustom`,
//     // it seems you're using `add` which creates an auto-generated ID.
//     // If you intend to fetch by UID, you should store the UID as the document ID
//     // during registration or link the user's phone to a Firebase Auth user.
//     // For now, I'll keep the `add` method as it was, but be aware of this.
//     await _db.collection('users').add({
//       'fullName': fullName,
//       'username': username,
//       'email': email,
//       'phone': phone,
//       'hardwareContact': hardwareContact,
//       'password': password, // Remember: Store hashed passwords in production!
//       'createdAt': FieldValue.serverTimestamp(),
//     });
//   }

//   // Update existing user data by User ID (UID)
//   // This method will be used by the ProfileScreen to save edited information.
//   Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
//     try {
//       // Update the document corresponding to the user's UID
//       await _db.collection('users').doc(uid).update(data);
//       print('User data updated successfully for UID: $uid');
//     } catch (e) {
//       print('Error updating user data for UID $uid: $e');
//       // You might want to throw an exception or return a boolean to indicate success/failure
//       rethrow; // Re-throw the error so the calling widget can handle it
//     }
//   }
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      return query.docs.first;
    }
    return null;
  }

  // Get user data by User ID (UID) 
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
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

  // Get current logged-in user data from local storage
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('logged_in_user_id');
      
      if (userId != null) {
        // Fetch fresh data from Firebase
        final userData = await getUserData(userId);
        
        if (userData != null) {
          // Update local storage with fresh data
          await _updateLocalUserData(userData);
          return userData;
        }
      }
      
      // Fallback to local data if Firebase fails
      return _getLocalUserData();
    } catch (e) {
      print('Error getting current user data: $e');
      return _getLocalUserData();
    }
  }

  // Get user data from local storage only
  Map<String, dynamic>? _getLocalUserData() {
    try {
      // This would need to be async, but for fallback we'll return null
      return null;
    } catch (e) {
      print('Error getting local user data: $e');
      return null;
    }
  }

  // Update local storage with user data
  Future<void> _updateLocalUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', userData['fullName'] ?? userData['username'] ?? 'User');
      await prefs.setString('user_email', userData['email'] ?? '');
      await prefs.setString('user_phone', userData['phone'] ?? '');
      await prefs.setString('user_hardware_contact', userData['hardwareContact'] ?? '');
    } catch (e) {
      print('Error updating local user data: $e');
    }
  }

  // Save new user data when a user registers - enhanced version
  Future<String> saveUserDataCustom({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required String hardwareContact,
    required String password,
  }) async {
    try {
      // Create user document
      DocumentReference docRef = await _db.collection('users').add({
        'fullName': fullName,
        'username': username,
        'email': email,
        'phone': phone,
        'hardwareContact': hardwareContact,
        'password': password, // Remember: Hash passwords in production!
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isActive': true,
        'profileCompletionStatus': 'complete',
        // Additional fields for trip tracking
        'totalTrips': 0,
        'tripsToday': 0,
        'lastTripDate': null,
        'emergencyContactsCount': 0,
        'notificationPreferences': {
          'emergencyAlerts': true,
          'tripReminders': true,
          'safetyUpdates': true,
        },
      });

      // Return the document ID for future reference
      return docRef.id;
    } catch (e) {
      print('Error saving user data: $e');
      throw Exception('Failed to save user data: $e');
    }
  }

  // Update existing user data by User ID (UID) - enhanced version
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      // Add lastUpdated timestamp
      data['lastUpdated'] = FieldValue.serverTimestamp();
      
      // Update the document
      await _db.collection('users').doc(uid).update(data);
      
      // Update local storage if this is the current user
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('logged_in_user_id');
      
      if (currentUserId == uid) {
        await _updateLocalUserData(data);
      }
      
      print('User data updated successfully for UID: $uid');
    } catch (e) {
      print('Error updating user data for UID $uid: $e');
      rethrow;
    }
  }

  // Update user's last login time
  Future<void> updateLastLogin(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last login: $e');
    }
  }

  // Update trip statistics
  Future<void> updateTripStats(String uid, {
    bool incrementTotalTrips = false,
    bool incrementTodayTrips = false,
    bool resetTodayTrips = false,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      
      if (incrementTotalTrips) {
        updates['totalTrips'] = FieldValue.increment(1);
      }
      
      if (incrementTodayTrips) {
        updates['tripsToday'] = FieldValue.increment(1);
        updates['lastTripDate'] = FieldValue.serverTimestamp();
      }
      
      if (resetTodayTrips) {
        updates['tripsToday'] = 0;
      }
      
      if (updates.isNotEmpty) {
        await _db.collection('users').doc(uid).update(updates);
      }
    } catch (e) {
      print('Error updating trip stats: $e');
    }
  }

  // Get user's trip statistics
  Future<Map<String, int>> getTripStats(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'totalTrips': data['totalTrips'] ?? 0,
          'tripsToday': data['tripsToday'] ?? 0,
        };
      }
      return {'totalTrips': 0, 'tripsToday': 0};
    } catch (e) {
      print('Error getting trip stats: $e');
      return {'totalTrips': 0, 'tripsToday': 0};
    }
  }

  // Check if user session is valid
  Future<bool> isValidSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('logged_in_user_id');
      final rememberMe = prefs.getBool('remember_me') ?? false;
      
      if (userId == null || !rememberMe) {
        return false;
      }
      
      // Verify user still exists in Firebase
      final userData = await getUserData(userId);
      return userData != null && (userData['isActive'] ?? false);
    } catch (e) {
      print('Error checking session validity: $e');
      return false;
    }
  }

  // Clear user session
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('logged_in_user_id');
      await prefs.remove('remember_me');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await prefs.remove('user_phone');
      await prefs.remove('user_hardware_contact');
      print('User session cleared');
    } catch (e) {
      print('Error clearing session: $e');
    }
  }

  // Save user session data
  Future<void> saveSession({
    required String uid,
    required Map<String, dynamic> userData,
    required bool rememberMe,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_in_user_id', uid);
      await prefs.setBool('remember_me', rememberMe);
      await _updateLocalUserData(userData);
      
      // Update last login in Firebase
      await updateLastLogin(uid);
    } catch (e) {
      print('Error saving session: $e');
    }
  }

  // Search users by username or full name (for admin features)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      // Search by username
      QuerySnapshot usernameQuery = await _db
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(10)
          .get();

      // Search by full name
      QuerySnapshot nameQuery = await _db
          .collection('users')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(10)
          .get();

      Set<String> seenIds = {};
      List<Map<String, dynamic>> results = [];

      // Combine results and remove duplicates
      for (var doc in [...usernameQuery.docs, ...nameQuery.docs]) {
        if (!seenIds.contains(doc.id)) {
          seenIds.add(doc.id);
          Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
          userData['uid'] = doc.id;
          results.add(userData);
        }
      }

      return results;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Get user statistics for admin dashboard
  Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      QuerySnapshot snapshot = await _db.collection('users').get();
      
      int totalUsers = snapshot.docs.length;
      int activeUsers = 0;
      int totalTrips = 0;
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['isActive'] == true) activeUsers++;
        totalTrips += (data['totalTrips'] as int?) ?? 0;
      }
      
      return {
        'totalUsers': totalUsers,
        'activeUsers': activeUsers,
        'totalTrips': totalTrips,
        'averageTripsPerUser': totalUsers > 0 ? (totalTrips / totalUsers).round() : 0,
      };
    } catch (e) {
      print('Error getting user statistics: $e');
      return {
        'totalUsers': 0,
        'activeUsers': 0,
        'totalTrips': 0,
        'averageTripsPerUser': 0,
      };
    }
  }
}