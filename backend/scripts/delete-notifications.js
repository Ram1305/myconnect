/**
 * Delete Notifications Script
 * Deletes all notifications for a specific user or all users
 * 
 * Usage:
 *   node scripts/delete-notifications.js <userId>     - Delete for specific user
 *   node scripts/delete-notifications.js --all        - Delete for all users
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Notification = require('../models/Notification');
const User = require('../models/User');

async function deleteNotifications(userId = null) {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/myconnect', {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('✅ Connected to MongoDB');

    if (userId === '--all') {
      // Delete all notifications
      const result = await Notification.deleteMany({});
      console.log(`🗑️  Deleted ${result.deletedCount} notifications for all users`);
    } else if (userId) {
      // Delete for specific user
      const user = await User.findById(userId);
      if (!user) {
        console.error('❌ User not found');
        process.exit(1);
      }

      console.log(`👤 User: ${user.username} (${user.mobileNumber})`);
      const result = await Notification.deleteMany({ recipient: userId });
      console.log(`🗑️  Deleted ${result.deletedCount} notifications for user ${user.username}`);
    } else {
      console.error('❌ Please provide userId or --all flag');
      process.exit(1);
    }

    console.log('✅ Notifications deleted successfully!');
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
  console.log('  node scripts/delete-notifications.js <userId>  - Delete for specific user');
  console.log('  node scripts/delete-notifications.js --all     - Delete for all users');
  console.log('\nExample:');
  console.log('  node scripts/delete-notifications.js 507f1f77bcf86cd799439011');
  console.log('  node scripts/delete-notifications.js --all');
  process.exit(1);
}

const userId = args[0];
deleteNotifications(userId);

