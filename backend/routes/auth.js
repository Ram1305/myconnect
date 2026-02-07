const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const multer = require('multer');
const path = require('path');
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const { auth } = require('../middleware/auth');
const { userProfileImageStorage } = require('../config/cloudinary');
const { requestPasswordResetOTP, verifyOTP, isOTPVerified, clearOTP } = require('../services/emailService');
const { sendNotificationToMultiple, saveNotificationToDb } = require('../services/notificationService');

// Configure multer for file uploads using Cloudinary
// Images are uploaded to Cloudinary and only the URL is stored in database
const upload = multer({
  storage: userProfileImageStorage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    // Allow common image MIME types
    const allowedMimeTypes = /^image\/(jpeg|jpg|png|gif|webp)$/i;
    // Allow common image extensions
    const allowedExtensions = /\.(jpeg|jpg|png|gif|webp)$/i;

    const extname = allowedExtensions.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedMimeTypes.test(file.mimetype);

    // Accept if either MIME type or extension matches (more lenient)
    if (mimetype || extname) {
      return cb(null, true);
    } else {
      console.error('File rejected - MIME type:', file.mimetype, 'Extension:', path.extname(file.originalname));
      cb(new Error(`Only image files are allowed! Received: ${file.mimetype || 'unknown'} - ${file.originalname}`));
    }
  }
});

// Generate JWT token
const generateToken = (userId) => {
  return jwt.sign({ userId }, process.env.JWT_SECRET || 'your-secret-key', { expiresIn: '30d' });
};

