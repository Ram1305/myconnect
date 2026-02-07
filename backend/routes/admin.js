const express = require('express');
const router = express.Router();
const XLSX = require('xlsx');
const User = require('../models/User');
const Chat = require('../models/Chat');
const { adminAuth, superAdminAuth } = require('../middleware/auth');
const { sendStatusNotification } = require('../services/notificationService');
const multer = require('multer');
const path = require('path');
const { userProfileImageStorage } = require('../config/cloudinary');

// Configure multer for file uploads (same as auth.js)
const upload = multer({
  storage: userProfileImageStorage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    const allowedMimeTypes = /^image\/(jpeg|jpg|png|gif|webp)$/i;
    const allowedExtensions = /\.(jpeg|jpg|png|gif|webp)$/i;

    const extname = allowedExtensions.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedMimeTypes.test(file.mimetype);

    if (mimetype || extname) {
      return cb(null, true);
    } else {
      cb(new Error(`Only image files are allowed!`));
    }
  }
});

// Get pending users
router.get('/pending', adminAuth, async (req, res) => {
  try {
    const query = { status: 'pending', isAdmin: { $ne: true } };
    if (req.user.role === 'admin') {
      query.createdByAdmin = req.user._id;
    } else if (req.user.role === 'super-admin') {
      // Super admin can see all pending users including other admins if needed
      delete query.isAdmin;
      query.status = 'pending';
    }

    const users = await User.find(query).select('-password').sort({ createdAt: -1 });
    res.json(users);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get approved users
router.get('/approved', adminAuth, async (req, res) => {
  try {
    const query = { status: 'approved', isAdmin: { $ne: true } };
    if (req.user.role === 'admin') {
      query.createdByAdmin = req.user._id;
    } else if (req.user.role === 'super-admin') {
      delete query.isAdmin;
      query.status = 'approved';
    }

    const users = await User.find(query).select('-password').sort({ createdAt: -1 });
    res.json(users);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get rejected users
router.get('/rejected', adminAuth, async (req, res) => {
  try {
    const query = { status: 'rejected', isAdmin: { $ne: true } };
    if (req.user.role === 'admin') {
      query.createdByAdmin = req.user._id;
    } else if (req.user.role === 'super-admin') {
      delete query.isAdmin;
      query.status = 'rejected';
    }

    const users = await User.find(query).select('-password').sort({ createdAt: -1 });
    res.json(users);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// ----- Super-admin-only routes -----

// List all admins (super-admin only)
router.get('/admins', superAdminAuth, async (req, res) => {
  try {
    const admins = await User.find({
      $or: [{ role: 'admin' }, { role: 'super-admin' }, { isAdmin: true }]
    })
      .select('username mobileNumber role isAdmin')
      .sort({ username: 1 });

    const adminsWithCount = await Promise.all(
      admins.map(async (admin) => {
        const relatedCount = await User.countDocuments({ createdByAdmin: admin._id });
        return {
          _id: admin._id,
          username: admin.username,
          mobileNumber: admin.mobileNumber,
          role: admin.role,
          isAdmin: admin.isAdmin,
          relatedCount
        };
      })
    );

    res.json(adminsWithCount);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get users related to an admin (createdByAdmin = adminId) (super-admin only)
router.get('/admins/:adminId/related', superAdminAuth, async (req, res) => {
  try {
    const { adminId } = req.params;
    const admin = await User.findOne({
      _id: adminId,
      $or: [{ role: 'admin' }, { role: 'super-admin' }, { isAdmin: true }]
    });
    if (!admin) {
      return res.status(404).json({ message: 'Admin not found' });
    }
    const users = await User.find({ createdByAdmin: adminId })
      .select('-password')
      .sort({ createdAt: -1 });
    res.json(users);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Assign a user to an admin (set createdByAdmin) (super-admin only)
router.put('/users/:userId/assign-admin', superAdminAuth, async (req, res) => {
  try {
    const { userId } = req.params;
    const { adminId } = req.body;
    if (!adminId) {
      return res.status(400).json({ message: 'adminId is required' });
    }
    const admin = await User.findOne({
      _id: adminId,
      $or: [{ role: 'admin' }, { role: 'super-admin' }, { isAdmin: true }]
    });
    if (!admin) {
      return res.status(404).json({ message: 'Admin not found' });
    }
    const user = await User.findByIdAndUpdate(
      userId,
      { createdByAdmin: adminId },
      { new: true }
    ).select('-password');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    res.json({ message: 'User assigned to admin', user });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Approve user
router.put('/approve/:id', adminAuth, async (req, res) => {
  console.log(`🔵 [ADMIN] Approve request for user: ${req.params.id}`);
  try {
    const user = await User.findByIdAndUpdate(
      req.params.id,
      { status: 'approved' },
      { new: true }
    ).select('-password');

    if (!user) {
      console.log(`❌ [ADMIN] User not found: ${req.params.id}`);
      return res.status(404).json({ message: 'User not found' });
    }

    console.log(`✅ [ADMIN] User approved. ID: ${user._id}, Status: ${user.status}`);

    // Send notification to user
    if (user.fcmToken) {
      try {
        await sendStatusNotification(user.fcmToken, 'approved');
        console.log(`✅ [ADMIN] Approved notification sent to ${user._id}`);
      } catch (notifError) {
        console.error(`⚠️ [ADMIN] Failed to send approved notification: ${notifError.message}`);
      }
    }

    res.json({ message: 'User approved', user });
  } catch (error) {
    console.error(`❌ [ADMIN] Approve error: ${error.message}`);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Reject user
router.put('/reject/:id', adminAuth, async (req, res) => {
  console.log(`🔵 [ADMIN] Reject request for user: ${req.params.id}`);
  try {
    const user = await User.findByIdAndUpdate(
      req.params.id,
      { status: 'rejected' },
      { new: true }
    ).select('-password');

    if (!user) {
      console.log(`❌ [ADMIN] User not found: ${req.params.id}`);
      return res.status(404).json({ message: 'User not found' });
    }

    console.log(`✅ [ADMIN] User rejected. ID: ${user._id}, Status: ${user.status}`);

    // Send notification to user
    if (user.fcmToken) {
      try {
        await sendStatusNotification(user.fcmToken, 'rejected');
        console.log(`✅ [ADMIN] Rejected notification sent to ${user._id}`);
      } catch (notifError) {
        console.error(`⚠️ [ADMIN] Failed to send rejected notification: ${notifError.message}`);
      }
    }

    res.json({ message: 'User rejected', user });
  } catch (error) {
    console.error(`❌ [ADMIN] Reject error: ${error.message}`);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Set user to pending
router.put('/pending/:id', adminAuth, async (req, res) => {
  try {
    const user = await User.findByIdAndUpdate(
      req.params.id,
      { status: 'pending' },
      { new: true }
    ).select('-password');

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Send notification to user
    if (user.fcmToken) {
      await sendStatusNotification(user.fcmToken, 'pending');
    }

    res.json({ message: 'User set to pending', user });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get users who cannot login (have token stored - logged out or reinstalled)
router.get('/cannot-login', adminAuth, async (req, res) => {
  try {
    // Find approved users who have a token stored
    // These users have logged in before but logged out/reinstalled app
    // They need admin to "allow login" again (clear token) before they can login
    const users = await User.find({
      status: 'approved',
      isAdmin: { $ne: true },
      token: { $ne: null, $exists: true } // Users with tokens stored (cannot login until admin allows)
    }).select('-password').sort({ updatedAt: -1 });

    res.json(users);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Allow user to login (clear their stored token so they can login fresh)
router.put('/allow-login/:id', adminAuth, async (req, res) => {
  try {
    const user = await User.findByIdAndUpdate(
      req.params.id,
      { token: null }, // Clear token - this allows user to login (token will be generated on login)
      { new: true }
    ).select('-password');

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    console.log('✅ [ADMIN] Login allowed for user:', req.params.id);
    res.json({ message: 'User can now login', user });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get all chats (admin view)
router.get('/chats', adminAuth, async (req, res) => {
  try {
    const chats = await Chat.find()
      .populate('participants', 'username mobileNumber profilePhoto')
      .sort({ lastMessageTime: -1 })
      .limit(100);

    res.json(chats);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get all chats for a specific user (admin view)
router.get('/user/:userId/chats', adminAuth, async (req, res) => {
  try {
    const chats = await Chat.find({
      participants: req.params.userId,
      isPublic: { $ne: true } // Exclude public chats
    })
      .populate('participants', 'username mobileNumber profilePhoto')
      .populate('messages.sender', 'username profilePhoto')
      .sort({ lastMessageTime: -1 });

    res.json(chats);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get chat messages (admin view - no participant check)
router.get('/chat/:chatId/messages', adminAuth, async (req, res) => {
  try {
    const chat = await Chat.findById(req.params.chatId)
      .populate('participants', 'username mobileNumber profilePhoto')
      .populate('messages.sender', 'username profilePhoto');

    if (!chat) {
      return res.status(404).json({ message: 'Chat not found' });
    }

    console.log(`✅ [ADMIN] Chat ${req.params.chatId} loaded with ${chat.messages?.length || 0} messages`);

    // Ensure messages array exists
    if (!chat.messages) {
      chat.messages = [];
    }

    res.json(chat);
  } catch (error) {
    console.error(`❌ [ADMIN] Error loading chat ${req.params.chatId}:`, error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete a chat (admin only)
router.delete('/chat/:chatId', adminAuth, async (req, res) => {
  try {
    const chat = await Chat.findById(req.params.chatId);

    if (!chat) {
      return res.status(404).json({ message: 'Chat not found' });
    }

    await Chat.findByIdAndDelete(req.params.chatId);
    res.json({ message: 'Chat deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete multiple chats (admin only)
router.delete('/chats', adminAuth, async (req, res) => {
  try {
    const { chatIds } = req.body;

    if (!chatIds || !Array.isArray(chatIds) || chatIds.length === 0) {
      return res.status(400).json({ message: 'Chat IDs are required' });
    }

    const result = await Chat.deleteMany({ _id: { $in: chatIds } });
    res.json({ message: `${result.deletedCount} chat(s) deleted successfully` });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete messages from a chat (admin only)
router.delete('/chat/:chatId/messages', adminAuth, async (req, res) => {
  try {
    const { messageIds } = req.body;
    const { chatId } = req.params;

    if (!messageIds || !Array.isArray(messageIds) || messageIds.length === 0) {
      return res.status(400).json({ message: 'Message IDs are required' });
    }

    const chat = await Chat.findById(chatId);

    if (!chat) {
      return res.status(404).json({ message: 'Chat not found' });
    }

    // Remove messages from the chat
    const initialCount = chat.messages.length;
    chat.messages = chat.messages.filter(
      msg => !messageIds.includes(msg._id.toString())
    );
    const deletedCount = initialCount - chat.messages.length;

    // Update lastMessageTime if messages were deleted
    if (chat.messages.length > 0) {
      chat.lastMessageTime = chat.messages[chat.messages.length - 1].timestamp || chat.messages[chat.messages.length - 1].createdAt;
      chat.lastMessage = chat.messages[chat.messages.length - 1].message;
    } else {
      chat.lastMessageTime = null;
      chat.lastMessage = null;
    }

    await chat.save();

    res.json({
      message: `${deletedCount} message(s) deleted successfully`,
      deletedCount
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Export users to Excel
router.get('/export/users', adminAuth, async (req, res) => {
  try {
    const { status } = req.query; // Optional: filter by status (pending, approved, rejected)

    // Build query
    const query = { isAdmin: { $ne: true } };
    if (status && ['pending', 'approved', 'rejected'].includes(status)) {
      query.status = status;
    }

    // Fetch users
    const users = await User.find(query)
      .select('-password')
      .sort({ createdAt: -1 });

    if (users.length === 0) {
      return res.status(404).json({ message: 'No users found to export' });
    }

    // Prepare data for Excel
    const excelData = users.map(user => ({
      'Username': user.username || '',
      'Mobile Number': user.mobileNumber || '',
      'Secondary Mobile Number': user.secondaryMobileNumber || '',
      'Email ID': user.emailId || '',
      'Father Name': user.fatherName || '',
      'Grandfather Name': user.grandfatherName || '',
      'Mother Name': user.motherName || '',
      'Mother Native': user.motherNative || '',
      'Grandmother Name': user.grandmotherName || '',
      'Grandmother Native': user.grandmotherNative || '',
      'Blood Group': user.bloodGroup || '',
      'Highest Qualification': user.highestQualification || '',
      'Date of Birth': user.dateOfBirth ? new Date(user.dateOfBirth).toLocaleDateString() : '',
      'Marital Status': user.maritalStatus || '',
      'Spouse Name': user.spouseName || '',
      'Spouse Native': user.spouseNative || '',
      'Current Address': user.currentAddress?.address || '',
      'Current State': user.currentAddress?.state || '',
      'Current Pincode': user.currentAddress?.pincode || '',
      'Native Address': user.nativeAddress?.address || '',
      'Native State': user.nativeAddress?.state || '',
      'Native Pincode': user.nativeAddress?.pincode || '',
      'Is Working': user.workingDetails?.isWorking ? 'Yes' : 'No',
      'Is Business': user.workingDetails?.isBusiness ? 'Yes' : 'No',
      'Company Name': user.workingDetails?.companyName || '',
      'Position': user.workingDetails?.position || '',
      'Total Years Experience': user.workingDetails?.totalYearsExperience || '',
      'Business Type': user.workingDetails?.businessType || '',
      'Business Name': user.workingDetails?.businessName || '',
      'Has Education': user.hasEducation ? 'Yes' : 'No',
      'College': user.college || '',
      'Year of Completion': user.yearOfCompletion || '',
      'Course': user.course || '',
      'Start Year': user.startYear || '',
      'End Year': user.endYear || '',
      'Status': user.status || '',
      'Created At': user.createdAt ? new Date(user.createdAt).toLocaleDateString() : '',
      'Updated At': user.updatedAt ? new Date(user.updatedAt).toLocaleDateString() : '',
    }));

    // Create workbook and worksheet
    const worksheet = XLSX.utils.json_to_sheet(excelData);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Users');

    // Generate Excel file buffer
    const excelBuffer = XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });

    // Set response headers
    const filename = `myconnect_users_${status || 'all'}_${Date.now()}.xlsx`;
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

    // Send file
    res.send(excelBuffer);
  } catch (error) {
    console.error('Export users error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Update user profile (Admin)
router.put('/users/:id', adminAuth, upload.fields([
  { name: 'profilePhoto', maxCount: 1 },
  { name: 'spousePhoto', maxCount: 1 },
  { name: 'familyPhoto', maxCount: 1 },
  { name: 'kidPhotos', maxCount: 10 }
]), async (req, res) => {
  try {
    const {
      username,
      mobileNumber,
      secondaryMobileNumber,
      fatherName,
      grandfatherName,
      greatGrandfatherName,
      motherName,
      motherNative,
      grandmotherName,
      grandmotherNative,
      emailId,
      bloodGroup,
      highestQualification,
      dateOfBirth,
      maritalStatus,
      spouseName,
      spouseNative,
      hasEducation,
      college,
      yearOfCompletion,
      course,
      startYear,
      endYear,
      extraDegrees,
      kids,
      currentAddress,
      nativeAddress,
      useSameAddress,
      workingDetails,
      status // Admin can also update status directly here if needed, but usually better via specific endpoints
    } = req.body;

    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Parse JSON strings if needed
    let currentAddr = {};
    let nativeAddr = {};
    let working = { isWorking: false, isBusiness: false };

    try {
      currentAddr = typeof currentAddress === 'string' ? JSON.parse(currentAddress) : (currentAddress || {});
      nativeAddr = typeof nativeAddress === 'string' ? JSON.parse(nativeAddress) : (nativeAddress || {});
      working = typeof workingDetails === 'string' ? JSON.parse(workingDetails) : (workingDetails || {});
    } catch (parseError) {
      console.error('Error parsing JSON fields:', parseError);
      return res.status(400).json({ message: 'Invalid data format', error: parseError.message });
    }

    // If useSameAddress is true, copy current address to native address
    const useSame = useSameAddress === 'true' || useSameAddress === true;
    if (useSame && currentAddr && Object.keys(currentAddr).length > 0) {
      nativeAddr = { ...currentAddr };
    }

    // Ensure addresses have all required fields (merge with existing if missing)
    if (!currentAddr || typeof currentAddr !== 'object') currentAddr = user.currentAddress || {};
    currentAddr.address = (currentAddr.address || '').trim() || (user.currentAddress?.address || '');
    currentAddr.state = (currentAddr.state || '').trim() || (user.currentAddress?.state || '');
    currentAddr.pincode = (currentAddr.pincode || '').trim() || (user.currentAddress?.pincode || '');
    currentAddr.latitude = currentAddr.latitude || user.currentAddress?.latitude || user.latitude || 0.0;
    currentAddr.longitude = currentAddr.longitude || user.currentAddress?.longitude || user.longitude || 0.0;

    if (!nativeAddr || typeof nativeAddr !== 'object') nativeAddr = user.nativeAddress || {};
    nativeAddr.address = (nativeAddr.address || '').trim() || (user.nativeAddress?.address || '');
    nativeAddr.state = (nativeAddr.state || '').trim() || (user.nativeAddress?.state || '');
    nativeAddr.pincode = (nativeAddr.pincode || '').trim() || (user.nativeAddress?.pincode || '');
    nativeAddr.latitude = nativeAddr.latitude || user.nativeAddress?.latitude || user.latitude || 0.0;
    nativeAddr.longitude = nativeAddr.longitude || user.nativeAddress?.longitude || user.longitude || 0.0;

    // Ensure working details
    if (!working || typeof working !== 'object') working = user.workingDetails || { isWorking: false, isBusiness: false, professionType: 'business' };

    // Handle profession type
    const professionType = working.professionType || user.workingDetails?.professionType || 'business';
    working.professionType = professionType;

    const hasWorkingDetails = working.professionType ||
      working.companyName || working.position || working.businessName || working.collegeName;
    working.isWorking = hasWorkingDetails ? true : (working.isWorking === true || working.isWorking === 'true');
    working.isBusiness = professionType === 'business' || (working.isBusiness === true || working.isBusiness === 'true');

    // Set fields based on profession type
    if (professionType === 'business') {
      // Business: Only Business Type and Business Name
      working.businessType = (working.businessType || '').trim() || (user.workingDetails?.businessType || '');
      working.businessName = (working.businessName || '').trim() || (user.workingDetails?.businessName || '');

      // Handle multiple business addresses
      if (working.businessAddresses && Array.isArray(working.businessAddresses)) {
        working.businessAddresses = working.businessAddresses
          .map(addr => (addr || '').trim())
          .filter(addr => addr.length > 0);
      } else if (user.workingDetails?.businessAddresses && Array.isArray(user.workingDetails.businessAddresses)) {
        working.businessAddresses = user.workingDetails.businessAddresses;
      } else {
        working.businessAddresses = [];
      }

      // Keep single businessAddress for backward compatibility
      if (working.businessAddress) {
        working.businessAddress = (working.businessAddress || '').trim();
        if (working.businessAddresses.length === 0 && working.businessAddress) {
          working.businessAddresses = [working.businessAddress];
        }
      } else if (user.workingDetails?.businessAddress) {
        working.businessAddress = user.workingDetails.businessAddress;
        if (working.businessAddresses.length === 0) {
          working.businessAddresses = [working.businessAddress];
        }
      } else {
        working.businessAddress = working.businessAddresses.length > 0 ? working.businessAddresses[0] : '';
      }

      // Keep other fields from existing data if not switching
      working.companyName = (working.companyName || '').trim() || (user.workingDetails?.companyName || '');
      working.position = (working.position || '').trim() || (user.workingDetails?.position || '');
      working.workingMeans = (working.workingMeans || '').trim() || (user.workingDetails?.workingMeans || '');
      working.totalYearsExperience = parseInt(working.totalYearsExperience) || (user.workingDetails?.totalYearsExperience || 0);
      working.collegeName = (working.collegeName || '').trim() || (user.workingDetails?.collegeName || '');
      working.studentYear = (working.studentYear || '').trim() || (user.workingDetails?.studentYear || '');
      working.department = (working.department || '').trim() || (user.workingDetails?.department || '');
    } else if (professionType === 'job') {
      // Job: Company Name, Position, Working Type, Total Years of Experience
      working.companyName = (working.companyName || '').trim() || (user.workingDetails?.companyName || '');
      working.position = (working.position || '').trim() || (user.workingDetails?.position || '');
      working.workingMeans = (working.workingMeans || '').trim() || (user.workingDetails?.workingMeans || '');
      working.totalYearsExperience = parseInt(working.totalYearsExperience) || (user.workingDetails?.totalYearsExperience || 0);
      // Keep other fields from existing data if not switching
      working.businessType = (working.businessType || '').trim() || (user.workingDetails?.businessType || '');
      working.businessName = (working.businessName || '').trim() || (user.workingDetails?.businessName || '');
      working.collegeName = (working.collegeName || '').trim() || (user.workingDetails?.collegeName || '');
      working.studentYear = (working.studentYear || '').trim() || (user.workingDetails?.studentYear || '');
      working.department = (working.department || '').trim() || (user.workingDetails?.department || '');
    } else if (professionType === 'student') {
      // Student: College Name, Year, Department
      working.collegeName = (working.collegeName || '').trim() || (user.workingDetails?.collegeName || '');
      working.studentYear = (working.studentYear || '').trim() || (user.workingDetails?.studentYear || '');
      working.department = (working.department || '').trim() || (user.workingDetails?.department || '');
      // Keep other fields from existing data if not switching
      working.businessType = (working.businessType || '').trim() || (user.workingDetails?.businessType || '');
      working.businessName = (working.businessName || '').trim() || (user.workingDetails?.businessName || '');
      working.companyName = (working.companyName || '').trim() || (user.workingDetails?.companyName || '');
      working.position = (working.position || '').trim() || (user.workingDetails?.position || '');
      working.workingMeans = (working.workingMeans || '').trim() || (user.workingDetails?.workingMeans || '');
      working.totalYearsExperience = parseInt(working.totalYearsExperience) || (user.workingDetails?.totalYearsExperience || 0);
    }

    // Update fields
    if (username) user.username = username.trim();
    if (mobileNumber) {
      // Check if mobile number is already taken by another user
      const existingUser = await User.findOne({ mobileNumber: mobileNumber.trim(), _id: { $ne: user._id } });
      if (existingUser) {
        return res.status(400).json({ message: 'Mobile number already exists' });
      }
      user.mobileNumber = mobileNumber.trim();
    }
    if (secondaryMobileNumber !== undefined) user.secondaryMobileNumber = secondaryMobileNumber ? secondaryMobileNumber.trim() : null;
    if (fatherName) user.fatherName = fatherName.trim();
    if (grandfatherName) user.grandfatherName = grandfatherName.trim();
    if (greatGrandfatherName !== undefined) user.greatGrandfatherName = greatGrandfatherName ? greatGrandfatherName.trim() : null;
    if (motherName !== undefined) user.motherName = motherName ? motherName.trim() : null;
    if (motherNative !== undefined) user.motherNative = motherNative ? motherNative.trim() : null;
    if (grandmotherName !== undefined) user.grandmotherName = grandmotherName ? grandmotherName.trim() : null;
    if (grandmotherNative !== undefined) user.grandmotherNative = grandmotherNative ? grandmotherNative.trim() : null;
    if (emailId !== undefined) user.emailId = emailId ? emailId.trim() : null;
    if (bloodGroup !== undefined) user.bloodGroup = bloodGroup || null;
    if (highestQualification) user.highestQualification = highestQualification.trim();
    if (dateOfBirth) {
      try { user.dateOfBirth = new Date(dateOfBirth); } catch (e) { }
    }
    if (maritalStatus) user.maritalStatus = maritalStatus;
    if (spouseName) user.spouseName = spouseName.trim();
    if (spouseNative !== undefined) user.spouseNative = spouseNative ? spouseNative.trim() : null;

    if (hasEducation !== undefined) user.hasEducation = hasEducation === 'true' || hasEducation === true;
    if (college !== undefined) user.college = college ? college.trim() : null;
    if (yearOfCompletion !== undefined) user.yearOfCompletion = yearOfCompletion ? yearOfCompletion.trim() : null;
    if (course !== undefined) user.course = course ? course.trim() : null;
    if (startYear !== undefined) user.startYear = startYear ? startYear.trim() : null;
    if (endYear !== undefined) user.endYear = endYear ? endYear.trim() : null;

    if (extraDegrees !== undefined) {
      try {
        const degreesArray = typeof extraDegrees === 'string' ? JSON.parse(extraDegrees) : extraDegrees;
        if (Array.isArray(degreesArray)) {
          user.extraDegrees = degreesArray;
        }
      } catch (e) {
        console.error('Error parsing extraDegrees:', e);
      }
    }

    if (kids) {
      try {
        const kidsArray = typeof kids === 'string' ? JSON.parse(kids) : kids;
        if (Array.isArray(kidsArray)) {
          const processedKids = kidsArray.map((kid, index) => {
            const kidData = {
              name: kid.name || '',
              dateOfBirth: kid.dateOfBirth ? new Date(kid.dateOfBirth) : null,
              photo: kid.photo || '', // keep existing URL if any
              schoolName: kid.schoolName || '',
              standard: kid.standard || ''
            };
            // Handle kid photo upload if provided
            const kidPhotoFiles = req.files?.['kidPhotos'] || [];
            // We need to match file to kid index. This is tricky with multiple files.
            // Assumption: client sends files in order or we rely on some mapping.
            // Actually, multer flattens field array.
            // A simpler approach for array fields with files is complex in multipart/form-data.
            // For now, let's assume if files are sent, they correspond to indices where file was changed?
            // Or maybe matching by filename logic if implemented in frontend.
            // But here, let's just see if we can match simple order if files exist.
            // Better: use the logic from auth.js:
            if (kidPhotoFiles[index]) {
              const kidPhotoUrl = kidPhotoFiles[index].path || '';
              if (kidPhotoUrl && kidPhotoUrl.startsWith('http')) {
                kidData.photo = kidPhotoUrl;
              }
            }
            return kidData;
          });
          user.kids = processedKids;
        }
      } catch (e) {
        console.error('Error parsing kids:', e);
      }
    }

    user.currentAddress = currentAddr;
    user.nativeAddress = nativeAddr;
    user.useSameAddress = useSame;
    user.workingDetails = working;

    // Photos
    const profilePhotoFiles = req.files?.['profilePhoto'] || [];
    if (profilePhotoFiles.length > 0) {
      const url = profilePhotoFiles[0].path || '';
      if (url.startsWith('http')) user.profilePhoto = url;
    }
    const spousePhotoFiles = req.files?.['spousePhoto'] || [];
    if (spousePhotoFiles.length > 0) {
      const url = spousePhotoFiles[0].path || '';
      if (url.startsWith('http')) user.spousePhoto = url;
    }
    const familyPhotoFiles = req.files?.['familyPhoto'] || [];
    if (familyPhotoFiles.length > 0) {
      const url = familyPhotoFiles[0].path || '';
      if (url.startsWith('http')) user.familyPhoto = url;
    }

    await user.save();
    console.log(`✅ [ADMIN] Updated user profile for ${user.username} (${user._id})`);

    res.json({
      message: 'User profile updated successfully',
      user: await User.findById(user._id).select('-password')
    });

  } catch (error) {
    console.error('Admin profile update error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;

