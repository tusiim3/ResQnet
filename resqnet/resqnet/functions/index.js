// The Cloud Functions for Firebase SDK to create Cloud Functions and triggers.
const functions = require('firebase-functions');

// The Firebase Admin SDK to interact with Firebase services.
const admin = require('firebase-admin');
admin.initializeApp(); // Initialize the Firebase Admin SDK

// This is your Cloud Function, named 'sendEmergencyNotification'.
// It listens for new documents in the 'emergency_locations' collection.
exports.sendEmergencyNotification = functions.firestore
    .document('emergency_locations/{emergencyId}')
    .onCreate(async (snapshot, context) => {
        // 1. Get the data from the new emergency document
        const emergencyData = snapshot.data();
        const emergencyId = context.params.emergencyId;

        const emergencyLatitude = emergencyData.latitude;
        const emergencyLongitude = emergencyData.longitude;
        const emergencyAdditionalInfo = emergencyData.additionalInfo || 'No additional details provided.';

        if (typeof emergencyLatitude !== 'number' || typeof emergencyLongitude !== 'number') {
            functions.logger.error(`Invalid latitude or longitude for emergency (${emergencyId}). Skipping notification.`);
            return null;
        }

        functions.logger.log(`New emergency (${emergencyId}) detected at Lat: ${emergencyLatitude}, Lng: ${emergencyLongitude}`);

        // 2. Prepare the FCM notification payload
        const payload = {
            notification: {
                title: `Emergency Alert`,
                body: `Coordinates: ${emergencyLatitude}, ${emergencyLongitude}. Info: ${emergencyAdditionalInfo.substring(0, 97)}${emergencyAdditionalInfo.length > 97 ? '...' : ''}`,
                icon: '/images/emergency_icon.png',
                click_action: `https://${process.env.GCLOUD_PROJECT}.firebaseapp.com/emergencies/${emergencyId}`,
            },
            data: {
                emergencyId: emergencyId,
                latitude: String(emergencyLatitude),
                longitude: String(emergencyLongitude),
                additionalInfo: emergencyAdditionalInfo,
            }
        };

        // 3. Gather device tokens to send notifications to
        // UPDATED: Now assumes FCM token is stored as a single 'fcmToken' field
        // directly in each user document.
        const allUsersSnapshot = await admin.firestore().collection('users').get();
        const tokensToSend = [];

        allUsersSnapshot.forEach((userDoc) => {
            const userData = userDoc.data();
            const fcmToken = userData.fcmToken; // Get the single fcmToken string

            // Check if the fcmToken exists and is a valid string
            if (fcmToken && typeof fcmToken === 'string') {
                tokensToSend.push(fcmToken);
            }
        });

        if (tokensToSend.length === 0) {
            functions.logger.log('No FCM tokens found in user profiles to send notifications to.');
            return null; // Exit if no tokens
        }

        // 4. Send the FCM notifications
        try {
            const response = await admin.messaging().sendToDevice(tokensToSend, payload);

            functions.logger.log('Notifications sent:', response);

            // 5. Clean up invalid tokens
            // IMPORTANT: The cleanupTokens helper function (below) is a placeholder.
            // For tokens stored as a single field in user documents, cleanup would involve
            // finding the specific user document whose token is invalid and removing/nulling
            // out that `fcmToken` field. This typically requires more complex logic.
            functions.logger.warn('Token cleanup for single-field user-based storage is more complex and not fully implemented in this example.');

            functions.logger.log('Notifications have been sent.');
            return null; // Indicate success
        } catch (error) {
            functions.logger.error('Error sending notifications:', error);
            return null; // Indicate error
        }
    });

// IMPORTANT: This cleanupTokens helper function (copied from previous response)
// is a placeholder. For tokens stored as a single field within user documents,
// the cleanup logic needs to be significantly re-written to target the specific
// user document and update its 'fcmToken' field (e.g., set to null or delete).
// It's often handled client-side on new token events (where the old token is
// automatically overwritten) or by a separate, periodic Cloud Function.
async function cleanupTokens(response, tokens) {
    functions.logger.warn("Placeholder cleanupTokens: This function needs to be re-written for your single-field user-based token storage strategy.");
    return Promise.resolve();
}
