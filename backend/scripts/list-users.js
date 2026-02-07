/**
 * List Users Script
 * Lists all users with their IDs, usernames, and FCM token status
 * 
 * Usage:
 *   node scripts/list-users.js
 *   node scripts/list-users.js --with-tokens  (only users with FCM tokens)
 */

require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');

async function listUsers(onlyWithTokens = false) {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/myconnect', {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('✅ Connected to MongoDB\n');

    // Build query
    const query = onlyWithTokens ? { fcmToken: { $ne: null, $exists: true } } : {};

    // Find users
    const users = await User.find(query).select('username mobileNumber fcmToken status').sort({ username: 1 });

    if (users.length === 0) {
      console.log('No users found');
      await mongoose.disconnect();
      process.exit(0);
    }

    console.log(`Found ${users.length} user(s):\n`);
    console.log('─'.repeat(100));
    console.log(
      'ID'.padEnd(25) +
      'Username'.padEnd(20) +
      'Mobile'.padEnd(15) +
      'Status'.padEnd(12) +
      'FCM Token'
    );
    console.log('─'.repeat(100));

    users.forEach((user) => {
      const id = user._id.toString();
      const username = (user.username || 'N/A').padEnd(20);
      const mobile = (user.mobileNumber || 'N/A').padEnd(15);
      const status = (user.status || 'N/A').padEnd(12);
      const hasToken = user.fcmToken ? '✅ Yes' : '❌ No';

      console.log(`${id} ${username} ${mobile} ${status} ${hasToken}`);
    });

    console.log('─'.repeat(100));
    console.log('\n💡 Copy a user ID to use with test-notification.js or delete-notifications.js');
    console.log('   Example: node scripts/test-notification.js ' + users[0]._id.toString());

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
const onlyWithTokens = args.includes('--with-tokens');

listUsers(onlyWithTokens);

