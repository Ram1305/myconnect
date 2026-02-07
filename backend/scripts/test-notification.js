/**
 * Test Notification Script
 * Sends a test notification to a specific user
 * 
 * Usage:
 *   node scripts/test-notification.js <userId>
 *   node scripts/test-notification.js <userId> --delete
 */

require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');
const Notification = require('../models/Notification');
const { initializeFirebase, sendNotification, saveNotificationToDb } = require('../services/notificationService');

async function testNotification(userId, shouldDelete = false) {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/myconnect', {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('✅ Connected to MongoDB');

    // Initialize Firebase
    initializeFirebase();
    console.log('✅ Firebase initialized');

    // Find user
    const user = await User.findById(userId);
    if (!user) {
      console.error('❌ User not found');
      process.exit(1);
    }

    console.log(`📱 User: ${user.username} (${user.mobileNumber})`);

    if (!user.fcmToken) {
      console.error('❌ User does not have an FCM token');
      console.log('💡 User needs to log in and grant notification permission');
      process.exit(1);
    }

    console.log(`🔑 FCM Token: ${user.fcmToken.substring(0, 30)}...`);

    if (shouldDelete) {
      // Delete all notifications for this user
      const deleted = await Notification.deleteMany({ recipient: userId });
      console.log(`🗑️  Deleted ${deleted.deletedCount} notifications`);
      await mongoose.disconnect();
      process.exit(0);
    }

    // Send test notification
    const testTitle = 'Test Notification (CLI)';
    const testBody = `This is a test notification sent via command line at ${new Date().toLocaleString()}`;

    console.log('\n📤 Sending test notification...');
    const pushResult = await sendNotification(
      user.fcmToken,
      testTitle,
      testBody,
      {
        type: 'test',
        timestamp: new Date().toISOString(),
        source: 'cli',
      }
    );

    if (pushResult) {
      console.log('✅ Push notification sent successfully!');
    } else {
      console.log('⚠️  Push notification failed (check logs above)');
    }

    // Save to database
    console.log('💾 Saving notification to database...');
    const dbResult = await saveNotificationToDb(
      userId,
      testTitle,
      testBody,
      'test',
      {
        timestamp: new Date().toISOString(),
        source: 'cli',
      }
    );

    if (dbResult) {
      console.log('✅ Notification saved to database');
    } else {
      console.log('⚠️  Failed to save notification to database');
    }

    console.log('\n✅ Test notification process completed!');
    console.log('💡 Check the device to see if notification was received');

    await mongoose.disconnect();
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    await mongoose.disconnect();
    process.exit(1);
  }
}

// Get command line arguments
const args = process.argv.slice(2);
if (args.length === 0) {
  console.log('Usage:');
  console.log('  node scripts/test-notification.js <userId>           - Send test notification');
  console.log('  node scripts/test-notification.js <userId> --delete  - Delete all notifications');
  console.log('\nExample:');
  console.log('  node scripts/test-notification.js 507f1f77bcf86cd799439011');
  process.exit(1);
}

const userId = args[0];
const shouldDelete = args.includes('--delete');

testNotification(userId, shouldDelete);

