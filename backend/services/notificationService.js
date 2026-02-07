const admin = require('firebase-admin');

// Initialize Firebase Admin (will be initialized in server.js)
let firebaseAdmin = null;

const initializeFirebase = () => {
  if (firebaseAdmin) {
    return; // Already initialized
  }

  try {
    // Get Firebase credentials from environment variables
    // Using the variable names from .env file
    const serviceAccount = {
      type: process.env.TYPE || "service_account",
      project_id: process.env.PROJECT_ID,
      private_key_id: process.env.PRIVATE_KEY_ID,
      private_key: process.env.PRIVATE_KEY?.replace(/\\n/g, '\n'),
      client_email: process.env.CLIENT_EMAIL,
      client_id: process.env.CLIENT_ID,
      auth_uri: process.env.AUTH_URI || "https://accounts.google.com/o/oauth2/auth",
      token_uri: process.env.TOKEN_URI || "https://oauth2.googleapis.com/token",
      auth_provider_x509_cert_url: process.env.AUTH_PROVIDER_X509_CERT_URL || "https://www.googleapis.com/oauth2/v1/certs",
      client_x509_cert_url: process.env.CLIENT_X509_CERT_URL,
      universe_domain: process.env.UNIVERSE_DOMAIN || "googleapis.com"
    };

    if (!serviceAccount.project_id || !serviceAccount.private_key) {
      console.error('❌ Firebase credentials not found in environment variables');
      console.error('Required: PROJECT_ID, PRIVATE_KEY, CLIENT_EMAIL');
      return;
    }

    firebaseAdmin = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });

    console.log('✅ Firebase Admin initialized');
  } catch (error) {
    console.error('❌ Error initializing Firebase Admin:', error);
  }
};

// Send notification to a single user
const sendNotification = async (fcmToken, title, body, data = {}) => {
  if (!firebaseAdmin) {
    initializeFirebase();
  }

  if (!fcmToken) {
    console.log('⚠️ No FCM token provided');
    return false;
  }

  try {
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      token: fcmToken,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log('✅ Notification sent successfully:', response);
    return true;
  } catch (error) {
    console.error('❌ Error sending notification:', error);
    // If token is invalid, return false
    if (error.code === 'messaging/invalid-registration-token' ||
      error.code === 'messaging/registration-token-not-registered') {
      console.log('⚠️ Invalid or unregistered FCM token');
    }
    return false;
  }
};

// Send notification to multiple users
const sendNotificationToMultiple = async (fcmTokens, title, body, data = {}) => {
  if (!firebaseAdmin) {
    initializeFirebase();
  }

  if (!fcmTokens || fcmTokens.length === 0) {
    console.log('⚠️ No FCM tokens provided');
    return { success: 0, failure: 0 };
  }

  // Filter out null/undefined tokens
  const validTokens = fcmTokens.filter(token => token != null && token.trim() !== '');

  if (validTokens.length === 0) {
    console.log('⚠️ No valid FCM tokens');
    return { success: 0, failure: 0 };
  }

  try {
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast({
      tokens: validTokens,
      ...message,
    });

    console.log(`✅ Notifications sent: ${response.successCount} success, ${response.failureCount} failure`);
    return { success: response.successCount, failure: response.failureCount };
  } catch (error) {
    console.error('❌ Error sending notifications:', error);
    return { success: 0, failure: validTokens.length };
  }
};

// Send chat notification
const sendChatNotification = async (recipientToken, senderName, message, chatId, isGroupChat = false) => {
  const title = isGroupChat ? `My Connect Chat` : senderName;
  const body = message.length > 100 ? message.substring(0, 100) + '...' : message;

  return await sendNotification(recipientToken, title, body, {
    type: 'chat',
    chatId: chatId,
    isGroupChat: isGroupChat.toString(),
  });
};

// Send status change notification
const sendStatusNotification = async (userToken, status) => {
  let title = 'Status Update';
  let body = '';

  switch (status) {
    case 'approved':
      title = 'Account Approved';
      body = 'Your account has been approved! You can now access all features.';
      break;
    case 'rejected':
      title = 'Account Rejected';
      body = 'Your account has been rejected. Please contact admin for more information.';
      break;
    case 'pending':
      title = 'Status Changed';
      body = 'Your account status has been changed to pending.';
      break;
    default:
      body = `Your account status has been changed to ${status}.`;
  }

  return await sendNotification(userToken, title, body, {
    type: 'status_change',
    status: status,
  });
};

// Save notification to database
const saveNotificationToDb = async (recipientId, title, body, type, data = {}) => {
  try {
    const Notification = require('../models/Notification');

    // Only save if we have a valid recipient ID (from user object)
    if (!recipientId) return false;

    const notification = new Notification({
      recipient: recipientId,
      title,
      body,
      type: type || 'other',
      data: data,
      isRead: false
    });

    await notification.save();
    console.log('✅ Notification saved to database');
    return true;
  } catch (error) {
    console.error('❌ Error saving notification to database:', error);
    return false;
  }
};

module.exports = {
  initializeFirebase,
  sendNotification,
  sendNotificationToMultiple,
  sendChatNotification,
  sendStatusNotification,
  saveNotificationToDb
};

