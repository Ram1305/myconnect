/**
 * Seed Super Admin
 * Creates or updates the default super admin user (mobile: 1234567890, password: 123456).
 *
 * Usage:
 *   node scripts/seed-super-admin.js
 *   (from backend directory: node scripts/seed-super-admin.js)
 */

try {
  require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
} catch (e) {
  // dotenv optional
}
const mongoose = require('mongoose');
const User = require('../models/User');

const SUPER_ADMIN_MOBILE = '1234567890';
const SUPER_ADMIN_PASSWORD = '123456';
const SUPER_ADMIN_USERNAME = 'Super Admin';

async function seedSuperAdmin() {
  try {
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/myconnect';
    await mongoose.connect(mongoUri);
    console.log('✅ Connected to MongoDB\n');

    let user = await User.findOne({ mobileNumber: SUPER_ADMIN_MOBILE });

    if (user) {
      user.username = SUPER_ADMIN_USERNAME;
      user.password = SUPER_ADMIN_PASSWORD; // will be hashed by pre-save
      user.role = 'super-admin';
      user.isAdmin = true;
      user.status = 'approved';
      user.fatherName = user.fatherName || 'N/A';
      user.grandfatherName = user.grandfatherName || 'N/A';
      await user.save();
      console.log('✅ Super admin updated. Mobile:', SUPER_ADMIN_MOBILE);
    } else {
      user = new User({
        username: SUPER_ADMIN_USERNAME,
        mobileNumber: SUPER_ADMIN_MOBILE,
        password: SUPER_ADMIN_PASSWORD,
        latitude: 0,
        longitude: 0,
        fatherName: 'N/A',
        grandfatherName: 'N/A',
        currentAddress: { address: '', state: '', pincode: '', latitude: 0, longitude: 0 },
        nativeAddress: { address: '', state: '', pincode: '', latitude: 0, longitude: 0 },
        useSameAddress: false,
        highestQualification: '',
        workingDetails: { isWorking: false, isBusiness: false },
        status: 'approved',
        isAdmin: true,
        role: 'super-admin',
      });
      await user.save();
      console.log('✅ Super admin created. Mobile:', SUPER_ADMIN_MOBILE, '| Password:', SUPER_ADMIN_PASSWORD);
    }

    console.log('   Login with mobile:', SUPER_ADMIN_MOBILE, 'and password:', SUPER_ADMIN_PASSWORD);
    await mongoose.disconnect();
    process.exit(0);
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

seedSuperAdmin();
