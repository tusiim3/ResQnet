// The Cloud Functions for Firebase SDK to create Cloud Functions and triggers.
const functions = require("firebase-functions");

// The Firebase Admin SDK to interact with Firebase services.
const admin = require("firebase-admin");
admin.initializeApp(); // Initialize the Firebase Admin SDK

/**
 * Function to handle new user registration and initialize user fields
 */
exports.onUserCreated = functions.firestore
    .document("users/{userId}")
    .onCreate(async (snapshot, context) => {
      const userId = context.params.userId;

      functions.logger.log(`New user created: ${userId}`);

      try {
        // Initialize user notification settings
        // (NOT FCM token - device-specific)
        await snapshot.ref.update({
          notificationEnabled: true,
          unreadAlerts: 0,
          lastLoginTime: admin.firestore.FieldValue.serverTimestamp(),
        });
        const message =
          `Initialized notification settings for user: ${userId}`;
        functions.logger.log(message);
      } catch (error) {
        const errorMessage =
          `Error initializing user fields for user ${userId}:`;
        functions.logger.error(errorMessage, error);
      }

      return null;
    });

/**
 * Cloud Function 'sendEmergencyNotification'.
 * Listens for new documents in the 'emergency_locations' collection.
 */
exports.sendEmergencyNotification = functions.firestore
    .document("emergency_locations/{emergencyId}")
    .onCreate(async (snapshot, context) => {
      // 1. Get the data from the new emergency document
      const emergencyData = snapshot.data();
      const emergencyId = context.params.emergencyId;

      const emergencyLatitude = emergencyData.latitude;
      const emergencyLongitude = emergencyData.longitude;
      const additionalInfo = emergencyData.additionalInfo ||
                           "No additional details provided.";

      const latIsNumber = typeof emergencyLatitude === "number";
      const lngIsNumber = typeof emergencyLongitude === "number";
      if (!latIsNumber || !lngIsNumber) {
        const errorMessage = `Invalid latitude or longitude for emergency ` +
                           `(${emergencyId}). Skipping notification.`;
        functions.logger.error(errorMessage);
        return null;
      }

      const logMessage = `New emergency (${emergencyId}) detected at ` +
                        `Lat: ${emergencyLatitude}, Lng: ${emergencyLongitude}`;
      functions.logger.log(logMessage);

      // 2. Prepare the FCM notification payload
      const bodyText = `Coordinates: ${emergencyLatitude}, ` +
                      `${emergencyLongitude}. Info: ` +
                      `${additionalInfo.substring(0, 97)}` +
                      `${additionalInfo.length > 97 ? "..." : ""}`;

      const clickAction = `https://${process.env.GCLOUD_PROJECT}` +
                         `.firebaseapp.com/emergencies/${emergencyId}`;

      const payload = {
        notification: {
          title: "Emergency Alert",
          body: bodyText,
          icon: "/images/emergency_icon.png",
          click_action: clickAction,
        },
        data: {
          emergencyId: emergencyId,
          latitude: String(emergencyLatitude),
          longitude: String(emergencyLongitude),
          additionalInfo: additionalInfo,
        },
      };

      // 3. Gather device tokens to send notifications to
      const allUsersSnapshot = await admin.firestore()
          .collection("users").get();
      const tokensToSend = [];

      allUsersSnapshot.forEach((userDoc) => {
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        // Check if the fcmToken exists and is a valid string
        if (fcmToken && typeof fcmToken === "string") {
          tokensToSend.push(fcmToken);
        }
      });

      if (tokensToSend.length === 0) {
        const noTokensMessage = "No FCM tokens found in user profiles to " +
                               "send notifications to.";
        functions.logger.log(noTokensMessage);
        return null; // Exit if no tokens
      }

      // 4. Send the FCM notifications
      try {
        const response = await admin.messaging()
            .sendToDevice(tokensToSend, payload);

        functions.logger.log("Notifications sent:", response);

        // 5. Clean up invalid tokens
        const cleanupWarning = "Token cleanup for single-field user-based " +
                              "storage is more complex and not fully " +
                              "implemented in this example.";
        functions.logger.warn(cleanupWarning);

        functions.logger.log("Notifications have been sent.");
        return null; // Indicate success
      } catch (error) {
        functions.logger.error("Error sending notifications:", error);
        return null; // Indicate error
      }
    });