// Signup
router.post('/signup', upload.single('profilePhoto'), async (req, res) => {
  try {
    console.log('🔵 [AUTH] Signup - Request received');

    // Check if an admin is creating this user
    let adminRequester = null;
    const authHeader = req.header('Authorization');
    if (authHeader) {
      try {
        const token = authHeader.replace('Bearer ', '');
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');
        const user = await User.findById(decoded.userId);
        if (user && (user.isAdmin || user.role === 'admin' || user.role === 'super-admin')) {
          adminRequester = user;
        }
      } catch (e) {
        console.log('🟡 [AUTH] Token in signup but invalid:', e.message);
      }
    }

    const {
      username,
      mobileNumber,
      password,
      latitude,
      longitude,
      currentAddress,
      nativeAddress,
      useSameAddress,
      fatherName,
      grandfatherName,
      highestQualification,
      workingDetails,
      isAdmin,
      role,
      createdByAdmin
    } = req.body;

    console.log('   username:', username);
    console.log('   mobileNumber:', mobileNumber);
    console.log('   password provided:', password ? 'Yes' : 'No');
    console.log('   latitude:', latitude, '| longitude:', longitude);
    console.log('   useSameAddress:', useSameAddress);
    console.log('   isAdmin:', isAdmin, '| createdByAdmin:', createdByAdmin);
    console.log('   profilePhoto in request:', req.file ? 'Yes (' + (req.file.originalname || '') + ')' : 'No');

    // Check if user already exists
    const existingUser = await User.findOne({
      $or: [{ username }, { mobileNumber }]
    });

    if (existingUser) {
      console.log('❌ [AUTH] Signup - User already exists:', existingUser.username || existingUser.mobileNumber);
      return res.status(400).json({ message: 'Username or mobile number already exists' });
    }
    console.log('✅ [AUTH] Signup - No existing user; proceeding');

    // Parse JSON strings if needed
    let currentAddr = {};
    let nativeAddr = {};
    let working = { isWorking: false, isBusiness: false };

    try {
      currentAddr = typeof currentAddress === 'string' ? JSON.parse(currentAddress) : (currentAddress || {});
      nativeAddr = typeof nativeAddress === 'string' ? JSON.parse(nativeAddress) : (nativeAddress || {});
      working = typeof workingDetails === 'string' ? JSON.parse(workingDetails) : (workingDetails || {});
    } catch (parseError) {
      console.error('❌ [AUTH] Signup - Error parsing JSON fields:', parseError);
      return res.status(400).json({ message: 'Invalid data format', error: parseError.message });
    }

    // If useSameAddress is true, copy current address to native address
    const useSame = useSameAddress === 'true' || useSameAddress === true;
    if (useSame && currentAddr && Object.keys(currentAddr).length > 0) {
      nativeAddr = { ...currentAddr };
    }

    // Ensure addresses have all required fields with defaults
    if (!currentAddr || typeof currentAddr !== 'object') {
      currentAddr = {};
    }
    currentAddr.address = (currentAddr.address || '').trim() || 'Address not specified';
    currentAddr.state = (currentAddr.state || '').trim() || '';
    currentAddr.pincode = (currentAddr.pincode || '').trim() || '';
    currentAddr.latitude = currentAddr.latitude || parseFloat(latitude) || 0.0;
    currentAddr.longitude = currentAddr.longitude || parseFloat(longitude) || 0.0;

    if (!nativeAddr || typeof nativeAddr !== 'object') {
      nativeAddr = {};
    }
    nativeAddr.address = (nativeAddr.address || '').trim() || 'Address not specified';
    nativeAddr.state = (nativeAddr.state || '').trim() || '';
    nativeAddr.pincode = (nativeAddr.pincode || '').trim() || '';
    nativeAddr.latitude = nativeAddr.latitude || parseFloat(latitude) || 0.0;
    nativeAddr.longitude = nativeAddr.longitude || parseFloat(longitude) || 0.0;

    // Ensure working details have all fields with defaults
    if (!working || typeof working !== 'object') {
      working = { isWorking: false, isBusiness: false, professionType: 'business' };
    }

    // Handle profession type - always set isWorking to true when profession is provided
    const professionType = working.professionType || 'business';
    working.professionType = professionType;
    working.isWorking = true; // Always true when profession is selected
    working.isBusiness = professionType === 'business';

    // Set defaults for all fields based on profession type
    if (professionType === 'business') {
      // Business: Only Business Type and Business Name
      working.businessType = (working.businessType || '').trim() || '';
      working.businessName = (working.businessName || '').trim() || '';
      // Clear other fields
      working.companyName = '';
      working.position = '';
      working.workingMeans = '';
      working.totalYearsExperience = 0;
      working.collegeName = '';
      working.studentYear = '';
      working.department = '';
    } else if (professionType === 'job') {
      // Job: Company Name, Position, Working Type, Total Years of Experience
      working.companyName = (working.companyName || '').trim() || '';
      working.position = (working.position || '').trim() || '';
      working.workingMeans = (working.workingMeans || '').trim() || '';
      working.totalYearsExperience = parseInt(working.totalYearsExperience) || 0;
      // Clear other fields
      working.businessType = '';
      working.businessName = '';
      working.collegeName = '';
      working.studentYear = '';
      working.department = '';
    } else if (professionType === 'student') {
      // Student: College Name, Year, Department
      working.collegeName = (working.collegeName || '').trim() || '';
      working.studentYear = (working.studentYear || '').trim() || '';
      working.department = (working.department || '').trim() || '';
      // Clear other fields
      working.businessType = '';
      working.businessName = '';
      working.companyName = '';
      working.position = '';
      working.workingMeans = '';
      working.totalYearsExperience = 0;
    }

    // Validate required fields
    // highestQualification is optional for all users
    if (!username || !mobileNumber || !password) {
      console.log('❌ [AUTH] Signup - Missing required fields (username/mobileNumber/password)');
      return res.status(400).json({ message: 'Missing required fields' });
    }

    if (!latitude || !longitude) {
      console.log('❌ [AUTH] Signup - Missing latitude/longitude');
      return res.status(400).json({ message: 'Latitude and longitude are required' });
    }
    console.log('✅ [AUTH] Signup - Validation passed');

    // Get Cloudinary URL from uploaded file
    // multer-storage-cloudinary stores the secure_url in req.file.path
    let profilePhotoUrl = '';
    if (req.file) {
      // req.file.path contains the Cloudinary secure URL (e.g., https://res.cloudinary.com/.../image.jpg)
      profilePhotoUrl = req.file.path || '';

      // Validate that we have a proper HTTPS URL
      if (profilePhotoUrl && !profilePhotoUrl.startsWith('http')) {
        console.error('❌ [AUTH] Invalid Cloudinary URL format:', profilePhotoUrl);
        return res.status(500).json({
          message: 'Error uploading image to Cloudinary',
          error: 'Invalid URL format received from Cloudinary'
        });
      }

      console.log('✅ [AUTH] Profile photo uploaded to Cloudinary:');
      console.log('   URL:', profilePhotoUrl);
      console.log('   Original name:', req.file.originalname);
      console.log('   Size:', req.file.size, 'bytes');
    } else {
      console.log('⚠️ [AUTH] No profile photo provided - user will have no profile image');
    }

    const user = new User({
      username: username.trim(),
      mobileNumber: mobileNumber.trim(),
      password,
      latitude: parseFloat(latitude),
      longitude: parseFloat(longitude),
      currentAddress: currentAddr,
      nativeAddress: nativeAddr,
      useSameAddress: useSame,
      fatherName: fatherName ? fatherName.trim() : '',
      grandfatherName: grandfatherName ? grandfatherName.trim() : '',
      highestQualification: highestQualification ? highestQualification.trim() : '',
      workingDetails: working,
      profilePhoto: profilePhotoUrl,
      isAdmin: isAdmin === 'true' || isAdmin === true || role === 'admin' || role === 'super-admin',
      role: (adminRequester && (role === 'admin' || role === 'super-admin')) ? role : 'user',
      createdByAdmin: adminRequester ? adminRequester._id : null,
      // Auto-approve if created by admin or if user is admin
      status: (adminRequester || isAdmin === 'true' || isAdmin === true) ? 'approved' : 'pending'
    });

    // Save user to database
    await user.save();

    console.log('🔵 [AUTH] Signup - User registered successfully and saved to database.');
    console.log('   userId:', user._id.toString());
    console.log('   username:', user.username);
    console.log('   mobileNumber:', user.mobileNumber);
    console.log('   status:', user.status);

    // Notify admins about new registration (Background task)
    // Wrap in a function and don't await to avoid delaying the response
    (async () => {
      try {
        const admins = await User.find({ isAdmin: true });
        if (admins.length > 0) {
          const adminTokens = admins.map(a => a.fcmToken).filter(token => token);
          const title = 'New User Registration';
          const body = `${user.username} has registered and is waiting for approval.`;

          // Send push notifications
          if (adminTokens.length > 0) {
            await sendNotificationToMultiple(adminTokens, title, body, {
              type: 'new_registration',
              userId: user._id.toString()
            });
          }

          // Save notifications to DB for each admin
          for (const adminUser of admins) {
            await saveNotificationToDb(adminUser._id, title, body, 'new_registration', {
              userId: user._id.toString()
            });
          }
          console.log(`✅ [AUTH] Admin notifications sent to ${admins.length} admins`);
        }
      } catch (notifError) {
        console.error('❌ [AUTH] Error sending admin notifications:', notifError);
      }
    })();

    res.status(201).json({
      message: user.status === 'approved'
        ? 'Registration successful.'
        : 'Registration successful. Waiting for approval.',
      user: {
        id: user._id.toString(),
        username: user.username,
        mobileNumber: user.mobileNumber,
        status: user.status
      }
    });
    console.log('✅ [AUTH] Signup - Response sent (201)');
  } catch (error) {
    console.error('❌ [AUTH] Signup error:', error);
    console.error('   message:', error?.message);
    console.error('   stack:', error?.stack);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Login
router.post('/login', async (req, res) => {
  try {
    const { mobileNumber, password } = req.body;

    console.log('🔵 [AUTH] Login - Starting login attempt');
    console.log('   Mobile Number:', mobileNumber);
    console.log('   Password provided:', password ? 'Yes' : 'No');

    const user = await User.findOne({ mobileNumber });
    if (!user) {
      console.log('❌ [AUTH] Login - User not found for mobile:', mobileNumber);
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    console.log('✅ [AUTH] Login - User found');
    console.log('   User ID:', user._id.toString());
    console.log('   Username:', user.username);
    console.log('   isAdmin (raw):', user.isAdmin, '| type:', typeof user.isAdmin);
    console.log('   Status:', user.status);
    console.log('   Token value:', user.token === null ? 'NULL' : user.token === undefined ? 'UNDEFINED' : user.token === '' ? 'EMPTY STRING' : 'EXISTS (length: ' + user.token.length + ')');
    console.log('   Token JSON:', JSON.stringify(user.token));

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      console.log('❌ [AUTH] Login - Password mismatch for user:', user._id.toString());
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    console.log('✅ [AUTH] Login - Password verified');

    // Check if user is approved
    if (user.status !== 'approved') {
      console.log('❌ [AUTH] Login - User not approved. Status:', user.status);
      return res.status(403).json({
        message: 'Your account is pending approval. Please contact administrator.',
        error: 'ACCOUNT_PENDING'
      });
    }

    console.log('✅ [AUTH] Login - User is approved');

    // Check if admin has allowed login (token should be null)
    // If token exists, user has already logged in and needs admin to allow again
    // Skip this check for admin users - admins can always login
    // Handle both boolean and string values for isAdmin
    const isAdminUser = user.isAdmin === true || user.isAdmin === 'true' || user.isAdmin === 1;

    // Check if token exists (treat null, undefined, and empty string as "no token")
    const hasToken = user.token !== null && user.token !== undefined && user.token !== '';

    console.log('🔵 [AUTH] Login - Checking admin status and token');
    console.log('   isAdminUser check result:', isAdminUser);
    console.log('   user.isAdmin === true:', user.isAdmin === true);
    console.log('   user.isAdmin === "true":', user.isAdmin === 'true');
    console.log('   user.isAdmin === 1:', user.isAdmin === 1);
    console.log('   user.token raw value:', JSON.stringify(user.token));
    console.log('   user.token type:', typeof user.token);
    console.log('   user.token length:', user.token ? user.token.length : 'N/A');
    console.log('   hasToken (token exists check):', hasToken);
    console.log('   user.token !== null:', user.token !== null);
    console.log('   user.token !== undefined:', user.token !== undefined);
    console.log('   user.token !== "":', user.token !== '');
    console.log('   !isAdminUser:', !isAdminUser);
    console.log('   Condition (!isAdminUser && hasToken):', !isAdminUser && hasToken);

    // Only block non-admin users who have a token
    // Admin users can always login regardless of token status
    if (!isAdminUser && hasToken) {
      console.log('❌ [AUTH] Login - BLOCKED: Non-admin user with existing token');
      console.log('   User ID:', user._id.toString());
      console.log('   Username:', user.username);
      console.log('   isAdmin value:', user.isAdmin, 'type:', typeof user.isAdmin);
      console.log('   isAdminUser:', isAdminUser);
      console.log('   hasToken:', hasToken);
      return res.status(403).json({
        message: 'Please ask your administrator to allow login.',
        error: 'LOGIN_NOT_ALLOWED'
      });
    }

    if (isAdminUser) {
      console.log('✅ [AUTH] Login - Admin user detected, allowing login');
      if (hasToken) {
        console.log('   Admin has existing token, will be replaced');
      } else {
        console.log('   Admin has no token, generating new one');
      }
    }

    console.log('✅ [AUTH] Login - Token check passed (admin user or no token)');

    // For admin users, log that token restriction is bypassed
    if (isAdminUser && user.token !== null && user.token !== undefined && user.token !== '') {
      console.log('🔵 [AUTH] Login - Admin user login: Token restriction bypassed.');
      console.log('   Admin User ID:', user._id.toString());
    }

    // Admin has allowed login (token is null) - generate and store new token
    console.log('🔵 [AUTH] Login - Proceeding to generate token');
    console.log('   User ID:', user._id.toString());
    console.log('   Is Admin:', isAdminUser);

    const token = generateToken(user._id);
    console.log('✅ [AUTH] Login - Token generated successfully');
    console.log('   Token length:', token.length);
    console.log('   User ID:', user._id.toString());

    // Store token using direct MongoDB update for reliability
    let tokenSaved = false;
    try {
      const db = User.db;
      const collection = db.collection('users');
      const updateResult = await collection.updateOne(
        { _id: user._id },
        { $set: { token: token } }
      );

      console.log('🔵 [AUTH] Login - Token update result:', {
        matched: updateResult.matchedCount,
        modified: updateResult.modifiedCount,
        acknowledged: updateResult.acknowledged
      });

      if (updateResult.modifiedCount > 0 || updateResult.matchedCount > 0) {
        // Wait a moment for write to complete
        await new Promise(resolve => setTimeout(resolve, 100));

        // Verify token was saved
        const verifyUser = await User.findById(user._id).select('token');
        if (verifyUser && verifyUser.token === token) {
          console.log('✅ [AUTH] Login - Token stored and verified successfully');
          tokenSaved = true;
        } else {
          console.error('❌ [AUTH] Login - Token update completed but verification failed');
          console.error('   Expected token length:', token.length);
          console.error('   Got token:', verifyUser?.token ? verifyUser.token.length + ' chars' : 'null/undefined');
        }
      }
    } catch (dbError) {
      console.error('❌ [AUTH] Login - Token storage error:', dbError.message);
    }

    // Fallback: Try findOneAndUpdate if direct MongoDB update failed
    if (!tokenSaved) {
      try {
        const updatedUser = await User.findOneAndUpdate(
          { _id: user._id },
          { token: token },
          { new: true, runValidators: false }
        );

        if (updatedUser) {
          const verifyUser = await User.findById(user._id).select('token');
          if (verifyUser && verifyUser.token === token) {
            console.log('✅ [AUTH] Login - Token saved using findOneAndUpdate fallback');
            tokenSaved = true;
          }
        }
      } catch (updateError) {
        console.error('❌ [AUTH] Login - Fallback update error:', updateError.message);
      }
    }

    if (!tokenSaved) {
      console.error('❌ [AUTH] Login - Token storage failed for user:', user._id.toString());
      return res.status(500).json({
        message: 'Failed to store authentication token. Please try again.',
        error: 'TOKEN_STORAGE_FAILED'
      });
    }

    console.log('✅ [AUTH] Login - SUCCESS - Sending response to client');
    console.log('   User ID:', user._id.toString());
    console.log('   Username:', user.username);
    console.log('   isAdmin:', user.isAdmin);
    console.log('   Token generated and stored successfully');

    res.json({
      token,
      user: {
        id: user._id,
        username: user.username,
        mobileNumber: user.mobileNumber,
        status: user.status,
        isAdmin: user.isAdmin,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Update FCM token
router.put('/fcm-token', auth, async (req, res) => {
  try {
    const { fcmToken } = req.body;

    await User.findByIdAndUpdate(
      req.user._id,
      { fcmToken: fcmToken || null },
      { new: true }
    );

    res.json({ message: 'FCM token updated successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Logout - Clear token from backend
router.post('/logout', auth, async (req, res) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    const user = await User.findById(req.user._id);

    // Check if token matches the stored token
    if (!user.token || user.token !== token) {
      return res.status(403).json({
        message: 'Token mismatch. Please ask your administrator to allow login.',
        error: 'TOKEN_MISMATCH'
      });
    }

    // DO NOT clear token - keep it stored so user cannot login again
    // until admin allows login again. This prevents re-login after logout/reinstall.
    console.log('🔵 [AUTH] Logout - Token kept stored. User will need admin to allow login again.');

    res.json({ message: 'Logged out successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get current user
router.get('/me', auth, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('-password');
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;
